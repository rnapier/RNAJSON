import XCTest

import RNAJSON
import AsyncAlgorithms

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

    func testCompactArray() async throws {
        let json = Data("""
        [1,2,3]
        """.utf8).async
        let result = try await Array(json.jsonTokens)
        XCTAssertEqual(result, [.arrayOpen, 1, 2, 3, .arrayClose])
    }

    func testComplexJSON() async throws {
        let url = Bundle.module.url(forResource: "json.org/pass1.json", withExtension: nil)!
        let json = try Data(contentsOf: url).async
        let result = try await Array(json.jsonTokens)

        let expected: [JSONToken] =
        [.arrayOpen, "JSON Test Pattern pass1", .objectOpen, .key("object with 1 member"), .arrayOpen, "array with 1 element", .arrayClose, .objectClose, .objectOpen, .objectClose, .arrayOpen, .arrayClose, -42, true, false, .null, .objectOpen, .key("integer"), 1234567890, .key("real"), .digits("-9876.543210"), .key("e"), .digits("0.123456789e-12"), .key("E"), .digits("1.234567890E+34"), .key(""), .digits("23456789012E66"), .key("zero"), 0, .key("one"), 1, .key("space"), " ", .key("quote"), #"\""#, .key("backslash"), #"\\"#, .key("controls"), #"\b\f\n\r\t"#, .key("slash"), #"/ & \/"#, .key("alpha"), "abcdefghijklmnopqrstuvwyz", .key("ALPHA"), "ABCDEFGHIJKLMNOPQRSTUVWYZ", .key("digit"), "0123456789", .key("0123456789"), "digit", .key("special"), "`1~!@#$%^&*()_+-={':[,]}|;.</>?", .key("hex"), #"\u0123\u4567\u89AB\uCDEF\uabcd\uef4A"#, .key("true"), true, .key("false"), false, .key("null"), .null, .key("array"), .arrayOpen, .arrayClose, .key("object"), .objectOpen, .objectClose, .key("address"), "50 St. James Street", .key("url"), "http://www.JSON.org/", .key("comment"), "// /* <!-- --", .key("# -- --> */"), " ", .key(" s p a c e d "), .arrayOpen, 1, 2, 3, 4, 5, 6, 7, .arrayClose, .key("compact"), .arrayOpen, 1, 2, 3, 4, 5, 6, 7, .arrayClose, .key("jsontext"), #"{\"object with 1 member\":[\"array with 1 element\"]}"#, .key("quotes"), #"&#34; \u0022 %22 0x22 034 &#x22;"#, .key(#"\/\\\"\uCAFE\uBABE\uAB98\uFCDE\ubcda\uef4A\b\f\n\r\t`1~!@#$%^&*()_+-=[]{}|;:',./<>?"#), "A key can be any string", .objectClose, 0.5, 98.6, 99.44, 1066, .digits("1e1"), .digits("0.1e1"), .digits("1e-1"), .digits("1e00"), .digits("2e+00"), .digits("2e-00"), "rosebud", .arrayClose]

        XCTAssertDeepEqual(result, expected)
    }

    func testDeepJSON() async throws {
        let url = Bundle.module.url(forResource: "json.org/pass2.json", withExtension: nil)!
        let json = try Data(contentsOf: url).async
        let result = try await Array(json.jsonTokens)

        let expected: [JSONToken] =
        repeatElement(JSONToken.arrayOpen, count: 19) + ["Not too deep"] + repeatElement(JSONToken.arrayClose, count: 19)

        XCTAssertDeepEqual(result, expected)
    }

    func testUnclosedArray() async throws {
        let json = Array("""
        ["Unclosed array"
        """.utf8).async

        let expected: [JSONToken] =
        [.arrayOpen, "Unclosed array"]

        try await XCTAssert(json.jsonTokens,
                            returns: expected,
                            throws: .unexpectedEndOfFile)
    }

    func testUnquotedKey() async throws {
        let json = Data("""
        {unquoted_key: "keys must be quoted"}
        """.utf8).async

        let expected: [JSONToken] =
        [.objectOpen]

        try await XCTAssert(json.jsonTokens,
                            returns: expected,
                            throws: .unexpectedCharacter(ascii: UInt8(ascii: "u"), characterIndex: 1))
    }

    func testExtraComma() async throws {
        let json = Data("""
        ["extra comma",]
        """.utf8).async

        let expected: [JSONToken] =
        [.arrayOpen, "extra comma"]

        try await XCTAssert(json.jsonTokens,
                            returns: expected,
                            throws: .unexpectedCharacter(ascii: UInt8(ascii: "]"), characterIndex: 15))
    }

    func testDoubleExtraComma() async throws {
        let json = Data("""
        ["double extra comma",,]
        """.utf8).async

        let expected: [JSONToken] =
        [.arrayOpen, "double extra comma"]

        try await XCTAssert(json.jsonTokens,
                            returns: expected,
                            throws: .unexpectedCharacter(ascii: UInt8(ascii: ","), characterIndex: 22))
    }

    func testMissingValue() async throws {
        let json = Data("""
        [   , "<-- missing value"]
        """.utf8).async

        let expected: [JSONToken] =
        [.arrayOpen]

        try await XCTAssert(json.jsonTokens,
                            returns: expected,
                            throws: .unexpectedCharacter(ascii: UInt8(ascii: ","), characterIndex: 4))
    }

    func testCommaAfterTheClose() async throws {
        let json = Data("""
        ["Comma after the close"],
        """.utf8).async

        let expected: [JSONToken] =
        [.arrayOpen, "Comma after the close", .arrayClose]

        try await XCTAssert(json.jsonTokens,
                            returns: expected,
                            throws: .unexpectedCharacter(ascii: UInt8(ascii: ","), characterIndex: 25))
    }

    func testExtraClose() async throws {
        let json = Data("""
        ["Extra close"]]
        """.utf8).async

        let expected: [JSONToken] =
        [.arrayOpen, "Extra close", .arrayClose]

        try await XCTAssert(json.jsonTokens,
                            returns: expected,
                            throws: .unexpectedCharacter(ascii: UInt8(ascii: "]"), characterIndex: 15))
    }

    func testExtraCommaObject() async throws {
        let json = Data("""
        {"Extra comma": true,}
        """.utf8).async

        let expected: [JSONToken] =
        [.objectOpen, .key("Extra comma"), .true]

        try await XCTAssert(json.jsonTokens,
                            returns: expected,
                            throws: .unexpectedCharacter(ascii: UInt8(ascii: "}"), characterIndex: 21))
    }

    func testExtraValueAfterClose() async throws {
        let json = Data("""
        {"Extra value after close": true} "misplaced quoted value"
        """.utf8).async

        let expected: [JSONToken] =
        [.objectOpen, .key("Extra value after close"), .true, .objectClose]

        try await XCTAssert(json.jsonTokens,
                            returns: expected,
                            throws: .unexpectedCharacter(ascii: UInt8(ascii: "\""), characterIndex: 34))
    }

    func testIllegalExpression() async throws {
        let json = Data("""
        {"Illegal expression": 1 + 2}
        """.utf8).async

        let expected: [JSONToken] =
        [.objectOpen, .key("Illegal expression"), 1]

        try await XCTAssert(json.jsonTokens,
                            returns: expected,
                            throws: .unexpectedCharacter(ascii: UInt8(ascii: "+"),                                 characterIndex: 25))
    }

    func testIllegalInvocation() async throws {
        let json = Data("""
        {"Illegal invocation": alert()}
        """.utf8).async

        let expected: [JSONToken] =
        [.objectOpen, .key("Illegal invocation")]

        try await XCTAssert(json.jsonTokens,
                            returns: expected,
                            throws: .unexpectedCharacter(ascii: UInt8(ascii: "a"),                                 characterIndex: 23))
    }

    func testLeadingZeros() async throws {
        let json = Data("""
        {"Numbers cannot have leading zeroes": 013}
        """.utf8).async

        let expected: [JSONToken] =
        [.objectOpen, .key("Numbers cannot have leading zeroes"), .digits("013"), .objectClose]

        let result = try await Array(json.jsonTokens)

        XCTAssertDeepEqual(result, expected)
    }

    func testNumbersCannotBeHex() async throws {
        let json = Data("""
        {"Numbers cannot be hex": 0x14}
        """.utf8).async

        let expected: [JSONToken] =
        [.objectOpen, .key("Numbers cannot be hex")]

        try await XCTAssert(json.jsonTokens,
                            returns: expected,
                            throws: .unexpectedCharacter(ascii: UInt8(ascii: "x"),                                 characterIndex: 27))
    }
}

extension XCTest {
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

    func XCTAssertDeepEqual(_ lhs: [JSONToken], _ rhs: [JSONToken]) {
        XCTAssertEqual(lhs.count, rhs.count)
        for (lhs, rhs) in zip(lhs, rhs) {
            XCTAssertEqual(lhs, rhs)
        }
    }
}
