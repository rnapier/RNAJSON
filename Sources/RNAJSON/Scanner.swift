//
//  Scanner.swift
//  
//
//  Created by Rob Napier on 7/24/22.
//

import Foundation

public struct JSONScanner {
    var reader: DocumentReader

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
                try reader.consumeString()
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
                try reader.consumeNumber()
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

    // MARK: - Object parsing -
    mutating func consumeObject() throws /*-> [String: JSONValue]*/ {
        precondition(self.reader.read() == .openObject)

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
            try reader.consumeString()  // Key
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

    // MARK: - Parse Array -
    mutating func consumeArray() throws {
        precondition(self.reader.read() == .openArray)

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
}

public enum JSONScannerError: Swift.Error, Equatable {
    case cannotConvertInputDataToUTF8
    case unexpectedCharacter(ascii: UInt8, characterIndex: Int)
    case unexpectedEndOfFile
    case tooManyNestedArraysOrDictionaries(characterIndex: Int)
    case invalidHexDigitSequence(String, index: Int)
    case unexpectedEscapedCharacter(ascii: UInt8, index: Int)
    case unescapedControlCharacterInString(ascii: UInt8, index: Int)
    case expectedLowSurrogateUTF8SequenceAfterHighSurrogate(in: String, index: Int)
    case couldNotCreateUnicodeScalarFromUInt32(in: String, index: Int, unicodeScalarValue: UInt32)
    case numberWithLeadingZero(index: Int)
    case numberIsNotRepresentableInSwift(parsed: String)
    case singleFragmentFoundButNotAllowed
}

extension JSONScanner {

    struct DocumentReader {
        let array: [UInt8]

        private(set) var readerIndex: Int = 0

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

        mutating func consumeString() throws  {
            guard self.read() == .quote else {
                throw JSONScannerError.unexpectedCharacter(ascii: self.peek(offset: -1)!, characterIndex: self.readerIndex - 1)
            }
            var copy = 0

            while let byte = peek(offset: copy) {
                switch byte {
                case UInt8(ascii: "\""):
                    self.moveReaderIndex(forwardBy: copy + 1)
                    return

                case 0 ... 31:
                    // All Unicode characters may be placed within the
                    // quotation marks, except for the characters that must be escaped:
                    // quotation mark, reverse solidus, and the control characters (U+0000
                    // through U+001F).
                    let errorIndex = self.readerIndex + copy
                    throw JSONScannerError.unescapedControlCharacterInString(ascii: byte, index: errorIndex)

                case UInt8(ascii: "\\"):
                    self.moveReaderIndex(forwardBy: copy)
                    try consumeEscapeSequence()
                    copy = 0

                default:
                    copy += 1
                    continue
                }
            }

            throw JSONScannerError.unexpectedEndOfFile
        }
        private mutating func consumeEscapeSequence() throws {
            precondition(self.read() == .backslash, "Expected to have an backslash first")
            guard let ascii = self.read() else {
                throw JSONScannerError.unexpectedEndOfFile
            }

            switch ascii {
            case 0x22, // quote
                0x5C, // backslash
                0x2F, // slash
                0x62, // \b
                0x66, // \f
                0x6E, // \n
                0x72, // \r
                0x74: // \t
                return
            case 0x75: // \u
                try consumeUnicodeHexSequence()
                return
            default:
                throw JSONScannerError.unexpectedEscapedCharacter(ascii: ascii, index: self.readerIndex - 1)
            }
        }

        private mutating func consumeUnicodeHexSequence() throws {
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

            guard DocumentReader.isHexAscii(firstHex),
                  DocumentReader.isHexAscii(secondHex),
                  DocumentReader.isHexAscii(thirdHex),
                  DocumentReader.isHexAscii(forthHex)
            else {
                let hexString = String(decoding: [firstHex, secondHex, thirdHex, forthHex], as: Unicode.UTF8.self)
                throw JSONScannerError.invalidHexDigitSequence(hexString, index: startIndex)
            }
        }

        private static func isHexAscii(_ ascii: UInt8) -> Bool {
            switch ascii {
            case 48 ... 57:
                return true
            case 65 ... 70:
                // uppercase letters
                return true
            case 97 ... 102:
                // lowercase letters
                return true
            default:
                return false
            }
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

        mutating func consumeNumber() throws {
            // parse first character
            guard let ascii = self.peek() else {
                preconditionFailure("Why was this function called, if there is no 0...9 or -")
            }
            switch ascii {
            case UInt8(ascii: "0"),
                UInt8(ascii: "1") ... UInt8(ascii: "9"),
                UInt8(ascii: "-"): break

            default:
                preconditionFailure("Why was this function called, if there is no 0...9 or -")
            }

            var numberchars = 1

            // parse everything else
            while let byte = self.peek(offset: numberchars) {
                switch byte {
                case UInt8(ascii: "0"),
                    UInt8(ascii: "1") ... UInt8(ascii: "9"),
                    UInt8(ascii: "."),
                    UInt8(ascii: "e"), UInt8(ascii: "E"),
                    UInt8(ascii: "+"), UInt8(ascii: "-"):
                    numberchars += 1

                case .space, .return, .newline, .tab, .comma, .closeArray, .closeObject:
                    self.moveReaderIndex(forwardBy: numberchars)
                    return
                default:
                    throw JSONScannerError.unexpectedCharacter(ascii: byte, characterIndex: readerIndex + numberchars)
                }
            }
        }
    }
}
