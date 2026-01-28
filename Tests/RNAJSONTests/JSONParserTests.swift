// import XCTest
//
// import RNAJSON
// import AsyncAlgorithms
//
// final class JSONParserTests: XCTestCase {
//    func testSingleDigit() async throws {
//        let json = Array("""
//        1
//        """.utf8)
//        var parser = JSONParser(bytes: json)
//        let result = try parser.parse()
//        XCTAssertEqual(result, 1)
//    }
//
//    func assertEqualContainers(_ lhs: JSONValue, _ rhs: JSONValue) throws {
//        XCTAssertEqual(try lhs.count, try rhs.count)
//        switch (lhs, rhs) {
//        case (.array(let lhs), .array(let rhs)):
//            for (lhs, rhs) in zip(lhs, rhs) {
//                if lhs.isContainer {
//                    try assertEqualContainers(lhs, rhs)
//                } else {
//                    XCTAssertEqual(lhs, rhs)
//                }
//            }
//        case (.object(let lhs), .object(let rhs)):
//            for (lhs, rhs) in zip(lhs, rhs) {
//                XCTAssertEqual(lhs.key, rhs.key)
//                if lhs.value.isContainer {
//                    try assertEqualContainers(lhs.value, rhs.value)
//                } else {
//                    XCTAssertEqual(lhs.value, rhs.value)
//                }
//            }
//        default: XCTFail("\(lhs) or \(rhs) is not a container")
//        }
//    }
//
//    func testComplexJSON() async throws {
//        let url = Bundle.module.url(forResource: "json.org/pass1.json", withExtension: nil)!
//        let json = try Array(Data(contentsOf: url))
//        var parser = JSONParser(bytes: json)
//        let result = try parser.parse()
//
//        let expected: JSONValue =
//        ["JSON Test Pattern pass1", ["object with 1 member": ["array with 1 element"]], [:], [], -42, true, false, .null, ["integer": 1234567890, "real": .digits("-9876.543210"), "e": .digits("0.123456789e-12"), "E": .digits("1.234567890E+34"), "": .digits("23456789012E66"), "zero": 0, "one": 1, "space": " ", "quote": "\"", "backslash": "\\", "controls": "\u{08}\u{0C}\n\r\t", "slash": "/ & /", "alpha": "abcdefghijklmnopqrstuvwyz", "ALPHA": "ABCDEFGHIJKLMNOPQRSTUVWYZ", "digit": "0123456789", "0123456789": "digit", "special": "`1~!@#$%^&*()_+-={\':[,]}|;.</>?", "hex": "ģ䕧覫췯ꯍ", "true": true, "false": false, "null": .null, "array": [], "object": [:], "address": "50 St. James Street", "url": "http://www.JSON.org/", "comment": "// /* <!-- --", "# -- --> */": " ", " s p a c e d ": [1, 2, 3, 4, 5, 6, 7], "compact": [1, 2, 3, 4, 5, 6, 7], "jsontext": "{\"object with 1 member\":[\"array with 1 element\"]}", "quotes": "&#34; \" %22 0x22 034 &#x22;", "/\\\"쫾몾ꮘﳞ볚\u{08}\u{0C}\n\r\t`1~!@#$%^&*()_+-=[]{}|;:\',./<>?": "A key can be any string"], 0.5, 98.6, 99.44, 1066, .digits("1e1"), .digits("0.1e1"), .digits("1e-1"), .digits("1e00"), .digits("2e+00"), .digits("2e-00"), "rosebud"]
//
//        try assertEqualContainers(result, expected)
//    }
//
////    func testInteger() async throws {
////        let json = Data("""
////        10
////        """.utf8).async
////        let result = try await Array(json.jsonTokens)
////        XCTAssertEqual(result, [10])
////    }
////
////    func testFloat() async throws {
////        let json = Data("""
////        10.1
////        """.utf8).async
////        let result = try await Array(json.jsonTokens)
////        XCTAssertEqual(result, [10.1])
////    }
////
////    func testSingleLetter() async throws {
////        let json = Data("""
////        "a"
////        """.utf8).async
////        let result = try await Array(json.jsonTokens)
////        XCTAssertEqual(result, ["a"])
////    }
////
////    func testString() async throws {
////        let json = Data("""
////        "testString"
////        """.utf8).async
////        let result = try await Array(json.jsonTokens)
////        XCTAssertEqual(result, ["testString"])
////    }
////
////    func testCompactArray() async throws {
////        let json = Data("""
////        [1,2,3]
////        """.utf8).async
////        let result = try await Array(json.jsonTokens)
////        XCTAssertEqual(result, [.arrayOpen, 1, .comma, 2, .comma, 3, .arrayClose])
////    }
////
////    func testComplexJSON() async throws {
////        let url = Bundle.module.url(forResource: "json.org/pass1.json", withExtension: nil)!
////        let json = try Data(contentsOf: url).async
////        let result = try await Array(json.jsonTokens)
////
////        let expected: [JSONToken] =
////        [.arrayOpen, "JSON Test Pattern pass1", .comma, .objectOpen, "object with 1 member", .colon, .arrayOpen, "array with 1 element", .arrayClose, .objectClose, .comma, .objectOpen, .objectClose, .comma, .arrayOpen, .arrayClose, .comma, -42, .comma, true, .comma, false, .comma, .null, .comma, .objectOpen, "integer", .colon, 1234567890, .comma, "real", .colon, .digits("-9876.543210"), .comma, "e", .colon, .digits("0.123456789e-12"), .comma, "E", .colon, .digits("1.234567890E+34"), .comma, "", .colon, .digits("23456789012E66"), .comma, "zero", .colon, 0, .comma, "one", .colon, 1, .comma, "space", .colon, " ", .comma, "quote", .colon, #"\""#, .comma, "backslash", .colon, #"\\"#, .comma, "controls", .colon, #"\b\f\n\r\t"#, .comma, "slash", .colon, #"/ & \/"#, .comma, "alpha", .colon, "abcdefghijklmnopqrstuvwyz", .comma, "ALPHA", .colon, "ABCDEFGHIJKLMNOPQRSTUVWYZ", .comma, "digit", .colon, "0123456789", .comma, "0123456789", .colon, "digit", .comma, "special", .colon, "`1~!@#$%^&*()_+-={':[,]}|;.</>?", .comma, "hex", .colon, #"\u0123\u4567\u89AB\uCDEF\uabcd\uef4A"#, .comma, "true", .colon, true, .comma, "false", .colon, false, .comma, "null", .colon, .null, .comma, "array", .colon, .arrayOpen, .arrayClose, .comma, "object", .colon, .objectOpen, .objectClose, .comma, "address", .colon, "50 St. James Street", .comma, "url", .colon, "http://www.JSON.org/", .comma, "comment", .colon, "// /* <!-- --", .comma, "# -- --> */", .colon, " ", .comma, " s p a c e d ", .colon, .arrayOpen, 1, .comma, 2, .comma, 3, .comma, 4, .comma, 5, .comma, 6, .comma, 7, .arrayClose, .comma, "compact", .colon, .arrayOpen, 1, .comma, 2, .comma, 3, .comma, 4, .comma, 5, .comma, 6, .comma, 7, .arrayClose, .comma, "jsontext", .colon, #"{\"object with 1 member\":[\"array with 1 element\"]}"#, .comma, "quotes", .colon, #"&#34; \u0022 %22 0x22 034 &#x22;"#, .comma, #"\/\\\"\uCAFE\uBABE\uAB98\uFCDE\ubcda\uef4A\b\f\n\r\t`1~!@#$%^&*()_+-=[]{}|;:',./<>?"#, .colon, "A key can be any string", .objectClose, .comma, 0.5, .comma, 98.6, .comma, 99.44, .comma, 1066, .comma, .digits("1e1"), .comma, .digits("0.1e1"), .comma, .digits("1e-1"), .comma, .digits("1e00"), .comma, .digits("2e+00"), .comma, .digits("2e-00"), .comma, "rosebud", .arrayClose]
////
////        XCTAssertEqual(result.count, expected.count)
////        for (lhs, rhs) in zip(result, expected) {
////            XCTAssertEqual(lhs, rhs)
////        }
////    }
////
////    func testDeepJSON() async throws {
////        let url = Bundle.module.url(forResource: "json.org/pass2.json", withExtension: nil)!
////        let json = try Data(contentsOf: url).async
////        let result = try await Array(json.jsonTokens)
////
////        let expected: [JSONToken] =
////        repeatElement(JSONToken.arrayOpen, count: 19) + ["Not too deep"] + repeatElement(JSONToken.arrayClose, count: 19)
////
////        XCTAssertEqual(result.count, expected.count)
////        for (lhs, rhs) in zip(result, expected) {
////            XCTAssertEqual(lhs, rhs)
////        }
////    }
////
////    func testBareString() async throws {
////        let url = Bundle.module.url(forResource: "json.org/fail1.json", withExtension: nil)!
////        let json = try Data(contentsOf: url).async
////        let result = try await Array(json.jsonTokens)
////
////        let expected: [JSONToken] =
////        ["A JSON payload should be an object or array, not a string."]
////
////        XCTAssertEqual(result.count, expected.count)
////        for (lhs, rhs) in zip(result, expected) {
////            XCTAssertEqual(lhs, rhs)
////        }
////    }
////
////    func testUnclosedArray() async throws {
////        let url = Bundle.module.url(forResource: "json.org/fail2.json", withExtension: nil)!
////
////        let json = try Data(contentsOf: url).async
////        let result = try await Array(json.jsonTokens)
////
////        let expected: [JSONToken] =
////        [.arrayOpen, "Unclosed array"]
////
////        XCTAssertEqual(result.count, expected.count)
////        for (lhs, rhs) in zip(result, expected) {
////            XCTAssertEqual(lhs, rhs)
////        }
////    }
////
//    func testUnquotedKey() async throws {
//        let json = Array("""
//        {unquoted_key: "keys must be quoted"}
//        """.utf8)
//
//        var parser = JSONParser(bytes: json)
//
//        await XCTAssertThrowsError(try parser.parse()) {
//            XCTAssertEqual($0 as? JSONParserError, .unexpectedCharacter(ascii: UInt8(ascii: "u"), characterIndex: 1))
//        }
//
//    }
//
// }
