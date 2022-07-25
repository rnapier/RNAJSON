//
//  Scanner.swift
//  
//
//  Created by Rob Napier on 7/24/22.
//

import Foundation

public struct JSONScanner {
    private var reader: DocumentReader

    public init(bytes: [UInt8]) {
        self.reader = DocumentReader(array: bytes)
    }

    public mutating func dataForBody() throws -> some Collection<UInt8> {
        try reader.consumeWhitespace()
        let startIndex = reader.readerIndex
        try consumeValue()
        return reader.array[startIndex..<reader.readerIndex]
    }

    private mutating func consumeValue() throws {
        while let byte = reader.peek() {
            switch byte {
            case .quote:
                try reader.consumeString()
                return

            case .openObject:
                try consumeObject()
                return
                
            case .openArray:
                try consumeArray()
                return

            case UInt8(ascii: "f"), UInt8(ascii: "t"), UInt8(ascii: "n"):
                try reader.consumeLiteral()
                return

            case UInt8(ascii: "-"), UInt8(ascii: "0") ... UInt8(ascii: "9"):
                try reader.consumeNumber()
                return

            case .space, .return, .newline, .tab:
                reader.moveReaderIndex(forwardBy: 1)

            default:
                throw JSONScannerError.unexpectedCharacter(ascii: byte, characterIndex: self.reader.readerIndex)
            }
        }

        throw JSONScannerError.unexpectedEndOfFile
    }

    private mutating func consumeObject() throws {
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

    private mutating func consumeArray() throws {
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
    case unexpectedCharacter(ascii: UInt8, characterIndex: Int)
    case unexpectedEndOfFile
    case invalidHexDigitSequence(String, index: Int)
    case unexpectedEscapedCharacter(ascii: UInt8, index: Int)
}

extension JSONScanner {

    private struct DocumentReader {
        let array: [UInt8]

        private(set) var readerIndex: Int = 0

        var isEOF: Bool {
            self.readerIndex >= self.array.endIndex
        }

        init(array: [UInt8]) {
            self.array = array
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

            while let byte = read() {
                switch byte {
                case UInt8(ascii: "\""):
                    return

                case UInt8(ascii: "\\"):
                    try consumeEscapedSequence()

                default:
                    continue
                }
            }
            throw JSONScannerError.unexpectedEndOfFile
        }

        private mutating func consumeEscapedSequence() throws {
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
            default:
                throw JSONScannerError.unexpectedEscapedCharacter(ascii: ascii, index: self.readerIndex - 1)
            }
        }

        private mutating func consumeUnicodeHexSequence() throws {
            let startIndex = self.readerIndex
            guard let firstHex = self.read(),
                  let secondHex = self.read(),
                  let thirdHex = self.read(),
                  let forthHex = self.read()
            else {
                throw JSONScannerError.unexpectedEndOfFile
            }

            guard isHexAscii(firstHex),
                  isHexAscii(secondHex),
                  isHexAscii(thirdHex),
                  isHexAscii(forthHex)
            else {
                let hexString = String(decoding: [firstHex, secondHex, thirdHex, forthHex], as: Unicode.UTF8.self)
                throw JSONScannerError.invalidHexDigitSequence(hexString, index: startIndex)
            }
        }

        private func isHexAscii(_ ascii: UInt8) -> Bool {
            switch ascii {
            case 48 ... 57, // Digits
                65 ... 70,  // Uppercase
                97 ... 102: // Lowercase
                return true
            default:
                return false
            }
        }

        mutating func consumeLiteral() throws  {
            func consume(remainder: String) throws {
                for byte in remainder.utf8 {
                    guard self.read() == byte else {
                        throw isEOF ? JSONScannerError.unexpectedEndOfFile :
                        JSONScannerError.unexpectedCharacter(ascii: self.peek(offset: -1)!,
                                                             characterIndex: self.readerIndex - 1)
                    }
                }
            }

            switch self.read() {
            case UInt8(ascii: "t"):
                try consume(remainder: "rue")

            case UInt8(ascii: "f"):
                try consume(remainder: "alse")

            case UInt8(ascii: "n"):
                try consume(remainder: "ull")

            default:
                preconditionFailure("Expected to have `t`, `f`, or `n` as first character")
            }
        }

        mutating func consumeNumber() throws {
            var numberchars = 0

            while let byte = self.peek(offset: numberchars) {
                switch byte {
                case UInt8(ascii: "0") ... UInt8(ascii: "9"),
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
