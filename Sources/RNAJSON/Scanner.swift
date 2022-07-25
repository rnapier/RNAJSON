//
//  Scanner.swift
//  
//
//  Created by Rob Napier on 7/24/22.
//

import Foundation

public struct JSONCodingKey: CodingKey, CustomStringConvertible, ExpressibleByStringLiteral, ExpressibleByIntegerLiteral {
    public var description: String { stringValue }

    public let stringValue: String
    public init(_ string: String) { self.stringValue = string }
    public init?(stringValue: String) { self.init(stringValue) }
    public var intValue: Int?
    public init(intValue: Int) {
        self.stringValue = "Index \(intValue)"
        self.intValue = intValue
    }
    public init(stringLiteral value: String) { self.init(value) }
    public init(integerLiteral value: Int) { self.init(intValue: value) }
}

// Stripped down version of stdlib.
// https://github.com/apple/swift-corelibs-foundation/blob/main/Sources/Foundation/JSONSerialization%2BParser.swift

public struct JSONScanner {
    public init() {}

    public func extractData<Source>(from data: Source, forPath path: [CodingKey]) throws -> Source.SubSequence
    where Source: BidirectionalCollection<UInt8>
    {
        var reader = DocumentReader(array: data)

        try reader.consumeWhitespace()

        for key in path {
            if let index = key.intValue { try reader.consumeArray(toIndex: index) }
            else { try reader.consumeObject(key: key.stringValue) }
        }

        let startIndex = reader.readerIndex
        try reader.consumeValue()
        return reader.array[startIndex..<reader.readerIndex]
    }

    // Convenience to accept JSONCodingKey literals.
    public func extractData<Source>(from data: Source, forPath path: [JSONCodingKey]) throws -> Source.SubSequence
    where Source: BidirectionalCollection<UInt8>, Source.Index == Int {
        try extractData(from: data, forPath: path as [CodingKey])
    }
}

public enum JSONScannerError: Swift.Error, Equatable {
    case unexpectedCharacter(ascii: UInt8, characterIndex: Int)
    case unexpectedEndOfFile
    case invalidHexDigitSequence(String, index: Int)
    case unexpectedEscapedCharacter(ascii: UInt8, index: Int)
    case indexNotFound(characterIndex: Int)
    case unexpectedType(characterIndex: Int)
    case keyNotFound(characterIndex: Int)
}

extension JSONScanner {

    private struct DocumentReader<Source: BidirectionalCollection<UInt8>> {
        let array: Source

        private(set) var readerIndex: Source.Index
        var offset: Int { array.distance(from: array.startIndex, to: readerIndex) }

        var isEOF: Bool {
            self.readerIndex >= self.array.endIndex
        }

        mutating func consumeValue() throws {
            while let byte = peek() {
                switch byte {
                case .quote:
                    try consumeString()
                    return

                case .openObject:
                    try consumeObject()
                    return

                case .openArray:
                    try consumeArray()
                    return

                case UInt8(ascii: "f"), UInt8(ascii: "t"), UInt8(ascii: "n"):
                    try consumeLiteral()
                    return

                case UInt8(ascii: "-"), UInt8(ascii: "0") ... UInt8(ascii: "9"):
                    try consumeNumber()
                    return

                case .space, .return, .newline, .tab:
                    moveReaderIndex(forwardBy: 1)

                default:
                    throw JSONScannerError.unexpectedCharacter(ascii: byte, characterIndex: offset)
                }
            }

            throw JSONScannerError.unexpectedEndOfFile
        }

        mutating func consumeObject(key: String? = nil) throws {
            precondition(read() == .openObject)

            // parse first value or end immediately
            switch try consumeWhitespace() {
            case .space, .return, .newline, .tab:
                preconditionFailure("Expected that all white space is consumed")
            case .closeObject:
                // if the first char after whitespace is a closing bracket, we found an empty array
                moveReaderIndex(forwardBy: 1)
                return
            default:
                break
            }

            while true {
                let thisKey = String(decoding: try consumeString(), as: UTF8.self)
                let colon = try consumeWhitespace()
                guard colon == .colon else {
                    throw JSONScannerError.unexpectedCharacter(ascii: colon, characterIndex: offset)
                }
                moveReaderIndex(forwardBy: 1)
                try consumeWhitespace()

                if thisKey == key { return }

                try self.consumeValue()

                let commaOrBrace = try consumeWhitespace()
                switch commaOrBrace {
                case .closeObject:
                    moveReaderIndex(forwardBy: 1)
                    if key != nil {
                        throw JSONScannerError.keyNotFound(characterIndex: offset)
                    }
                    return

                case .comma:
                    moveReaderIndex(forwardBy: 1)
                    if try consumeWhitespace() == .closeObject {
                        // the foundation json implementation does support trailing commas
                        moveReaderIndex(forwardBy: 1)
                        return
                    }
                    continue

                default:
                    throw JSONScannerError.unexpectedCharacter(ascii: commaOrBrace, characterIndex: offset)
                }
            }
        }

        mutating func consumeArray(toIndex: Int? = nil) throws {
            guard read() == .openArray else {
                throw JSONScannerError.unexpectedType(characterIndex: offset)
            }

            // parse first value or end immediately
            if try consumeWhitespace() == .closeArray {
                // if the first char after whitespace is a closing bracket, we found an empty array
                moveReaderIndex(forwardBy: 1)
                if toIndex != nil {
                    throw JSONScannerError.indexNotFound(characterIndex: offset)
                }
                return
            }

            var index = 0

            // parse values
            while index < (toIndex ?? .max) {
                try consumeValue()
                index += 1

                // consume the whitespace after the value before the comma
                let ascii = try consumeWhitespace()
                switch ascii {
                case .closeArray:
                    moveReaderIndex(forwardBy: 1)
                    if toIndex != nil {
                        throw JSONScannerError.indexNotFound(characterIndex: offset)
                    }
                    return
                case .comma:
                    // consume the comma
                    moveReaderIndex(forwardBy: 1)
                    // consume the whitespace before the next value
                    if try consumeWhitespace() == .closeArray {
                        // the foundation json implementation does support trailing commas
                        moveReaderIndex(forwardBy: 1)
                        return
                    }
                    continue
                default:
                    throw JSONScannerError.unexpectedCharacter(ascii: ascii, characterIndex: offset)
                }
            }
        }

        init(array: Source) {
            self.array = array
            self.readerIndex = array.startIndex
        }

        mutating func read() -> UInt8? {
            guard self.readerIndex < self.array.endIndex else {
                self.readerIndex = self.array.endIndex
                return nil
            }

            defer { array.formIndex(after: &readerIndex) }

            return self.array[self.readerIndex]
        }

        func peek(offset: Int = 0) -> UInt8? {
            guard let peekIndex = array.index(readerIndex, offsetBy: offset, limitedBy: array.endIndex) else {
                return nil
            }

            return self.array[peekIndex]
        }

        mutating func moveReaderIndex(forwardBy offset: Int) {
            array.formIndex(&readerIndex, offsetBy: offset)
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

        @discardableResult
        mutating func consumeString() throws -> some Collection<UInt8> {
            guard self.read() == .quote else {
                throw JSONScannerError.unexpectedCharacter(ascii: self.peek(offset: -1)!, characterIndex: self.offset - 1)
            }

            let startIndex = readerIndex

            while let byte = read() {
                switch byte {
                case UInt8(ascii: "\""):
                    return array[startIndex ..< array.index(before: readerIndex)]

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
                throw JSONScannerError.unexpectedEscapedCharacter(ascii: ascii, index: offset - 1)
            }
        }

        private mutating func consumeUnicodeHexSequence() throws {
            let startIndex = self.offset
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
                                                             characterIndex: self.offset - 1)
                    }
                }
            }

            switch self.read() {
            case UInt8(ascii: "t"): try consume(remainder: "rue")
            case UInt8(ascii: "f"): try consume(remainder: "alse")
            case UInt8(ascii: "n"): try consume(remainder: "ull")
            default: preconditionFailure("Expected to have `t`, `f`, or `n` as first character")
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
                    throw JSONScannerError.unexpectedCharacter(ascii: byte, characterIndex: offset + numberchars)
                }
            }
        }
    }
}
