public enum JSONError: Swift.Error, Hashable {
    case unexpectedCharacter(ascii: UInt8, characterIndex: Int)
    case unexpectedEndOfFile

//    case unexpectedByte// (at: Int, found: [UInt8])
//    case unexpectedToken // (at: Int, expected: [JSONToken], found: JSONToken)
//    case dataTruncated
    case typeMismatch
//    case dataCorrupted
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
let numberTerminators = whitespaceBytes + [._comma,
                                           ._closebrace,
                                           ._closebracket]

public struct AsyncJSONTokenSequence<Base: AsyncSequence>: AsyncSequence where Base.Element == UInt8 {
    public typealias Element = JSONToken

    var base: Base

    public struct AsyncIterator: AsyncIteratorProtocol {
        public typealias Element = JSONToken

        var byteSource: Base.AsyncIterator
        var peek: UInt8? = nil {
            didSet {
                if peek != nil { characterIndex -= 1 }
            }
        }

        var characterIndex = -1 // Reading increments; starts at 0

        var containers: [UInt8] = []

        internal init(underlyingIterator: Base.AsyncIterator) {
            byteSource = underlyingIterator
        }

        public mutating func next() async throws -> JSONToken? {
            func nextByte() async throws -> UInt8? {
                defer {
                    peek = nil
                    characterIndex += 1
                }
                if let peek { return peek }
                return try await byteSource.next()
            }

            while let first = try await nextByte() {
                switch first {
                case UInt8(ascii: "["):
                    containers.append(first)
                    return .arrayOpen

                case UInt8(ascii: "{"):
                    containers.append(first)
                    return .objectOpen

                case UInt8(ascii: "]"):
                    guard let open = containers.popLast(), open == ._openbracket else {
                        throw JSONError.unexpectedCharacter(ascii: first, characterIndex: characterIndex)
                    }
                    return .arrayClose

                case UInt8(ascii: "}"):
                    guard let open = containers.popLast(), open == ._openbrace else {
                        throw JSONError.unexpectedCharacter(ascii: first, characterIndex: characterIndex)
                    }
                    return .objectClose

                case UInt8(ascii: ":"):
                    return .colon

                case UInt8(ascii: ","):
                    return .comma

                case UInt8(ascii: "t"):
                    guard try await nextByte() == UInt8(ascii: "r"),
                          try await nextByte() == UInt8(ascii: "u"),
                          try await nextByte() == UInt8(ascii: "e")
                    else {
                        throw JSONError.unexpectedCharacter(ascii: first, characterIndex: characterIndex)
                    }
                    return .true

                case UInt8(ascii: "f"):
                    guard try await nextByte() == UInt8(ascii: "a"),
                          try await nextByte() == UInt8(ascii: "l"),
                          try await nextByte() == UInt8(ascii: "s"),
                          try await nextByte() == UInt8(ascii: "e")
                    else {
                        throw JSONError.unexpectedCharacter(ascii: first, characterIndex: characterIndex)
                    }
                    return .false

                case UInt8(ascii: "n"):
                    guard try await nextByte() == UInt8(ascii: "u"),
                          try await nextByte() == UInt8(ascii: "l"),
                          try await nextByte() == UInt8(ascii: "l")
                    else {
                        throw JSONError.unexpectedCharacter(ascii: first, characterIndex: characterIndex)
                    }
                    return .null

                case UInt8(ascii: #"""#):
                    var string: [UInt8] = []
                    while let byte = try await nextByte() {
                        switch byte {
                        case UInt8(ascii: "\\"):
                            // Don't worry about what the next character is. At this point, we're not validating
                            // the string, just looking for an unescaped double-quote.
                            string.append(byte)
                            guard let escaped = try await nextByte() else { break }
                            string.append(escaped)

                        case UInt8(ascii: #"""#):
                            return .string(string)

                        default:
                            string.append(byte)
                        }
                    }
                    throw JSONError.unexpectedEndOfFile

                case UInt8(ascii: "-"), UInt8(ascii: "0")...UInt8(ascii: "9"):
                    var number = [first]
                    while let digit = try await nextByte() {
                        if numberBytes.contains(digit) {
                            number.append(digit)
                        } else if numberTerminators.contains(digit) {
                            peek = digit
                            break
                        } else {
                            throw JSONError.unexpectedCharacter(ascii: digit,
                                                                characterIndex: characterIndex)
                        }
                    }
                    return .number(number)

                case 0x09, 0x0a, 0x0d, 0x20: // consume whitespace
                    continue

                default:
                    throw JSONError.unexpectedCharacter(ascii: first,
                                                        characterIndex: characterIndex)
                }
            }

            guard containers.isEmpty else {
                throw JSONError.unexpectedEndOfFile
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
    var jsonTokens: AsyncJSONTokenSequence<Self> {
        AsyncJSONTokenSequence(underlyingSequence: self)
    }
}
