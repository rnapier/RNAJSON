import Foundation

/// Removes unnecessary whitespace
public struct JSONCompactor {
    public init() {}

    public func compact(from data: some DataProtocol) throws -> Data {
        var compactor = DocumentReader(array: data)
        return try compactor.consumeValue()
    }
}

extension JSONCompactor {

    private struct DocumentReader<Source: DataProtocol> {
        let array: Source

        private(set) var readerIndex: Source.Index
        var offset: Int { array.distance(from: array.startIndex, to: readerIndex) }

        var isEOF: Bool {
            self.readerIndex >= self.array.endIndex
        }

        mutating func consumeValue() throws -> Data {
            while let byte = peek() {
                switch byte {
                case .quote:
                    return try consumeString()

                case .openObject:
                    return try consumeObject()

                case .openArray:
                    return try consumeArray()

                case UInt8(ascii: "f"), UInt8(ascii: "t"), UInt8(ascii: "n"):
                    return try consumeLiteral()

                case UInt8(ascii: "-"), UInt8(ascii: "0") ... UInt8(ascii: "9"):
                    return try consumeNumber()

                case .space, .return, .newline, .tab:
                    moveReaderIndex(forwardBy: 1)

                default:
                    throw JSONScannerError.unexpectedCharacter(ascii: byte, characterIndex: offset)
                }
            }

            throw JSONScannerError.unexpectedEndOfFile
        }

        mutating func consumeObject() throws -> Data {
            precondition(read() == .openObject)

            var result = Data([.openObject])

            // parse first value or end immediately
            switch try consumeWhitespace() {
            case .space, .return, .newline, .tab:
                preconditionFailure("Expected that all white space is consumed")
            case .closeObject:
                // if the first char after whitespace is a closing bracket, we found an empty array
                moveReaderIndex(forwardBy: 1)
                result.append(.closeObject)
                return result
            default:
                break
            }

            while true {
                result.append(try consumeString())
                let colon = try consumeWhitespace()
                guard colon == .colon else {
                    throw JSONScannerError.unexpectedCharacter(ascii: colon, characterIndex: offset)
                }
                result.append(.colon)
                moveReaderIndex(forwardBy: 1)
                try consumeWhitespace()

                result.append(try self.consumeValue())

                let commaOrBrace = try consumeWhitespace()
                switch commaOrBrace {
                case .closeObject:
                    moveReaderIndex(forwardBy: 1)
                    result.append(.closeObject)
                    return result

                case .comma:
                    moveReaderIndex(forwardBy: 1)
                    if try consumeWhitespace() == .closeObject {
                        // the foundation json implementation does support trailing commas
                        moveReaderIndex(forwardBy: 1)
                        result.append(.closeObject)
                        return result
                    }
                    result.append(.comma)
                    continue

                default:
                    throw JSONScannerError.unexpectedCharacter(ascii: commaOrBrace, characterIndex: offset)
                }
            }
        }

        mutating func consumeArray() throws -> Data {
            guard read() == .openArray else {
                throw JSONScannerError.unexpectedType(characterIndex: offset)
            }

            var result = Data([.openArray])

            // parse first value or end immediately
            if try consumeWhitespace() == .closeArray {
                // if the first char after whitespace is a closing bracket, we found an empty array
                moveReaderIndex(forwardBy: 1)
                result.append(.closeArray)
                return result
            }

            var index = 0

            // parse values
            while true {
                result.append(try consumeValue())
                index += 1

                // consume the whitespace after the value before the comma
                let ascii = try consumeWhitespace()
                switch ascii {
                case .closeArray:
                    moveReaderIndex(forwardBy: 1)
                    result.append(.closeArray)
                    return result
                case .comma:
                    // consume the comma
                    moveReaderIndex(forwardBy: 1)
                    // consume the whitespace before the next value
                    if try consumeWhitespace() == .closeArray {
                        // the foundation json implementation does support trailing commas
                        moveReaderIndex(forwardBy: 1)
                        result.append(.closeArray)
                        return result
                    }
                    result.append(.comma)
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

        mutating func consumeString() throws -> Data {
            guard self.read() == .quote else {
                throw JSONScannerError.unexpectedCharacter(ascii: self.peek(offset: -1)!, characterIndex: self.offset - 1)
            }

            var result = Data([.quote])

            let startIndex = readerIndex

            while let byte = read() {
                switch byte {
                case .quote:
                    result.append(contentsOf: array[startIndex ..< array.index(before: readerIndex)])
                    result.append(.quote)
                    return result

                case .backslash:
                   try advanceEscapedSequence()

                default:
                    continue
                }
            }
            throw JSONScannerError.unexpectedEndOfFile
        }

        private mutating func advanceEscapedSequence() throws {
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
                try advanceUnicodeHexSequence()
            default:
                throw JSONScannerError.unexpectedEscapedCharacter(ascii: ascii, index: offset - 1)
            }
        }

        private mutating func advanceUnicodeHexSequence() throws {
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

        mutating func consumeLiteral() throws -> Data {
            func consume(remainder: String) throws {
                for byte in remainder.utf8 {
                    guard self.read() == byte else {
                        throw isEOF ? JSONScannerError.unexpectedEndOfFile :
                        JSONScannerError.unexpectedCharacter(ascii: self.peek(offset: -1)!,
                                                             characterIndex: self.offset - 1)
                    }
                }
            }

            let startIndex = self.readerIndex

            switch self.read() {
            case UInt8(ascii: "t"): try consume(remainder: "rue")
            case UInt8(ascii: "f"): try consume(remainder: "alse")
            case UInt8(ascii: "n"): try consume(remainder: "ull")
            default: preconditionFailure("Expected to have `t`, `f`, or `n` as first character")
            }
            return Data(array[startIndex..<self.readerIndex])
        }

        mutating func consumeNumber() throws -> Data {
            var numberchars = 0

            let startIndex = self.readerIndex

            while let byte = self.peek(offset: numberchars) {
                switch byte {
                case UInt8(ascii: "0") ... UInt8(ascii: "9"),
                    UInt8(ascii: "."),
                    UInt8(ascii: "e"), UInt8(ascii: "E"),
                    UInt8(ascii: "+"), UInt8(ascii: "-"):
                    numberchars += 1

                case .space, .return, .newline, .tab, .comma, .closeArray, .closeObject:
                    self.moveReaderIndex(forwardBy: numberchars)
                    return Data(array[startIndex..<self.readerIndex])

                default:
                    throw JSONScannerError.unexpectedCharacter(ascii: byte, characterIndex: offset + numberchars)
                }
            }
            return Data(array[startIndex..<self.readerIndex])
        }
    }
}
