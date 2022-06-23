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
private let startNumberBytes: [UInt8] = [UInt8(ascii: "-")] + Array(UInt8(ascii: "0")...UInt8(ascii: "9"))

let numberTerminators = whitespaceBytes + [.comma,
                                           .closeObject,
                                           .closeArray]

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

        enum Awaiting {
            case topLevel, objectKeyOrClose, objectKey, keyValueSeparator, objectValue, objectSeparatorOrClose, arrayValueOrClose, arrayValue, arraySeparatorOrClose, end
        }

        var awaiting: Awaiting = .topLevel

        public mutating func next() async throws -> JSONToken? {
            func nextByte() async throws -> UInt8? {
                defer {
                    peek = nil
                    characterIndex += 1
                }
                if let peek { return peek }
                return try await byteSource.next()
            }

            func nextByteAfterWhitespace() async throws -> UInt8? {
                repeat {
                    guard let byte = try await nextByte() else { return nil }
                    if !whitespaceBytes.contains(byte) { return byte }
                } while true
            }

            func consumeContainerOpen(first: UInt8) async throws -> JSONToken {
                containers.append(first)

                switch first {
                case .openArray:
                    awaiting = .arrayValue
                    return .arrayOpen

                case .openObject:
                    awaiting = .objectKey
                    return .objectOpen

                default:
                    throw JSONError.unexpectedCharacter(ascii: first, characterIndex: characterIndex)
                }
            }

            func consumeOpenString() async throws -> [UInt8] {
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
                        return string

                    default:
                        string.append(byte)
                    }
                }
                throw JSONError.unexpectedEndOfFile
            }

            func consumeDigits(first: UInt8) async throws -> JSONToken {
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
            }

            func assertNextByte(is character: Unicode.Scalar) async throws {
                guard let byte = try await nextByte() else {
                    throw JSONError.unexpectedEndOfFile
                }
                guard byte == UInt8(ascii: character) else {
                    throw JSONError.unexpectedCharacter(ascii: byte, characterIndex: characterIndex)
                }
            }

            func assertNextBytes(are characters: String) async throws {
                for character in characters.unicodeScalars {
                    try await assertNextByte(is: character)
                }
            }

            while let first = try await nextByteAfterWhitespace() {
                switch first {
                case .openObject where [.topLevel, .objectValue, .arrayValue].contains(awaiting):
                    containers.append(first)
                    awaiting = .objectKeyOrClose
                    return .objectOpen

                case .quote where [.objectKey, .objectKeyOrClose].contains(awaiting):
                    awaiting = .keyValueSeparator
                    return .objectKey(try await consumeOpenString())

                case .colon where [.keyValueSeparator].contains(awaiting):
                    awaiting = .objectValue
                    continue

                case .quote where [.objectValue].contains(awaiting):
                    awaiting = .objectSeparatorOrClose
                    return .string(try await consumeOpenString())

                case let digit where [.objectValue].contains(awaiting) && startNumberBytes.contains(digit):
                    awaiting = .objectSeparatorOrClose
                    return try await consumeDigits(first: first)

                case UInt8(ascii: "t") where [.objectValue].contains(awaiting):
                    awaiting = .objectSeparatorOrClose
                    try await assertNextBytes(are: "rue")
                    return .true

                case UInt8(ascii: "f") where [.objectValue].contains(awaiting):
                    awaiting = .objectSeparatorOrClose
                    try await assertNextBytes(are: "alse")
                    return .false

                case UInt8(ascii: "n") where [.objectValue].contains(awaiting):
                    awaiting = .objectSeparatorOrClose
                    try await assertNextBytes(are: "ull")
                    return .null

                case .comma where [.objectSeparatorOrClose].contains(awaiting):
                    awaiting = .objectKey
                    continue

                case .closeObject where containers.last == .openObject && [.objectSeparatorOrClose, .objectKeyOrClose].contains(awaiting):
                    containers.removeLast()
                    switch containers.last {
                    case .none: awaiting = .end
                    case .some(.openObject): awaiting = .objectSeparatorOrClose
                    case .some(.openArray): awaiting = .arraySeparatorOrClose
                    default: preconditionFailure()
                    }
                    return .objectClose

                case .openArray where [.topLevel, .objectValue, .arrayValue, .arrayValueOrClose].contains(awaiting):
                    containers.append(first)
                    awaiting = .arrayValueOrClose
                    return .arrayOpen

                case .quote where [.arrayValue, .arrayValueOrClose].contains(awaiting):
                    awaiting = .arraySeparatorOrClose
                    return .string(try await consumeOpenString())

                case let digit where [.arrayValue, .arrayValueOrClose].contains(awaiting) && startNumberBytes.contains(digit):
                    awaiting = .arraySeparatorOrClose
                    return try await consumeDigits(first: first)

                case UInt8(ascii: "t") where [.arrayValue, .arrayValueOrClose].contains(awaiting):
                    awaiting = .arraySeparatorOrClose
                    try await assertNextBytes(are: "rue")
                    return .true

                case UInt8(ascii: "f") where [.arrayValue, .arrayValueOrClose].contains(awaiting):
                    awaiting = .arraySeparatorOrClose
                    try await assertNextBytes(are: "alse")
                    return .false

                case UInt8(ascii: "n") where [.arrayValue, .arrayValueOrClose].contains(awaiting):
                    awaiting = .arraySeparatorOrClose
                    try await assertNextBytes(are: "ull")
                    return .null

                case .comma where [.arraySeparatorOrClose].contains(awaiting):
                    awaiting = .arrayValue
                    continue

                case .closeArray where containers.last == .openArray && [.arraySeparatorOrClose, .arrayValueOrClose].contains(awaiting):
                    containers.removeLast()
                    switch containers.last {
                    case .none: awaiting = .end
                    case .some(.openObject): awaiting = .objectSeparatorOrClose
                    case .some(.openArray): awaiting = .arraySeparatorOrClose
                    default: preconditionFailure()
                    }
                    return .arrayClose

                default:
                    throw JSONError.unexpectedCharacter(ascii: first, characterIndex: characterIndex)
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
