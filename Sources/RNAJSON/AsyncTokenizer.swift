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
    case unexpectedEscapedCharacter(ascii: UInt8, in: String, Location)
    case unescapedControlCharacterInString(ascii: UInt8, in: String, Location)
    case expectedLowSurrogateUTF8SequenceAfterHighSurrogate(in: String, Location)
    case couldNotCreateUnicodeScalarFromUInt32(in: String, Location, unicodeScalarValue: UInt32)
    case invalidHexDigitSequence(String, Location)
    case jsonFragmentDisallowed
    case missingKey(Location)
    case missingObjectValue(Location)
    case missingExponent(Location)
    case corruptedLiteral(expected: String, Location)
    case tooManySigns(Location)

    // Split these; they're for JSON
    case typeMismatch
    case missingValue
}

internal let whitespaceBytes: [UInt8] = [0x09, 0x0a, 0x0d, 0x20]

private typealias Location = JSONError.Location

let terminators = whitespaceBytes + [.comma, .closeObject, .closeArray]

private struct Awaiting: OptionSet {
    let rawValue: Int
    static let start = Awaiting(rawValue: 1 << 0)
    static let objectKey = Awaiting(rawValue: 1 << 1)
    static let keyValueSeparator = Awaiting(rawValue: 1 << 2)
    static let objectValue = Awaiting(rawValue: 1 << 3)
    static let objectSeparator = Awaiting(rawValue: 1 << 4)
    static let objectClose = Awaiting(rawValue: 1 << 5)
    static let arrayValue = Awaiting(rawValue: 1 << 6)
    static let arraySeparator = Awaiting(rawValue: 1 << 7)
    static let arrayClose = Awaiting(rawValue: 1 << 8)
    static let end = Awaiting(rawValue: 1 << 9)
}

extension Awaiting: CustomStringConvertible {
    var description: String {
        var values: [String] = []
        if contains(.start) { values.append("start") }
        if contains(.objectKey) { values.append("objectKey") }
        if contains(.keyValueSeparator) { values.append("keyValueSeparator") }
        if contains(.objectValue) { values.append("objectValue") }
        if contains(.objectSeparator) { values.append("objectSeparator") }
        if contains(.objectClose) { values.append("objectClose") }
        if contains(.arrayValue) { values.append("arrayValue") }
        if contains(.arraySeparator) { values.append("arraySeparator") }
        if contains(.arrayClose) { values.append("arrayClose") }
        if contains(.end) { values.append("end") }

        return "[\(values.joined(separator: ", "))]"
    }
}

public struct AsyncJSONTokenSequence<Base: AsyncSequence>: AsyncSequence where Base.Element == UInt8 {
    public typealias Element = JSONToken

    var base: Base

    var strict: Bool

    public struct AsyncIterator: AsyncIteratorProtocol {
        public typealias Element = JSONToken

        var strict: Bool
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
        var location: JSONError.Location { Location(line: line, column: column, index: index) }

        internal init(underlyingIterator: Base.AsyncIterator, strict: Bool) {
            byteSource = underlyingIterator
            self.strict = strict
        }

        private var awaiting: Awaiting = .start

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

            func consumeOpenString() async throws -> String {
                var copy: [UInt8] = []
                var output: String = ""

                while let byte = try await nextByte() {
                    switch byte {
                    case UInt8(ascii: "\""):
                        output += String(decoding: copy, as: Unicode.UTF8.self)
                        return output

                    case 0 ... 31:
                        // All Unicode characters may be placed within the
                        // quotation marks, except for the characters that must be escaped:
                        // quotation mark, reverse solidus, and the control characters (U+0000
                        // through U+001F).
                        output += String(decoding: copy, as: Unicode.UTF8.self)
                        throw JSONError.unescapedControlCharacterInString(ascii: byte, in: output, location)

                    case UInt8(ascii: "\\"):
                        output += String(decoding: copy, as: Unicode.UTF8.self)
                        output += try await parseEscapeSequence(in: output)
                        copy = []

                    default:
                        copy.append(byte)
                        continue
                    }
                }

                throw JSONError.unexpectedEndOfFile(location)
            }

            func parseEscapeSequence(in string: String) async throws -> String {
                guard let ascii = try await nextByte() else {
                    throw JSONError.unexpectedEndOfFile(location)
                }

                switch ascii {
                case 0x22: return "\""
                case 0x5C: return "\\"
                case 0x2F: return "/"
                case 0x62: return "\u{08}" // \b
                case 0x66: return "\u{0C}" // \f
                case 0x6E: return "\u{0A}" // \n
                case 0x72: return "\u{0D}" // \r
                case 0x74: return "\u{09}" // \t
                case 0x75:
                    let character = try await parseUnicodeSequence(in: string)
                    return String(character)
                default:
                    throw JSONError.unexpectedEscapedCharacter(ascii: ascii, in: string, location)
                }
            }

            func parseUnicodeSequence(in string: String) async throws -> Unicode.Scalar {
                // we build this for utf8 only for now.
                let bitPattern = try await parseUnicodeHexSequence()

                // check if high surrogate
                let isFirstByteHighSurrogate = bitPattern & 0xFC00 // nil everything except first six bits
                if isFirstByteHighSurrogate == 0xD800 {
                    // if we have a high surrogate we expect a low surrogate next
                    let highSurrogateBitPattern = bitPattern
                    guard let (escapeChar) = try await nextByte(),
                          let (uChar) = try await nextByte()
                    else {
                        throw JSONError.unexpectedEndOfFile(location)
                    }

                    guard escapeChar == .backslash, uChar == UInt8(ascii: "u") else {
                        throw JSONError.expectedLowSurrogateUTF8SequenceAfterHighSurrogate(in: string, location)
                    }

                    let lowSurrogateBitPattern = try await parseUnicodeHexSequence()
                    let isSecondByteLowSurrogate = lowSurrogateBitPattern & 0xFC00 // nil everything except first six bits
                    guard isSecondByteLowSurrogate == 0xDC00 else {
                        throw JSONError.expectedLowSurrogateUTF8SequenceAfterHighSurrogate(in: string, location)
                    }

                    let highValue = UInt32(highSurrogateBitPattern - 0xD800) * 0x400
                    let lowValue = UInt32(lowSurrogateBitPattern - 0xDC00)
                    let unicodeValue = highValue + lowValue + 0x10000
                    guard let unicode = Unicode.Scalar(unicodeValue) else {
                        throw JSONError.couldNotCreateUnicodeScalarFromUInt32(
                            in: string, location, unicodeScalarValue: unicodeValue
                        )
                    }
                    return unicode
                }

                guard let unicode = Unicode.Scalar(bitPattern) else {
                    throw JSONError.couldNotCreateUnicodeScalarFromUInt32(
                        in: string, location, unicodeScalarValue: UInt32(bitPattern)
                    )
                }
                return unicode
            }

            func parseUnicodeHexSequence() async throws -> UInt16 {
                // As stated in RFC-8259 an escaped unicode character is 4 HEXDIGITs long
                // https://tools.ietf.org/html/rfc8259#section-7
                guard let firstHex = try await nextByte(),
                      let secondHex = try await nextByte(),
                      let thirdHex = try await nextByte(),
                      let forthHex = try await nextByte()
                else {
                    throw JSONError.unexpectedEndOfFile(location)
                }

                guard let first = hexAsciiTo4Bits(firstHex),
                      let second = hexAsciiTo4Bits(secondHex),
                      let third = hexAsciiTo4Bits(thirdHex),
                      let forth = hexAsciiTo4Bits(forthHex)
                else {
                    let hexString = String(decoding: [firstHex, secondHex, thirdHex, forthHex], as: Unicode.UTF8.self)
                    throw JSONError.invalidHexDigitSequence(hexString, location)
                }
                let firstByte = UInt16(first) << 4 | UInt16(second)
                let secondByte = UInt16(third) << 4 | UInt16(forth)

                let bitPattern = UInt16(firstByte) << 8 | UInt16(secondByte)

                return bitPattern
            }

            func hexAsciiTo4Bits(_ ascii: UInt8) -> UInt8? {
                switch ascii {
                case 48 ... 57:
                    return ascii - 48
                case 65 ... 70:
                    // uppercase letters
                    return ascii - 55
                case 97 ... 102:
                    // lowercase letters
                    return ascii - 87
                default:
                    return nil
                }
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
                            throw JSONError.numberWithLeadingZero(location)
                        }
                        if numbersSinceControlChar == 0, pastControlChar == .operand {
                            // the number started with a minus. this is the leading zero.
                            hasLeadingZero = true
                        }
                        digits.append(byte)
                        numbersSinceControlChar += 1
                    case UInt8(ascii: "1") ... UInt8(ascii: "9"):
                        if hasLeadingZero {
                            throw JSONError.numberWithLeadingZero(location)
                        }
                        digits.append(byte)
                        numbersSinceControlChar += 1
                    case UInt8(ascii: "."):
                        guard numbersSinceControlChar > 0, pastControlChar == .operand else {
                            throw JSONError.unexpectedCharacter(ascii: byte, location)
                        }

                        digits.append(byte)
                        hasLeadingZero = false
                        pastControlChar = .decimalPoint
                        numbersSinceControlChar = 0

                    case UInt8(ascii: "e"), UInt8(ascii: "E"):
                        guard numbersSinceControlChar > 0,
                              pastControlChar == .operand || pastControlChar == .decimalPoint
                        else {
                            throw JSONError.unexpectedCharacter(ascii: byte, location)
                        }

                        digits.append(byte)
                        hasLeadingZero = false
                        pastControlChar = .exp
                        numbersSinceControlChar = 0

                    case UInt8(ascii: "+"), UInt8(ascii: "-"):
                        guard numbersSinceControlChar == 0, pastControlChar == .exp else {
                            throw JSONError.unexpectedCharacter(ascii: byte, location)
                        }

                        digits.append(byte)
                        pastControlChar = .expOperator
                        numbersSinceControlChar = 0
                        
                    case .space, .return, .newline, .tab, .comma, .closeArray, .closeObject:
                        guard numbersSinceControlChar > 0 else {
                            switch pastControlChar {
                            case .exp, .expOperator: throw JSONError.missingExponent(location)
                            default:
                                throw JSONError.unexpectedCharacter(ascii: byte, location)
                            }
                        }
                        peek = byte
                        return .number(String(decoding: digits, as: Unicode.UTF8.self))

                    default:
                        throw JSONError.unexpectedCharacter(ascii: byte, location)
                    }
                }
                
                guard numbersSinceControlChar > 0 else {
                    throw JSONError.unexpectedEndOfFile(location)
                }

                return .number(String(decoding: digits, as: Unicode.UTF8.self))
            }

            func consumeScalarValue(first: UInt8) async throws -> JSONToken {
                switch first {
                case .quote:
                    return .string(try await consumeOpenString())

                case UInt8(ascii: "-"), UInt8(ascii: "0")...UInt8(ascii: "9"):
                    return try await consumeDigits(first: first)

                case UInt8(ascii: "t"):
                    try await consumeOpenLiteral("true")
                    return .true

                case UInt8(ascii: "f"):
                    try await consumeOpenLiteral("false")
                    return .false

                case UInt8(ascii: "n"):
                    try await consumeOpenLiteral("null")
                    return .null

                default:
                    throw JSONError.unexpectedCharacter(ascii: first, location)
                }
            }

            func popContainer() {
                containers.removeLast()
                switch containers.last {
                case .none: awaiting = .end
                case .some(.object): awaiting = [.objectSeparator, .objectClose]
                case .some(.array): awaiting = [.arraySeparator, .arrayClose]
                }
            }

            func assertNextByte(is character: Unicode.Scalar) async throws {
                guard let byte = try await nextByte() else {
                    throw JSONError.unexpectedEndOfFile(location)
                }
                guard byte == UInt8(ascii: character) else {
                    throw JSONError.unexpectedCharacter(ascii: byte, location)
                }
            }

            func consumeOpenLiteral(_ literal: String) async throws {
                do {
                    for character in literal.unicodeScalars.dropFirst() {
                        try await assertNextByte(is: character)
                    }
                } catch JSONError.unexpectedCharacter {
                    throw JSONError.corruptedLiteral(expected: literal, location)
                }

                if let terminator = try await nextByte() {
                    if terminators.contains(terminator) {
                        peek = terminator
                    } else {
                        throw JSONError.corruptedLiteral(expected: literal, location)
                    }
                }
            }

            while let first = try await nextByte() {
                switch first {
                case .tab, .newline, .return, .space:
                    continue

                case .openObject where !awaiting.isDisjoint(with: [.start, .objectValue, .arrayValue]):
                    containers.append(.object)
                    awaiting = [.objectKey, .objectClose]
                    return .objectOpen

                case .quote where awaiting.contains(.objectKey):
                    awaiting = .keyValueSeparator
                    return .objectKey(try await consumeOpenString())

                case .colon where awaiting.contains(.keyValueSeparator):
                    awaiting = .objectValue

                case .comma where awaiting.contains(.objectSeparator):
                    awaiting = strict ? [.objectKey] : [.objectKey, .objectClose]

                case .closeObject where containers.last == .object && awaiting.contains(.objectClose):
                    popContainer()
                    return .objectClose

                case .openArray where !awaiting.isDisjoint(with: [.start, .objectValue, .arrayValue]):
                    containers.append(.array)
                    awaiting = [.arrayValue, .arrayClose]
                    return .arrayOpen

                case .comma where awaiting.contains(.arraySeparator):
                    awaiting = strict ? [.arrayValue] : [.arrayValue, .arrayClose]

                case .closeArray where containers.last == .array && awaiting.contains(.arrayClose):
                    popContainer()
                    return .arrayClose

                case _ where awaiting.contains(.objectValue):
                    awaiting = [.objectSeparator, .objectClose]
                    return try await consumeScalarValue(first: first)

                case _ where awaiting.contains(.arrayValue):
                    awaiting = [.arraySeparator, .arrayClose]
                    return try await consumeScalarValue(first: first)

                case _ where !strict && awaiting.contains(.start):
                    awaiting = .end
                    return try await consumeScalarValue(first: first)

                case _ where strict && awaiting.contains(.start):
                    throw JSONError.jsonFragmentDisallowed

                case _ where awaiting.contains(.objectKey):
                    throw JSONError.missingKey(location)

                case _ where awaiting.contains(.keyValueSeparator):
                    throw JSONError.missingObjectValue(location)

                default:
                    throw JSONError.unexpectedCharacter(ascii: first, location)
                }
            }

            guard containers.isEmpty else {
                throw JSONError.unexpectedEndOfFile(location)
            }

            return nil
        }
    }

    public func makeAsyncIterator() -> AsyncIterator {
        return AsyncIterator(underlyingIterator: base.makeAsyncIterator(), strict: strict)
    }

    public init(_ base: Base, strict: Bool = false) {
        self.base = base
        self.strict = strict
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
