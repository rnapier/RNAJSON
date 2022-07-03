import XCTest

import RNAJSON
import AsyncAlgorithms

typealias Location = JSONError.Location

final class JSONTokenizerTests: XCTestCase {
    func testSingleDigit() async throws {
        let json = Data("""
        1
        """.utf8).async
        let result = try await Array(json.jsonTokens)
        XCTAssertEqual(result, [1])
    }

    func testInteger() async throws {
        let json = Data("""
        10
        """.utf8).async
        let result = try await Array(json.jsonTokens)
        XCTAssertEqual(result, [10])
    }

    func testFloat() async throws {
        let json = Data("""
        10.1
        """.utf8).async
        let result = try await Array(json.jsonTokens)
        XCTAssertEqual(result, [10.1])
    }

    func testSingleLetter() async throws {
        let json = Data("""
        "a"
        """.utf8).async
        let result = try await Array(json.jsonTokens)
        XCTAssertEqual(result, ["a"])
    }

    func testString() async throws {
        let json = Data("""
        "testString"
        """.utf8).async
        let result = try await Array(json.jsonTokens)
        XCTAssertEqual(result, ["testString"])
    }

    func testQuote() async throws {
        let json = Data(#"""
        "\""
        """#.utf8).async
        let result = try await Array(json.jsonTokens)
        XCTAssertEqual(result, ["\""])
    }

    func testCompactArray() async throws {
        let json = Data("""
        [1,2,3]
        """.utf8).async
        let result = try await Array(json.jsonTokens)
        XCTAssertEqual(result, [.arrayOpen, 1, 2, 3, .arrayClose])
    }

    func testRunOnLiteral() async throws {
        let json = Data("""
        trueabc
        """.utf8).async

        let expected: [JSONToken] =
        [true]

        try await XCTAssert(json.jsonTokens,
                            returns: expected,
                            throws: .unexpectedCharacter(ascii: UInt8(ascii: "a"), Location(line: 1, column: 4, index: 4)))
    }

    // pass1
    func testComplexJSON() async throws {
        let json = Data(#"""
        [
            "JSON Test Pattern pass1",
            {"object with 1 member":["array with 1 element"]},
            {},
            [],
            -42,
            true,
            false,
            null,
            {
                "integer": 1234567890,
                "real": -9876.543210,
                "e": 0.123456789e-12,
                "E": 1.234567890E+34,
                "":  23456789012E66,
                "zero": 0,
                "one": 1,
                "space": " ",
                "quote": "\"",
                "backslash": "\\",
                "controls": "\b\f\n\r\t",
                "slash": "/ & \/",
                "alpha": "abcdefghijklmnopqrstuvwyz",
                "ALPHA": "ABCDEFGHIJKLMNOPQRSTUVWYZ",
                "digit": "0123456789",
                "0123456789": "digit",
                "special": "`1~!@#$%^&*()_+-={':[,]}|;.</>?",
                "hex": "\u0123\u4567\u89AB\uCDEF\uabcd\uef4A",
                "true": true,
                "false": false,
                "null": null,
                "array":[  ],
                "object":{  },
                "address": "50 St. James Street",
                "url": "http://www.JSON.org/",
                "comment": "// /* <!-- --",
                "# -- --> */": " ",
                " s p a c e d " :[1,2 , 3

        ,

        4 , 5        ,          6           ,7        ],"compact":[1,2,3,4,5,6,7],
                "jsontext": "{\"object with 1 member\":[\"array with 1 element\"]}",
                "quotes": "&#34; \u0022 %22 0x22 034 &#x22;",
                "\/\\\"\uCAFE\uBABE\uAB98\uFCDE\ubcda\uef4A\b\f\n\r\t`1~!@#$%^&*()_+-=[]{}|;:',./<>?"
        : "A key can be any string"
            },
            0.5 ,98.6
        ,
        99.44
        ,

        1066,
        1e1,
        0.1e1,
        1e-1,
        1e00,2e+00,2e-00
        ,"rosebud"]
        """#.utf8).async

        let expected: [JSONToken] =
        [.arrayOpen,
         "JSON Test Pattern pass1",
         .objectOpen, .key("object with 1 member"), .arrayOpen, "array with 1 element", .arrayClose, .objectClose,
         .objectOpen, .objectClose,
         .arrayOpen, .arrayClose,
         -42,
         true,
         false,
         .null,
         .objectOpen,
         .key("integer"), 1234567890,
         .key("real"), .digits("-9876.543210"),
         .key("e"), .digits("0.123456789e-12"),
         .key("E"), .digits("1.234567890E+34"),
         .key(""), .digits("23456789012E66"),
         .key("zero"), 0,
         .key("one"), 1,
         .key("space"), " ",
         .key("quote"), "\"",
         .key("backslash"), "\\",
         .key("controls"), "\u{08}\u{0C}\n\r\t",
         .key("slash"), "/ & /",
         .key("alpha"), "abcdefghijklmnopqrstuvwyz",
         .key("ALPHA"), "ABCDEFGHIJKLMNOPQRSTUVWYZ",
         .key("digit"), "0123456789",
         .key("0123456789"), "digit",
         .key("special"), "`1~!@#$%^&*()_+-={\':[,]}|;.</>?",
         .key("hex"), "ģ䕧覫췯ꯍ",
         .key("true"), true,
         .key("false"), false,
         .key("null"), .null,
         .key("array"), .arrayOpen, .arrayClose,
         .key("object"), .objectOpen, .objectClose,
         .key("address"), "50 St. James Street",
         .key("url"), "http://www.JSON.org/",
         .key("comment"), "// /* <!-- --",
         .key("# -- --> */"), " ",
         .key(" s p a c e d "), .arrayOpen, 1, 2, 3, 4, 5, 6, 7, .arrayClose,
         .key("compact"), .arrayOpen, 1, 2, 3, 4, 5, 6, 7, .arrayClose,
         .key("jsontext"), "{\"object with 1 member\":[\"array with 1 element\"]}",
         .key("quotes"), "&#34; \" %22 0x22 034 &#x22;",
         .key("/\\\"쫾몾ꮘﳞ볚\u{08}\u{0C}\n\r\t`1~!@#$%^&*()_+-=[]{}|;:\',./<>?"), "A key can be any string",
         .objectClose,
         0.5, 98.6,
         99.44,
         1066,
         .digits("1e1"),
         .digits("0.1e1"),
         .digits("1e-1"),
         .digits("1e00"),
         .digits("2e+00"),
         .digits("2e-00"),
         "rosebud", .arrayClose]

        try await XCTAssertDeepEqual(json.jsonTokens, expected)
    }

    // pass2
    func testDeepJSON() async throws {
        let url = Bundle.module.url(forResource: "json.org/pass2.json", withExtension: nil)!
        let json = try Data(contentsOf: url).async

        let expected: [JSONToken] =
        repeatElement(JSONToken.arrayOpen, count: 19) + ["Not too deep"] + repeatElement(JSONToken.arrayClose, count: 19)

        try await XCTAssertDeepEqual(json.jsonTokens, expected)
    }

    // fail1
    func testDisallowedFragments() async throws {
        let json = Array("""
        "A JSON payload should be an object or array, not a string."
        """.utf8).async

        let expected: [JSONToken] =
        []

        let tokens = AsyncJSONTokenSequence(json, strict: true)

        try await XCTAssert(tokens,
                            returns: expected,
                            throws: .jsonFragmentDisallowed)
    }

    // fail2
    func testUnclosedArray() async throws {
        let json = Array("""
        ["Unclosed array"
        """.utf8).async

        let expected: [JSONToken] =
        [.arrayOpen, "Unclosed array"]

        try await XCTAssert(json.jsonTokens,
                            returns: expected,
                            throws: .unexpectedEndOfFile(Location(line: 1, column: 17, index: 17)))
    }

    // fail3
    func testUnquotedKey() async throws {
        let json = Data("""
        {unquoted_key: "keys must be quoted"}
        """.utf8).async

        let expected: [JSONToken] =
        [.objectOpen]

        try await XCTAssert(json.jsonTokens,
                            returns: expected,
                            throws: .missingKey(Location(line: 1, column: 1, index: 1)))
    }

    // fail4
    func testExtraCommaStrict() async throws {
        let json = Data("""
        ["extra comma",]
        """.utf8).async

        let expected: [JSONToken] =
        [.arrayOpen, "extra comma"]

        try await XCTAssert(AsyncJSONTokenSequence(json, strict: true),
                            returns: expected,
                            throws: .unexpectedCharacter(ascii: UInt8(ascii: "]"),
                                                         Location(line: 1, column: 15, index: 15)))
    }

    // fail4 -- JSONSerialization allows trailing comma
    func testExtraCommaAllowed() async throws {
        let json = Data("""
        ["extra comma",]
        """.utf8).async

        let expected: [JSONToken] =
        [.arrayOpen, "extra comma", .arrayClose]

        try await XCTAssertDeepEqual(json.jsonTokens, expected)
    }

    // fail5
    func testDoubleExtraComma() async throws {
        let json = Data("""
        ["double extra comma",,]
        """.utf8).async

        let expected: [JSONToken] =
        [.arrayOpen, "double extra comma"]

        try await XCTAssert(json.jsonTokens,
                            returns: expected,
                            throws: .unexpectedCharacter(ascii: UInt8(ascii: ","),
                                                         Location(line: 1, column: 22, index: 22)))
    }

    // fail6
    func testMissingValue() async throws {
        let json = Data("""
        [   , "<-- missing value"]
        """.utf8).async

        let expected: [JSONToken] =
        [.arrayOpen]

        try await XCTAssert(json.jsonTokens,
                            returns: expected,
                            throws: .unexpectedCharacter(ascii: UInt8(ascii: ","),
                                                         Location(line: 1, column: 4, index: 4)))
    }

    // fail7
    func testCommaAfterTheClose() async throws {
        let json = Data("""
        ["Comma after the close"],
        """.utf8).async

        let expected: [JSONToken] =
        [.arrayOpen, "Comma after the close", .arrayClose]

        try await XCTAssert(json.jsonTokens,
                            returns: expected,
                            throws: .unexpectedCharacter(ascii: UInt8(ascii: ","),
                                                         Location(line: 1, column: 25, index: 25)))
    }

    // fail8
    func testExtraClose() async throws {
        let json = Data("""
        ["Extra close"]]
        """.utf8).async

        let expected: [JSONToken] =
        [.arrayOpen, "Extra close", .arrayClose]

        try await XCTAssert(json.jsonTokens,
                            returns: expected,
                            throws: .unexpectedCharacter(ascii: UInt8(ascii: "]"),
                                                         Location(line: 1, column: 15, index: 15)))
    }

    // fail9
    func testExtraCommaObjectStrict() async throws {
        let json = Data("""
        {"Extra comma": true,}
        """.utf8).async

        let expected: [JSONToken] =
        [.objectOpen, .key("Extra comma"), .true]

        try await XCTAssert(AsyncJSONTokenSequence(json, strict: true),
                            returns: expected,
                            throws: .missingKey(Location(line: 1, column: 21, index: 21)))
    }

    // fail9 -- JSONSerialization allows trailing comma
    func testExtraCommaObjectAllowed() async throws {
        let json = Data("""
        {"Extra comma": true,}
        """.utf8).async

        let expected: [JSONToken] =
        [.objectOpen, .key("Extra comma"), .true, .objectClose]

        try await XCTAssertDeepEqual(json.jsonTokens, expected)
    }

    // fail10
    func testExtraValueAfterClose() async throws {
        let json = Data("""
        {"Extra value after close": true} "misplaced quoted value"
        """.utf8).async

        let expected: [JSONToken] =
        [.objectOpen, .key("Extra value after close"), .true, .objectClose]

        try await XCTAssert(json.jsonTokens,
                            returns: expected,
                            throws: .unexpectedCharacter(ascii: UInt8(ascii: "\""),
                                                         Location(line: 1, column: 34, index: 34)))
    }

    // fail11
    func testIllegalExpression() async throws {
        let json = Data("""
        {"Illegal expression": 1 + 2}
        """.utf8).async

        let expected: [JSONToken] =
        [.objectOpen, .key("Illegal expression"), 1]

        try await XCTAssert(json.jsonTokens,
                            returns: expected,
                            throws: .unexpectedCharacter(ascii: UInt8(ascii: "+"),
                                                         Location(line: 1, column: 25, index: 25)))
    }

    // fail12
    func testIllegalInvocation() async throws {
        let json = Data("""
        {"Illegal invocation": alert()}
        """.utf8).async

        let expected: [JSONToken] =
        [.objectOpen, .key("Illegal invocation")]

        try await XCTAssert(json.jsonTokens,
                            returns: expected,
                            throws: .unexpectedCharacter(ascii: UInt8(ascii: "a"),
                                                         Location(line: 1, column: 23, index: 23)))
    }

    // fail13
    func testLeadingZeros() async throws {
        let json = Data("""
        {"Numbers cannot have leading zeroes": 013}
        """.utf8).async

        let expected: [JSONToken] =
        [.objectOpen, .key("Numbers cannot have leading zeroes")]

        try await XCTAssert(json.jsonTokens,
                            returns: expected,
                            throws: .numberWithLeadingZero(Location(line: 1, column: 40, index: 40)))
    }

    func testDoubleLeadingZeros() async throws {
        let json = Data("""
        {"Numbers cannot have leading zeroes": 0013}
        """.utf8).async

        let expected: [JSONToken] =
        [.objectOpen, .key("Numbers cannot have leading zeroes")]

        try await XCTAssert(json.jsonTokens,
                            returns: expected,
                            throws: .numberWithLeadingZero(Location(line: 1, column: 40, index: 40)))
    }

    func testMinusLeadingZero() async throws {
        let json = Data("""
        {"Numbers cannot have leading zeroes": -013}
        """.utf8).async

        let expected: [JSONToken] =
        [.objectOpen, .key("Numbers cannot have leading zeroes")]

        try await XCTAssert(json.jsonTokens,
                            returns: expected,
                            throws: .numberWithLeadingZero(Location(line: 1, column: 41, index: 41)))
    }

    // fail14
    func testNumbersCannotBeHex() async throws {
        let json = Data("""
        {"Numbers cannot be hex": 0x14}
        """.utf8).async

        let expected: [JSONToken] =
        [.objectOpen, .key("Numbers cannot be hex")]

        try await XCTAssert(json.jsonTokens,
                            returns: expected,
                            throws: .unexpectedCharacter(ascii: UInt8(ascii: "x"),
                                                         Location(line: 1, column: 27, index: 27)))
    }

    // fail15
    func testIllegalBackslashEscape() async throws {
        let json = Data(#"""
        ["Illegal backslash escape: \x15"]
        """#.utf8).async

        let expected: [JSONToken] =
        [.arrayOpen]

        try await XCTAssert(json.jsonTokens,
                            returns: expected,
                            throws: .unexpectedEscapedCharacter(ascii: UInt8(ascii: "x"), in: "Illegal backslash escape: ",
                                                                Location(line: 1, column: 29, index: 29)))
    }

    // fail16
    func testBackslashOutsideString() async throws {
        let json = Data(#"""
        [\naked]
        """#.utf8).async

        let expected: [JSONToken] =
        [.arrayOpen]

        try await XCTAssert(json.jsonTokens,
                            returns: expected,
                            throws: .unexpectedCharacter(ascii: UInt8(ascii: "\\"),
                                                         Location(line: 1, column: 1, index: 1)))
    }

    // fail17
    func testIllegalBackslashEscapeWithLeadingZero() async throws {
        let json = Data(#"""
        ["Illegal backslash escape: \017"]
        """#.utf8).async

        let expected: [JSONToken] =
        [.arrayOpen]

        try await XCTAssert(json.jsonTokens,
                            returns: expected,
                            throws: .unexpectedEscapedCharacter(ascii: UInt8(ascii: "0"), in: "Illegal backslash escape: ",
                                                                Location(line: 1, column: 29, index: 29)))
    }

    // fail19
    func testMissingColon() async throws {
        let json = Data(#"""
        {"Missing colon" null}
        """#.utf8).async

        let expected: [JSONToken] =
        [.objectOpen, .key("Missing colon")]

        try await XCTAssert(json.jsonTokens,
                            returns: expected,
                            throws: .missingObjectValue(Location(line: 1, column: 17, index: 17)))
    }

    // fail20
    func testDoubleColon() async throws {
        let json = Data(#"""
        {"Double colon":: null}
        """#.utf8).async

        let expected: [JSONToken] =
        [.objectOpen, .key("Double colon")]

        try await XCTAssert(json.jsonTokens,
                            returns: expected,
                            throws: .unexpectedCharacter(ascii: UInt8(ascii: ":"),
                                                         Location(line: 1, column: 16, index: 16)))
    }

    // fail21
    func testCommaInsteadOfColon() async throws {
        let json = Data(#"""
        {"Comma instead of colon", null}
        """#.utf8).async

        let expected: [JSONToken] =
        [.objectOpen, .key("Comma instead of colon")]

        try await XCTAssert(json.jsonTokens,
                            returns: expected,
                            throws: .missingObjectValue(Location(line: 1, column: 25, index: 25)))
    }

    // fail22
    func testColonInsteadOfComma() async throws {
        let json = Data(#"""
        ["Colon instead of comma": false]
        """#.utf8).async

        let expected: [JSONToken] =
        [.arrayOpen, "Colon instead of comma"]

        try await XCTAssert(json.jsonTokens,
                            returns: expected,
                            throws: .unexpectedCharacter(ascii: UInt8(ascii: ":"),
                                                         Location(line: 1, column: 25, index: 25)))
    }

    // fail23
    // FIXME: Improve error?
    func testBadValue() async throws {
        let json = Data(#"""
        ["Bad value", truth]
        """#.utf8).async

        let expected: [JSONToken] =
        [.arrayOpen, "Bad value"]

        try await XCTAssert(json.jsonTokens,
                            returns: expected,
                            throws: .corruptedLiteral(expected: "true",
                                                         Location(line: 1, column: 17, index: 17)))
    }

    // fail24
    func testSingleQuote() async throws {
        let json = Data(#"""
        ['single quote']
        """#.utf8).async

        let expected: [JSONToken] =
        [.arrayOpen]

        try await XCTAssert(json.jsonTokens,
                            returns: expected,
                            throws: .unexpectedCharacter(ascii: UInt8(ascii: "'"),
                                                         Location(line: 1, column: 1, index: 1)))
    }

    // fail25
    func testTabCharacterInString() async throws {
        let json = Data("[\"\ttab\tcharacter\tin\tstring\t\"]".utf8).async

        let expected: [JSONToken] =
        [.arrayOpen]

        try await XCTAssert(json.jsonTokens,
                            returns: expected,
                            throws: .unescapedControlCharacterInString(ascii: UInt8(ascii: "\t"), in: "",
                                                                       Location(line: 1, column: 2, index: 2)))
    }

    // fail26 (in test case, there are no tabs)
    func testEscapedSpacesInString() async throws {
        let json = Data(#"""
        ["tab\   character\   in\  string\  "]
        """#.utf8).async

        let expected: [JSONToken] =
        [.arrayOpen]

        try await XCTAssert(json.jsonTokens,
                            returns: expected,
                            throws: .unexpectedEscapedCharacter(ascii: UInt8(ascii: " "), in: "tab",
                                                                Location(line: 1, column: 6, index: 6)))
    }

    // fail27
    func testLineBreakInString() async throws {
        let json = Data(#"""
        ["line
        break"]
        """#.utf8).async

        let expected: [JSONToken] =
        [.arrayOpen]

        try await XCTAssert(json.jsonTokens,
                            returns: expected,
                            throws: .unescapedControlCharacterInString(ascii: UInt8(ascii: "\n"), in: "line",
                                                                       Location(line: 2, column: 0, index: 6)))
    }

    // fail28
    func testEscapedLineBreakInString() async throws {
        let json = Data(#"""
        ["line\
        break"]
        """#.utf8).async

        let expected: [JSONToken] =
        [.arrayOpen]

        try await XCTAssert(json.jsonTokens,
                            returns: expected,
                            throws: .unexpectedEscapedCharacter(ascii: UInt8(ascii: "\n"), in: "line",
                                                                Location(line: 2, column: 0, index: 7)))
    }

    // fail29
    func testInvalidExpNumber() async throws {
        let json = Data(#"""
        [0e]
        """#.utf8).async

        let expected: [JSONToken] =
        [.arrayOpen]

        try await XCTAssert(json.jsonTokens,
                            returns: expected,
                            throws: .missingExponent(Location(line: 1, column: 3, index: 3)))
    }

    // fail30
    func testInvalidExpNumberWithOperator() async throws {
        let json = Data(#"""
        [0e+]
        """#.utf8).async

        let expected: [JSONToken] =
        [.arrayOpen]

        try await XCTAssert(json.jsonTokens,
                            returns: expected,
                            throws: .missingExponent(Location(line: 1, column: 4, index: 4)))
    }

    // fail31
    func testTooManyExpSigns() async throws {
        let json = Data(#"""
        [0e+-1]
        """#.utf8).async

        let expected: [JSONToken] =
        [.arrayOpen]

        try await XCTAssert(json.jsonTokens,
                            returns: expected,
                            throws: .unexpectedCharacter(ascii: UInt8(ascii: "-"), Location(line: 1, column: 4, index: 4)))
    }

    // fail32
    func testCommaInsteadOfClosingBrace() async throws {
        let json = Data(#"""
        {"Comma instead if closing brace": true,
        """#.utf8).async

        let expected: [JSONToken] =
        [.objectOpen, .key("Comma instead if closing brace"), .true]

        try await XCTAssert(json.jsonTokens,
                            returns: expected,
                            throws: .unexpectedEndOfFile(Location(line: 1, column: 40, index: 40)))
    }

    // fail33
    func testBraceMismatch() async throws {
        let json = Data(#"""
        ["mismatch"}
        """#.utf8).async

        let expected: [JSONToken] =
        [.arrayOpen, "mismatch"]

        try await XCTAssert(json.jsonTokens,
                            returns: expected,
                            throws: .unexpectedCharacter(ascii: UInt8(ascii: "}"), Location(line: 1, column: 11, index: 11)))
    }

    func testTrailingEscape() async throws {
        let json = Data(#"""
        ["trailing escape \
        """#.utf8).async

        let expected: [JSONToken] =
        [.arrayOpen]

        try await XCTAssert(json.jsonTokens,
                            returns: expected,
                            throws: .unexpectedEndOfFile(Location(line: 1, column:19, index: 19)))

    }

    func testSurrogatePairs() async throws {
        let json = Data(#"""
        "\uD834\uDD1E"
        """#.utf8).async

        let expected: [JSONToken] =
        [.string("\u{1D11E}")]

        try await XCTAssertDeepEqual(json.jsonTokens, expected)
    }

    func testMissingLowSurrogatePair() async throws {
        let json = Data(#"""
        "\uD834"
        """#.utf8).async

        let expected: [JSONToken] =
        []

        try await XCTAssert(json.jsonTokens,
                            returns: expected,
                            throws: .expectedLowSurrogateUTF8SequenceAfterHighSurrogate(in: "", Location(line: 1, column: 7, index: 7)))
    }

    func testInvalidLowSurrogatePair() async throws {
        let json = Data(#"""
        "\uD834\uD834"
        """#.utf8).async

        let expected: [JSONToken] =
        []

        try await XCTAssert(json.jsonTokens,
                            returns: expected,
                            throws: .expectedLowSurrogateUTF8SequenceAfterHighSurrogate(in: "", Location(line: 1, column: 12, index: 12)))
    }

    func testOutOfRangeUnicode() async throws {
        let json = Data(#"""
        "\uDD1E\uD834"
        """#.utf8).async

        let expected: [JSONToken] =
        []

        try await XCTAssert(json.jsonTokens,
                            returns: expected,
                            throws: .couldNotCreateUnicodeScalarFromUInt32(in: "", Location(line: 1, column: 6, index: 6), unicodeScalarValue: 56606))
    }

    func testTruncatedUnicode() async throws {
        let json = Data(#"""
        "\u12
        """#.utf8).async

        let expected: [JSONToken] =
        []

        try await XCTAssert(json.jsonTokens,
                            returns: expected,
                            throws: .unexpectedEndOfFile(Location(line: 1, column: 5, index: 5)))
    }

    func testInvalidHex() async throws {
        let json = Data(#"""
        "\u012x"
        """#.utf8).async

        let expected: [JSONToken] =
        []

        try await XCTAssert(json.jsonTokens,
                            returns: expected,
                            throws: .invalidHexDigitSequence("012x", Location(line: 1, column: 6, index: 6)))
    }

    func testDecimalAfterMinus() async throws {
        let json = Data(#"""
        -.1
        """#.utf8).async

        let expected: [JSONToken] =
        []

        try await XCTAssert(json.jsonTokens,
                            returns: expected,
                            throws: .unexpectedCharacter(ascii: UInt8(ascii: "."), Location(line: 1, column: 1, index: 1)))
    }

    func testEAfterMinus() async throws {
        let json = Data(#"""
        -e1
        """#.utf8).async

        let expected: [JSONToken] =
        []

        try await XCTAssert(json.jsonTokens,
                            returns: expected,
                            throws: .unexpectedCharacter(ascii: UInt8(ascii: "e"), Location(line: 1, column: 1, index: 1)))
    }

    func testSpaceAfterMinus() async throws {
        let json = Data(#"""
        - 1
        """#.utf8).async

        let expected: [JSONToken] =
        []

        try await XCTAssert(json.jsonTokens,
                            returns: expected,
                            throws: .unexpectedCharacter(ascii: UInt8(ascii: " "), Location(line: 1, column: 1, index: 1)))
    }

    func testEndOfFileAfterMinus() async throws {
        let json = Data(#"""
        -
        """#.utf8).async

        let expected: [JSONToken] =
        []

        try await XCTAssert(json.jsonTokens,
                            returns: expected,
                            throws: .unexpectedEndOfFile(Location(line: 1, column: 1, index: 1)))
    }

    func testTruncatedLiteral() async throws {
        let json = Data(#"""
        tru
        """#.utf8).async

        let expected: [JSONToken] =
        []

        try await XCTAssert(json.jsonTokens,
                            returns: expected,
                            throws: .unexpectedEndOfFile(Location(line: 1, column: 3, index: 3)))
    }

    func testArrayOfObjects() async throws {
        let json = Data(#"""
        {
            "id": 142,
            "name": "aerodactyl",
            "types": [{
                    "type": {
                        "name": "rock",
                        "url": "https://pokeapi.co/api/v2/type/6/"
                    },
                    "slot": 1
                },
                {
                    "type": {
                        "name": "flying",
                        "url": "https://pokeapi.co/api/v2/type/3/"
                    },
                    "slot": 2
                }
            ]
        }
        """#.utf8).async

        let expected: [JSONToken] =
        [
            .objectOpen,
            .objectKey("id"), .number("142"),
            .objectKey("name"), .string("aerodactyl"),
            .objectKey("types"),
            .arrayOpen,
            .objectOpen,
            .objectKey("type"), .objectOpen,
            .objectKey("name"), .string("rock"),
            .objectKey("url"), .string("https://pokeapi.co/api/v2/type/6/"),
            .objectClose,
            .objectKey("slot"), .number("1"),
            .objectClose,
            .objectOpen,
            .objectKey("type"), .objectOpen,
            .objectKey("name"), .string("flying"),
            .objectKey("url"), .string("https://pokeapi.co/api/v2/type/3/"),
            .objectClose,
            .objectKey("slot"), .number("2"),
            .objectClose,
            .arrayClose,
            .objectClose
        ]


        try await XCTAssertDeepEqual(json.jsonTokens, expected)

    }

}


private extension XCTest {
    func XCTAssertThrowsError<T: Sendable>(
        _ expression: @autoclosure () async throws -> T,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #filePath,
        line: UInt = #line,
        _ errorHandler: (_ error: Error) -> Void = { _ in }
    ) async {
        do {
            _ = try await expression()
            var message = message()
            if message.isEmpty { message = "Did not throw when expected" }
            XCTFail(message, file: file, line: line)
        } catch {
            errorHandler(error)
        }
    }

    func XCTAssert(_ sequence: AsyncJSONTokenSequence<some AsyncSequence>, returns values: [JSONToken], throws error: JSONError) async throws {
        var tokens = sequence.makeAsyncIterator()
        var values = values.makeIterator()

        while let expected = values.next(),
              let result = try await tokens.next() {
            XCTAssertEqual(result, expected)
        }

        await XCTAssertThrowsError(try await tokens.next()) {
            XCTAssertEqual($0 as? JSONError, error)
        }
    }

    func XCTAssertDeepEqual(_ lhs: AsyncJSONTokenSequence<some Any>, _ rhs: [JSONToken]) async throws {
        let lhs = try await Array(lhs)
        XCTAssertEqual(lhs.count, rhs.count)
        for (lhs, rhs) in zip(lhs, rhs) {
            XCTAssertEqual(lhs, rhs)
        }
    }
}
