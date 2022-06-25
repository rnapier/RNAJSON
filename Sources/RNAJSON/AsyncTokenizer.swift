public enum JSONError: Swift.Error, Hashable {
    public struct Location: Hashable {
        public var line: Int
        public var column: Int
        public var index: Int
        public init(line: Int, column: Int, index: Int) {
            self.line = line
            self.column = column
            self.index = index
        }
    }
    case unexpectedCharacter(ascii: UInt8, Location)
    case unexpectedEndOfFile(Location)
    case numberWithLeadingZero(Location)
    case unexpectedEscapedCharacter(ascii: UInt8, Location)
    case unescapedControlCharacterInString(ascii: UInt8, Location)
    case invalidHexDigitSequence(String, Location)
    case jsonFragmentDisallowed
    case missingKey(Location)

    case typeMismatch
    case missingValue
}

internal let whitespaceBytes: [UInt8] = [0x09, 0x0a, 0x0d, 0x20]
private let hexDigits = Array(UInt8(ascii: "0")...UInt8(ascii: "9")) +
Array(UInt8(ascii: "a")...UInt8(ascii: "f")) +
Array(UInt8(ascii: "A")...UInt8(ascii: "F"))

private typealias Location = JSONError.Location

let terminators = whitespaceBytes + [.comma, .closeObject, .closeArray]

public struct AsyncJSONTokenSequence<Base: AsyncSequence>: AsyncSequence where Base.Element == UInt8 {
    public typealias Element = JSONToken

    var base: Base

    var allowFragments: Bool

    public struct AsyncIterator: AsyncIteratorProtocol {
        public typealias Element = JSONToken

        var allowFragments: Bool
        var byteSource: Base.AsyncIterator
        var peek: UInt8? = nil {
            didSet {
                if peek != nil {
                    column -= 1
                    index -= 1
                }
            }
        }

        var line = 1
        var column = -1 // Reading increments; starts at 0
        var index = -1 // Reading increments; starts at 0

        internal init(underlyingIterator: Base.AsyncIterator, allowFragments: Bool) {
            byteSource = underlyingIterator
            self.allowFragments = allowFragments
        }

        enum Awaiting {
            case start, objectKeyOrClose, objectKey, keyValueSeparator, objectValue, objectSeparatorOrClose, arrayValueOrClose, arrayValue, arraySeparatorOrClose, end
        }

        var awaiting: Awaiting = .start

        enum Container { case object, array }
        var containers: [Container] = []

        enum ControlCharacter {
            case operand
            case decimalPoint
            case exp
            case expOperator
        }

        public mutating func next() async throws -> JSONToken? {
            func nextByte() async throws -> UInt8? {
                var result: UInt8?
                if let peek {
                    result = peek
                    self.peek = nil
                } else {
                    result = try await byteSource.next()
                }

                if result == .newline {
                    line += 1
                    column = 0
                } else {
                    column += 1
                }
                index += 1

                return result
            }

            func consumeOpenString() async throws -> [UInt8] {
                var output: [UInt8] = []

                while let byte = try await nextByte() {
                    switch byte {
                    case UInt8(ascii: "\""):
                        return output

                    case 0 ... 31:
                        throw JSONError.unescapedControlCharacterInString(ascii: byte, Location(line: line, column: column, index: index))

                    case UInt8(ascii: "\\"):
                        output.append(byte)

                        guard let escaped = try await nextByte() else {
                            throw JSONError.unexpectedEndOfFile(Location(line: line, column: column, index: index))
                        }
                        switch escaped {
                        case .quote, .backslash, UInt8(ascii: "/"), UInt8(ascii: "b"), UInt8(ascii: "f"), UInt8(ascii: "n"), UInt8(ascii: "r"), UInt8(ascii: "t"):
                            output.append(escaped)
                        case UInt8(ascii: "u"):
                            output.append(escaped)
                            guard let digit1 = try await nextByte(),
                                  let digit2 = try await nextByte(),
                                  let digit3 = try await nextByte(),
                                  let digit4 = try await nextByte() else {
                                      throw JSONError.unexpectedEndOfFile(Location(line: line, column: column, index: index))
                                  }

                            let digits = [digit1, digit2, digit3, digit4]
                            guard digits.allSatisfy(hexDigits.contains) else {
                                let hexString = String(decoding: digits, as: Unicode.UTF8.self)
                                throw JSONError.invalidHexDigitSequence(hexString, Location(line: line, column: column, index: index))
                            }

                            output += digits

                        default:
                            throw JSONError.unexpectedEscapedCharacter(ascii: escaped, Location(line: line, column: column, index: index))
                        }
                    default:
                        output.append(byte)
                        continue
                    }
                }

                throw JSONParserError.unexpectedEndOfFile
            }

            func consumeDigits(first: UInt8) async throws -> JSONToken {
                // Based heavily on stdlib JSONParser:
                // https://github.com/apple/swift-corelibs-foundation/blob/main/Sources/Foundation/JSONSerialization%2BParser.swift
                // Code primarily by Fabian Fett (fabianfett@apple.com)
                var pastControlChar: ControlCharacter = .operand
                var numbersSinceControlChar: UInt = 0
                var hasLeadingZero = false

                // parse first character

                switch first {
                case UInt8(ascii: "0"):
                    numbersSinceControlChar = 1
                    pastControlChar = .operand
                    hasLeadingZero = true
                case UInt8(ascii: "1") ... UInt8(ascii: "9"):
                    numbersSinceControlChar = 1
                    pastControlChar = .operand
                case UInt8(ascii: "-"):
                    numbersSinceControlChar = 0
                    pastControlChar = .operand
                default:
                    preconditionFailure("Why was this function called, if there is no 0...9 or -")
                }

                var digits: [UInt8] = [first]

                // parse everything else
                while let byte = try await nextByte() {
                    switch byte {
                    case UInt8(ascii: "0"):
                        if hasLeadingZero {
                            throw JSONError.numberWithLeadingZero(Location(line: line, column: column, index: index))
                        }
                        if numbersSinceControlChar == 0, pastControlChar == .operand {
                            // the number started with a minus. this is the leading zero.
                            hasLeadingZero = true
                        }
                        digits.append(byte)
                        numbersSinceControlChar += 1
                    case UInt8(ascii: "1") ... UInt8(ascii: "9"):
                        if hasLeadingZero {
                            throw JSONError.numberWithLeadingZero(Location(line: line, column: column, index: index))
                        }
                        digits.append(byte)
                        numbersSinceControlChar += 1
                    case UInt8(ascii: "."):
                        guard numbersSinceControlChar > 0, pastControlChar == .operand else {
                            throw JSONError.unexpectedCharacter(ascii: byte, Location(line: line, column: column, index: index))
                        }

                        digits.append(byte)
                        hasLeadingZero = false
                        pastControlChar = .decimalPoint
                        numbersSinceControlChar = 0

                    case UInt8(ascii: "e"), UInt8(ascii: "E"):
                        guard numbersSinceControlChar > 0,
                              pastControlChar == .operand || pastControlChar == .decimalPoint
                        else {
                            throw JSONError.unexpectedCharacter(ascii: byte, Location(line: line, column: column, index: index))
                        }

                        digits.append(byte)
                        hasLeadingZero = false
                        pastControlChar = .exp
                        numbersSinceControlChar = 0
                    case UInt8(ascii: "+"), UInt8(ascii: "-"):
                        guard numbersSinceControlChar == 0, pastControlChar == .exp else {
                            throw JSONError.unexpectedCharacter(ascii: byte, Location(line: line, column: column, index: index))
                        }

                        digits.append(byte)
                        pastControlChar = .expOperator
                        numbersSinceControlChar = 0
                    case .space, .return, .newline, .tab, .comma, .closeArray, .closeObject:
                        guard numbersSinceControlChar > 0 else {
                            throw JSONError.unexpectedCharacter(ascii: byte, Location(line: line, column: column, index: index))
                        }
                        peek = byte
                        return .number(digits)
                    default:
                        throw JSONError.unexpectedCharacter(ascii: byte, Location(line: line, column: column, index: index))
                    }
                }
                
                guard numbersSinceControlChar > 0 else {
                    throw JSONError.unexpectedEndOfFile(Location(line: line, column: column, index: index))
                }

                return .number(digits)
            }

            func consumeScalarValue(first: UInt8) async throws -> JSONToken {
                switch first {
                case .quote:
                    return .string(try await consumeOpenString())

                case UInt8(ascii: "-"), UInt8(ascii: "0")...UInt8(ascii: "9"):
                    return try await consumeDigits(first: first)

                case UInt8(ascii: "t"):
                    try await assertNextBytes(are: "rue")
                    return .true

                case UInt8(ascii: "f"):
                    try await assertNextBytes(are: "alse")
                    return .false

                case UInt8(ascii: "n"):
                    try await assertNextBytes(are: "ull")
                    return .null

                default:
                    throw JSONError.unexpectedCharacter(ascii: first, Location(line: line, column: column, index: index))
                }
            }

            func popContainer() {
                containers.removeLast()
                switch containers.last {
                case .none: awaiting = .end
                case .some(.object): awaiting = .objectSeparatorOrClose
                case .some(.array): awaiting = .arraySeparatorOrClose
                }
            }

            func assertNextByte(is character: Unicode.Scalar) async throws {
                guard let byte = try await nextByte() else {
                    throw JSONError.unexpectedEndOfFile(Location(line: line, column: column, index: index))
                }
                guard byte == UInt8(ascii: character) else {
                    throw JSONError.unexpectedCharacter(ascii: byte, Location(line: line, column: column, index: index))
                }
            }

            // FIXME: Make clearer; this also checks for a terminator
            func assertNextBytes(are characters: String) async throws {
                for character in characters.unicodeScalars {
                    try await assertNextByte(is: character)
                }

                if let terminator = try await nextByte() {
                    if terminators.contains(terminator) {
                        peek = terminator
                    } else {
                        throw JSONError.unexpectedCharacter(ascii: terminator, Location(line: line, column: column, index: index))
                    }
                }
            }

            while let first = try await nextByte() {
                switch first {
                case .tab, .newline, .return, .space:
                    continue

                case .openObject where [.start, .objectValue, .arrayValue].contains(awaiting):
                    containers.append(.object)
                    awaiting = .objectKeyOrClose
                    return .objectOpen

                case .quote where [.objectKey, .objectKeyOrClose].contains(awaiting):
                    awaiting = .keyValueSeparator
                    return .objectKey(try await consumeOpenString())

                case .colon where awaiting == .keyValueSeparator:
                    awaiting = .objectValue
                    continue

                case .comma where awaiting == .objectSeparatorOrClose:
                    awaiting = .objectKey
                    continue

                case .closeObject where containers.last == .object && [.objectSeparatorOrClose, .objectKeyOrClose].contains(awaiting):
                    popContainer()
                    return .objectClose

                case _ where [.objectKey, .objectKeyOrClose].contains(awaiting):
                    throw JSONError.missingKey(Location(line: line, column: column, index: index))

                case .openArray where [.start, .objectValue, .arrayValue, .arrayValueOrClose].contains(awaiting):
                    containers.append(.array)
                    awaiting = .arrayValueOrClose
                    return .arrayOpen

                case .comma where awaiting == .arraySeparatorOrClose:
                    awaiting = .arrayValue
                    continue

                case .closeArray where containers.last == .array && [.arraySeparatorOrClose, .arrayValueOrClose].contains(awaiting):
                    popContainer()
                    return .arrayClose

                case _ where awaiting == .objectValue:
                    awaiting = .objectSeparatorOrClose
                    return try await consumeScalarValue(first: first)

                case _ where [.arrayValue, .arrayValueOrClose].contains(awaiting):
                    awaiting = .arraySeparatorOrClose
                    return try await consumeScalarValue(first: first)

                case _ where awaiting == .start && allowFragments:
                    awaiting = .end
                    return try await consumeScalarValue(first: first)

                case _ where awaiting == .start && !allowFragments:
                    throw JSONError.jsonFragmentDisallowed

                default:
                    throw JSONError.unexpectedCharacter(ascii: first, Location(line: line, column: column, index: index))
                }
            }

            guard containers.isEmpty else {
                throw JSONError.unexpectedEndOfFile(Location(line: line, column: column, index: index))
            }

            return nil
        }
    }

    public func makeAsyncIterator() -> AsyncIterator {
        return AsyncIterator(underlyingIterator: base.makeAsyncIterator(), allowFragments: allowFragments)
    }

    public init(_ base: Base, allowFragments: Bool = true) {
        self.base = base
        self.allowFragments = allowFragments
    }
}

public extension AsyncSequence where Self.Element == UInt8 {
    /**
     A non-blocking sequence of  `JSONTokens` created by decoding the elements of `self`.
     */
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    var jsonTokens: AsyncJSONTokenSequence<Self> {
        AsyncJSONTokenSequence(self)
    }
}
