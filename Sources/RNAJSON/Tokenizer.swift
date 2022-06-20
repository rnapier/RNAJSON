import Foundation

public enum JSONError: Swift.Error, Hashable {
    case unexpectedByte// (at: Int, found: [UInt8])
    case unexpectedToken // (at: Int, expected: [JSONToken], found: JSONToken)
    case dataTruncated
    case typeMismatch
    case dataCorrupted
    case missingValue
}


internal let whitespaceBytes: [UInt8] = [0x09, 0x0a, 0x0d, 0x20]
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
                    continue

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
