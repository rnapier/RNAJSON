public enum JSONError: Swift.Error, Hashable, Sendable {
    public struct Location: Hashable, Sendable {
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
}
