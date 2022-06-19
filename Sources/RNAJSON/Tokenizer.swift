import Foundation

public enum JSONToken: Hashable {
    case arrayOpen
    case arrayClose
    case objectOpen
    case objectClose
    case colon
    case comma
    case `true`
    case `false`
    case null
    case string(Data)
    case number(Data)
}

extension JSONToken {
    static func digits(_ digits: String) -> Self {
        .number(Data(digits.utf8))
    }
}

extension JSONToken: ExpressibleByStringLiteral {
    public init(stringLiteral value: StringLiteralType) {
        self = .string(Data(value.utf8))
    }
}

extension JSONToken: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: IntegerLiteralType) {
        self = .number(Data("\(value)".utf8))
    }
}

extension JSONToken: ExpressibleByFloatLiteral {
    public init(floatLiteral value: FloatLiteralType) {
        self = .number(Data("\(value)".utf8))
    }
}

extension JSONToken: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self = .null
    }
}

extension JSONToken: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: BooleanLiteralType) {
        self = value ? .true : .false
    }
}

extension JSONToken: CustomStringConvertible {
    public var description: String {
        switch self {
        case .arrayOpen: return ".arrayOpen"
        case .arrayClose: return ".arrayClose"
        case .objectOpen: return ".objectOpen"
        case .objectClose: return ".objectClose"
        case .colon: return ".colon"
        case .comma: return ".comma"
        case .true: return "true"
        case .false: return "false"
        case .null: return ".null"
        case .string(let data):
            if let string = String(data: data, encoding: .utf8) {
                if string.contains("\\") {
                    return """
                        #"\(string)"#
                        """
                } else {
                    return """
                        "\(string)"
                        """
                }
            } else {
                let bytes = data.map { "\($0)" }.joined(separator: ",")
                return """
                    .string(Data([\(bytes)]))
                    """
            }

        case .number(let data):
            if let digits = String(data: data, encoding: .utf8) {
                let interpreted = "\(digits)"

                if let int = Int(interpreted), "\(int)" == interpreted {
                    return interpreted
                }

                if let double = Double(interpreted), "\(double)" == interpreted {
                    return interpreted
                }

                return """
                    .digits("\(digits)")
                    """
            } else {
                let bytes = data.map { "\($0)" }.joined(separator: ",")
                return """
                    .number(Data([\(bytes)]))
                    """
            }
        }
    }
}

public enum JSONError: Swift.Error {
    case unexpectedByte// (at: Int, found: [UInt8])
    case unexpectedToken(at: Int, expected: [JSONToken], found: JSONToken)
    case dataTruncated
    case typeMismatch
    case dataCorrupted
    case missingValue
}

private let whitespaceBytes: [UInt8] = [0x09, 0x0a, 0x0d, 0x20]
private let newlineBytes: [UInt8] = [0x0a, 0x0d]
private let numberBytes: [UInt8] = [0x2b,   // +
                                    0x2d,   // -
                                    0x2e,   // .
                                    0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, // 0-9
                                    0x45,   // E
                                    0x65    // e
]

public struct AsyncJSONTokenizer<Base: AsyncSequence>: AsyncSequence where Base.Element == UInt8 {
    public typealias Element = JSONToken

    var base: Base

    public struct AsyncIterator: AsyncIteratorProtocol {
        public typealias Element = JSONToken

        var byteSource: Base.AsyncIterator
        var buffer: Array<UInt8> = []
        var peek: UInt8? = nil

        internal init(underlyingIterator: Base.AsyncIterator) {
            byteSource = underlyingIterator
        }

        public mutating func next() async throws -> JSONToken? {
            func nextByte() async throws -> UInt8? {
                defer { peek = nil }
                if let peek { return peek }
                return try await byteSource.next()
            }

            while let first = try await nextByte() {
                switch first {
                case UInt8(ascii: "["):
                    return .arrayOpen

                case UInt8(ascii: "{"):
                    return .objectOpen

                case UInt8(ascii: "]"):
                    return .arrayClose

                case UInt8(ascii: "}"):
                    return .objectClose

                case UInt8(ascii: ":"):
                    return .colon

                case UInt8(ascii: ","):
                    return .comma

                case UInt8(ascii: "t"):
                    guard try await byteSource.next() == UInt8(ascii: "r"),
                          try await byteSource.next() == UInt8(ascii: "u"),
                          try await byteSource.next() == UInt8(ascii: "e")
                    else {
                        throw JSONError.unexpectedByte  // FIXME: Better error
                    }
                    return .true

                case UInt8(ascii: "f"):
                    guard try await byteSource.next() == UInt8(ascii: "a"),
                          try await byteSource.next() == UInt8(ascii: "l"),
                          try await byteSource.next() == UInt8(ascii: "s"),
                          try await byteSource.next() == UInt8(ascii: "e")
                    else {
                        throw JSONError.unexpectedByte  // FIXME: Better error
                    }
                    return .false

                case UInt8(ascii: "n"):
                    guard try await byteSource.next() == UInt8(ascii: "u"),
                          try await byteSource.next() == UInt8(ascii: "l"),
                          try await byteSource.next() == UInt8(ascii: "l")
                    else {
                        throw JSONError.unexpectedByte  // FIXME: Better error
                    }
                    return .null

                case UInt8(ascii: "\""):
                    var string = Data()
                    while let byte = try await byteSource.next() {
                        switch byte {
                        case UInt8(ascii: "\\"):
                            // Don't worry about what the next character is. At this point, we're not validating
                            // the string, just looking for an unescaped double-quote.
                            string.append(byte)
                            guard let escaped = try await byteSource.next() else { break }
                            string.append(escaped)

                        case UInt8(ascii: "\""):
                            return .string(string)

                        default:
                            string.append(byte)
                        }
                    }
                    throw JSONError.dataTruncated

                case UInt8(ascii: "-"), UInt8(ascii: "0")...UInt8(ascii: "9"):
                    var number = Data([first])
                    while let digit = try await byteSource.next() {
                        if numberBytes.contains(digit) {
                            number.append(digit)
                        } else {
                            peek = digit
                            break
                        }
                    }
                    return .number(number)

                case 0x09, 0x0a, 0x0d, 0x20: // consume whitespace
                    while let byte = try await byteSource.next() {
                        guard whitespaceBytes.contains(byte) else {
                            peek = byte
                            break
                        }
                    }


                default:
                    throw JSONError.unexpectedByte
                }
            }

            return nil
        }
    }

    public func makeAsyncIterator() -> AsyncIterator {
        return AsyncIterator(underlyingIterator: base.makeAsyncIterator())
    }

    internal init(underlyingSequence: Base) {
        base = underlyingSequence
    }
}

public extension AsyncSequence where Self.Element == UInt8 {
    /**
     A non-blocking sequence of  `JSONTokens` created by decoding the elements of `self`.
     */
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    var jsonTokens: AsyncJSONTokenizer<Self> {
        AsyncJSONTokenizer(underlyingSequence: self)
    }
}
