//
//  Scanner.swift
//  
//
//  Created by Rob Napier on 7/24/22.
//

import Foundation

public enum JSONScannerError: Swift.Error, Equatable {
    case cannotConvertInputDataToUTF8
    case unexpectedCharacter(ascii: UInt8, characterIndex: Int)
    case unexpectedEndOfFile
    case tooManyNestedArraysOrDictionaries(characterIndex: Int)
    case invalidHexDigitSequence(String, index: Int)
    case unexpectedEscapedCharacter(ascii: UInt8, in: String, index: Int)
    case unescapedControlCharacterInString(ascii: UInt8, in: String, index: Int)
    case expectedLowSurrogateUTF8SequenceAfterHighSurrogate(in: String, index: Int)
    case couldNotCreateUnicodeScalarFromUInt32(in: String, index: Int, unicodeScalarValue: UInt32)
    case numberWithLeadingZero(index: Int)
    case numberIsNotRepresentableInSwift(parsed: String)
    case singleFragmentFoundButNotAllowed
}

public struct JSONScanner {
    var reader: DocumentReader
    var depth: Int = 0

    public init(bytes: [UInt8]) {
        self.reader = DocumentReader(array: bytes)
    }

    public mutating func dataForBody() throws -> some Collection<UInt8> {
        try reader.consumeWhitespace()
        let startIndex = reader.readerIndex
        try consumeValue()
        return reader.array[startIndex..<reader.readerIndex]
    }

    // MARK: Generic Value Parsing
    mutating func consumeValue() throws {
        var whitespace = 0
        while let byte = reader.peek(offset: whitespace) {
            switch byte {
            case UInt8(ascii: "\""):
                reader.moveReaderIndex(forwardBy: whitespace)
                try reader.readString()
                return
            case .openObject:
                reader.moveReaderIndex(forwardBy: whitespace)
                try consumeObject()
                return
            case .openArray:
                reader.moveReaderIndex(forwardBy: whitespace)
                try consumeArray()
                return
            case UInt8(ascii: "f"), UInt8(ascii: "t"), UInt8(ascii: "n"):
                reader.moveReaderIndex(forwardBy: whitespace)
                try reader.consumeLiteral()
                return
            case UInt8(ascii: "-"), UInt8(ascii: "0") ... UInt8(ascii: "9"):
                reader.moveReaderIndex(forwardBy: whitespace)
                try self.reader.consumeNumber()
                return
            case .space, .return, .newline, .tab:
                whitespace += 1
                continue
            default:
                throw JSONScannerError.unexpectedCharacter(ascii: byte, characterIndex: self.reader.readerIndex)
            }
        }

        throw JSONScannerError.unexpectedEndOfFile
    }


    // MARK: - Parse Array -
    mutating func consumeArray() throws {
        precondition(self.reader.read() == .openArray)
        guard self.depth < 512 else {
            throw JSONScannerError.tooManyNestedArraysOrDictionaries(characterIndex: self.reader.readerIndex - 1)
        }
        self.depth += 1
        defer { depth -= 1 }

        // parse first value or end immediately
        switch try reader.consumeWhitespace() {
        case .space, .return, .newline, .tab:
            preconditionFailure("Expected that all white space is consumed")
        case .closeArray:
            // if the first char after whitespace is a closing bracket, we found an empty array
            self.reader.moveReaderIndex(forwardBy: 1)
            return
        default:
            break
        }

        // parse values
        while true {
            try consumeValue()

            // consume the whitespace after the value before the comma
            let ascii = try reader.consumeWhitespace()
            switch ascii {
            case .space, .return, .newline, .tab:
                preconditionFailure("Expected that all white space is consumed")
            case .closeArray:
                reader.moveReaderIndex(forwardBy: 1)
                return
            case .comma:
                // consume the comma
                reader.moveReaderIndex(forwardBy: 1)
                // consume the whitespace before the next value
                if try reader.consumeWhitespace() == .closeArray {
                    // the foundation json implementation does support trailing commas
                    reader.moveReaderIndex(forwardBy: 1)
                    return
                }
                continue
            default:
                throw JSONScannerError.unexpectedCharacter(ascii: ascii, characterIndex: reader.readerIndex)
            }
        }
    }

    // MARK: - Object parsing -
    mutating func consumeObject() throws /*-> [String: JSONValue]*/ {
         precondition(self.reader.read() == .openObject)
        guard self.depth < 512 else {
            throw JSONScannerError.tooManyNestedArraysOrDictionaries(characterIndex: self.reader.readerIndex - 1)
        }
        self.depth += 1
        defer { depth -= 1 }

        // parse first value or end immediately
        switch try reader.consumeWhitespace() {
        case .space, .return, .newline, .tab:
            preconditionFailure("Expected that all white space is consumed")
        case .closeObject:
            // if the first char after whitespace is a closing bracket, we found an empty array
            self.reader.moveReaderIndex(forwardBy: 1)
            return
        default:
            break
        }

        while true {
            /*let key = */try reader.readString()
            let colon = try reader.consumeWhitespace()
            guard colon == .colon else {
                throw JSONScannerError.unexpectedCharacter(ascii: colon, characterIndex: reader.readerIndex)
            }
            reader.moveReaderIndex(forwardBy: 1)
            try reader.consumeWhitespace()
            try self.consumeValue()

            let commaOrBrace = try reader.consumeWhitespace()
            switch commaOrBrace {
            case .closeObject:
                reader.moveReaderIndex(forwardBy: 1)
                return
            case .comma:
                reader.moveReaderIndex(forwardBy: 1)
                if try reader.consumeWhitespace() == .closeObject {
                    // the foundation json implementation does support trailing commas
                    reader.moveReaderIndex(forwardBy: 1)
                    return
                }
                continue
            default:
                throw JSONScannerError.unexpectedCharacter(ascii: commaOrBrace, characterIndex: reader.readerIndex)
            }
        }
    }
}

extension JSONScanner {

    struct DocumentReader {
        let array: [UInt8]

        private(set) var readerIndex: Int = 0

        private var readableBytes: Int {
            self.array.endIndex - self.readerIndex
        }

        var isEOF: Bool {
            self.readerIndex >= self.array.endIndex
        }

        init(array: [UInt8]) {
            self.array = array
        }

        subscript(bounds: Range<Int>) -> ArraySlice<UInt8> {
            self.array[bounds]
        }

        mutating func read() -> UInt8? {
            guard self.readerIndex < self.array.endIndex else {
                self.readerIndex = self.array.endIndex
                return nil
            }

            defer { self.readerIndex += 1 }

            return self.array[self.readerIndex]
        }

        func peek(offset: Int = 0) -> UInt8? {
            guard self.readerIndex + offset < self.array.endIndex else {
                return nil
            }

            return self.array[self.readerIndex + offset]
        }

        mutating func moveReaderIndex(forwardBy offset: Int) {
            self.readerIndex += offset
        }

        @discardableResult
        mutating func consumeWhitespace() throws -> UInt8 {
            var whitespace = 0
            while let ascii = self.peek(offset: whitespace) {
                switch ascii {
                case .space, .return, .newline, .tab:
                    whitespace += 1
                    continue
                default:
                    self.moveReaderIndex(forwardBy: whitespace)
                    return ascii
                }
            }

            throw JSONScannerError.unexpectedEndOfFile
        }

        mutating func readString() throws /*-> String*/ {
            try self.readUTF8StringTillNextUnescapedQuote()
        }

        mutating func consumeNumber() throws /*-> String */{
            try self.parseNumber()
        }

        mutating func consumeLiteral() throws /*-> Bool */ {
            switch self.read() {
            case UInt8(ascii: "t"):
                guard self.read() == UInt8(ascii: "r"),
                      self.read() == UInt8(ascii: "u"),
                      self.read() == UInt8(ascii: "e")
                else {
                    guard !self.isEOF else {
                        throw JSONScannerError.unexpectedEndOfFile
                    }

                    throw JSONScannerError.unexpectedCharacter(ascii: self.peek(offset: -1)!, characterIndex: self.readerIndex - 1)
                }

            case UInt8(ascii: "f"):
                guard self.read() == UInt8(ascii: "a"),
                      self.read() == UInt8(ascii: "l"),
                      self.read() == UInt8(ascii: "s"),
                      self.read() == UInt8(ascii: "e")
                else {
                    guard !self.isEOF else {
                        throw JSONScannerError.unexpectedEndOfFile
                    }

                    throw JSONScannerError.unexpectedCharacter(ascii: self.peek(offset: -1)!, characterIndex: self.readerIndex - 1)
                }

            case UInt8(ascii: "n"):
                guard self.read() == UInt8(ascii: "u"),
                      self.read() == UInt8(ascii: "l"),
                      self.read() == UInt8(ascii: "l")
                else {
                    guard !self.isEOF else {
                        throw JSONScannerError.unexpectedEndOfFile
                    }

                    throw JSONScannerError.unexpectedCharacter(ascii: self.peek(offset: -1)!, characterIndex: self.readerIndex - 1)
                }

            default:
                preconditionFailure("Expected to have `t` or `f` as first character")
            }
        }

        // MARK: - Private Methods -
        // MARK: String

        enum EscapedSequenceError: Swift.Error {
            case expectedLowSurrogateUTF8SequenceAfterHighSurrogate(index: Int)
            case unexpectedEscapedCharacter(ascii: UInt8, index: Int)
            case couldNotCreateUnicodeScalarFromUInt32(index: Int, unicodeScalarValue: UInt32)
        }

        private mutating func readUTF8StringTillNextUnescapedQuote() throws /* -> String */{
            guard self.read() == .quote else {
                throw JSONScannerError.unexpectedCharacter(ascii: self.peek(offset: -1)!, characterIndex: self.readerIndex - 1)
            }
            var stringStartIndex = self.readerIndex
            var copy = 0
            var output: String?

            while let byte = peek(offset: copy) {
                switch byte {
                case UInt8(ascii: "\""):
                    self.moveReaderIndex(forwardBy: copy + 1)
                    guard var result = output else {
                        // if we don't have an output string we create a new string
                        return //String(decoding: self[stringStartIndex ..< stringStartIndex + copy], as: Unicode.UTF8.self)
                    }
                    // if we have an output string we append
                    result += String(decoding: self[stringStartIndex ..< stringStartIndex + copy], as: Unicode.UTF8.self)
                    return //result

                case 0 ... 31:
                    // All Unicode characters may be placed within the
                    // quotation marks, except for the characters that must be escaped:
                    // quotation mark, reverse solidus, and the control characters (U+0000
                    // through U+001F).
                    var string = output ?? ""
                    let errorIndex = self.readerIndex + copy
                    string += self.makeStringFast(self.array[stringStartIndex ... errorIndex])
                    throw JSONScannerError.unescapedControlCharacterInString(ascii: byte, in: string, index: errorIndex)

                case UInt8(ascii: "\\"):
                    self.moveReaderIndex(forwardBy: copy)
                    if output != nil {
                        output! += self.makeStringFast(self.array[stringStartIndex ..< stringStartIndex + copy])
                    } else {
                        output = self.makeStringFast(self.array[stringStartIndex ..< stringStartIndex + copy])
                    }

                    let escapedStartIndex = self.readerIndex

                    do {
                        let escaped = try parseEscapeSequence()
                        output! += escaped
                        stringStartIndex = self.readerIndex
                        copy = 0
                    } catch EscapedSequenceError.unexpectedEscapedCharacter(let ascii, let failureIndex) {
                        output! += makeStringFast(array[escapedStartIndex ..< self.readerIndex])
                        throw JSONScannerError.unexpectedEscapedCharacter(ascii: ascii, in: output!, index: failureIndex)
                    } catch EscapedSequenceError.expectedLowSurrogateUTF8SequenceAfterHighSurrogate(let failureIndex) {
                        output! += makeStringFast(array[escapedStartIndex ..< self.readerIndex])
                        throw JSONScannerError.expectedLowSurrogateUTF8SequenceAfterHighSurrogate(in: output!, index: failureIndex)
                    } catch EscapedSequenceError.couldNotCreateUnicodeScalarFromUInt32(let failureIndex, let unicodeScalarValue) {
                        output! += makeStringFast(array[escapedStartIndex ..< self.readerIndex])
                        throw JSONScannerError.couldNotCreateUnicodeScalarFromUInt32(
                            in: output!, index: failureIndex, unicodeScalarValue: unicodeScalarValue
                        )
                    }

                default:
                    copy += 1
                    continue
                }
            }

            throw JSONScannerError.unexpectedEndOfFile
        }

        // can be removed as soon https://bugs.swift.org/browse/SR-12126 and
        // https://bugs.swift.org/browse/SR-12125 has landed.
        // Thanks @weissi for making my code fast!
        private func makeStringFast<Bytes: Collection>(_ bytes: Bytes) -> String where Bytes.Element == UInt8 {
            if let string = bytes.withContiguousStorageIfAvailable({ String(decoding: $0, as: Unicode.UTF8.self) }) {
                return string
            } else {
                return String(decoding: bytes, as: Unicode.UTF8.self)
            }
        }

        private mutating func parseEscapeSequence() throws -> String {
            precondition(self.read() == .backslash, "Expected to have an backslash first")
            guard let ascii = self.read() else {
                throw JSONScannerError.unexpectedEndOfFile
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
                let character = try parseUnicodeSequence()
                return String(character)
            default:
                throw EscapedSequenceError.unexpectedEscapedCharacter(ascii: ascii, index: self.readerIndex - 1)
            }
        }

        private mutating func parseUnicodeSequence() throws -> Unicode.Scalar {
            // we build this for utf8 only for now.
            let bitPattern = try parseUnicodeHexSequence()

            // check if high surrogate
            let isFirstByteHighSurrogate = bitPattern & 0xFC00 // nil everything except first six bits
            if isFirstByteHighSurrogate == 0xD800 {
                // if we have a high surrogate we expect a low surrogate next
                let highSurrogateBitPattern = bitPattern
                guard let (escapeChar) = self.read(),
                      let (uChar) = self.read()
                else {
                    throw JSONScannerError.unexpectedEndOfFile
                }

                guard escapeChar == UInt8(ascii: #"\"#), uChar == UInt8(ascii: "u") else {
                    throw EscapedSequenceError.expectedLowSurrogateUTF8SequenceAfterHighSurrogate(index: self.readerIndex - 1)
                }

                let lowSurrogateBitBattern = try parseUnicodeHexSequence()
                let isSecondByteLowSurrogate = lowSurrogateBitBattern & 0xFC00 // nil everything except first six bits
                guard isSecondByteLowSurrogate == 0xDC00 else {
                    // we are in an escaped sequence. for this reason an output string must have
                    // been initialized
                    throw EscapedSequenceError.expectedLowSurrogateUTF8SequenceAfterHighSurrogate(index: self.readerIndex - 1)
                }

                let highValue = UInt32(highSurrogateBitPattern - 0xD800) * 0x400
                let lowValue = UInt32(lowSurrogateBitBattern - 0xDC00)
                let unicodeValue = highValue + lowValue + 0x10000
                guard let unicode = Unicode.Scalar(unicodeValue) else {
                    throw EscapedSequenceError.couldNotCreateUnicodeScalarFromUInt32(
                        index: self.readerIndex, unicodeScalarValue: unicodeValue
                    )
                }
                return unicode
            }

            guard let unicode = Unicode.Scalar(bitPattern) else {
                throw EscapedSequenceError.couldNotCreateUnicodeScalarFromUInt32(
                    index: self.readerIndex, unicodeScalarValue: UInt32(bitPattern)
                )
            }
            return unicode
        }

        private mutating func parseUnicodeHexSequence() throws -> UInt16 {
            // As stated in RFC-8259 an escaped unicode character is 4 HEXDIGITs long
            // https://tools.ietf.org/html/rfc8259#section-7
            let startIndex = self.readerIndex
            guard let firstHex = self.read(),
                  let secondHex = self.read(),
                  let thirdHex = self.read(),
                  let forthHex = self.read()
            else {
                throw JSONScannerError.unexpectedEndOfFile
            }

            guard let first = DocumentReader.hexAsciiTo4Bits(firstHex),
                  let second = DocumentReader.hexAsciiTo4Bits(secondHex),
                  let third = DocumentReader.hexAsciiTo4Bits(thirdHex),
                  let forth = DocumentReader.hexAsciiTo4Bits(forthHex)
            else {
                let hexString = String(decoding: [firstHex, secondHex, thirdHex, forthHex], as: Unicode.UTF8.self)
                throw JSONScannerError.invalidHexDigitSequence(hexString, index: startIndex)
            }
            let firstByte = UInt16(first) << 4 | UInt16(second)
            let secondByte = UInt16(third) << 4 | UInt16(forth)

            let bitPattern = UInt16(firstByte) << 8 | UInt16(secondByte)

            return bitPattern
        }

        private static func hexAsciiTo4Bits(_ ascii: UInt8) -> UInt8? {
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

        // MARK: Numbers

        private enum ControlCharacter {
            case operand
            case decimalPoint
            case exp
            case expOperator
        }

        private mutating func parseNumber() throws {
            var pastControlChar: ControlCharacter = .operand
            var numbersSinceControlChar: UInt = 0
            var hasLeadingZero = false

            // parse first character
            guard let ascii = self.peek() else {
                preconditionFailure("Why was this function called, if there is no 0...9 or -")
            }
            switch ascii {
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

            var numberchars = 1

            // parse everything else
            while let byte = self.peek(offset: numberchars) {
                switch byte {
                case UInt8(ascii: "0"):
                    if hasLeadingZero {
                        throw JSONScannerError.numberWithLeadingZero(index: readerIndex + numberchars)
                    }
                    if numbersSinceControlChar == 0, pastControlChar == .operand {
                        // the number started with a minus. this is the leading zero.
                        hasLeadingZero = true
                    }
                    numberchars += 1
                    numbersSinceControlChar += 1
                case UInt8(ascii: "1") ... UInt8(ascii: "9"):
                    if hasLeadingZero {
                        throw JSONScannerError.numberWithLeadingZero(index: readerIndex + numberchars)
                    }
                    numberchars += 1
                    numbersSinceControlChar += 1
                case UInt8(ascii: "."):
                    guard numbersSinceControlChar > 0, pastControlChar == .operand else {
                        throw JSONScannerError.unexpectedCharacter(ascii: byte, characterIndex: readerIndex + numberchars)
                    }

                    numberchars += 1
                    hasLeadingZero = false
                    pastControlChar = .decimalPoint
                    numbersSinceControlChar = 0

                case UInt8(ascii: "e"), UInt8(ascii: "E"):
                    guard numbersSinceControlChar > 0,
                          pastControlChar == .operand || pastControlChar == .decimalPoint
                    else {
                        throw JSONScannerError.unexpectedCharacter(ascii: byte, characterIndex: readerIndex + numberchars)
                    }

                    numberchars += 1
                    hasLeadingZero = false
                    pastControlChar = .exp
                    numbersSinceControlChar = 0
                case UInt8(ascii: "+"), UInt8(ascii: "-"):
                    guard numbersSinceControlChar == 0, pastControlChar == .exp else {
                        throw JSONScannerError.unexpectedCharacter(ascii: byte, characterIndex: readerIndex + numberchars)
                    }

                    numberchars += 1
                    pastControlChar = .expOperator
                    numbersSinceControlChar = 0
                case .space, .return, .newline, .tab, .comma, .closeArray, .closeObject:
                    guard numbersSinceControlChar > 0 else {
                        throw JSONScannerError.unexpectedCharacter(ascii: byte, characterIndex: readerIndex + numberchars)
                    }
                    //let numberStartIndex = self.readerIndex
                    self.moveReaderIndex(forwardBy: numberchars)

                    return
                default:
                    throw JSONScannerError.unexpectedCharacter(ascii: byte, characterIndex: readerIndex + numberchars)
                }
            }

            guard numbersSinceControlChar > 0 else {
                throw JSONScannerError.unexpectedEndOfFile
            }

            defer { self.readerIndex = self.array.endIndex }
            return
        }
    }
}
