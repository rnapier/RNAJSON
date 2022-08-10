//
//  JSONPointerTests.swift
//  
//
//  Created by Rob Napier on 6/26/22.
//

import XCTest
import RNAJSON

final class JSONPointerTests: XCTestCase {

    let aerodactyl = Array("""
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
""".utf8)

    func testJSONParse() async throws {

        let tokens = AsyncJSONTokenSequence(aerodactyl)
        let result = try await JSONValue(from: tokens)

        let expected = try JSONDecoder().decode(JSONValue.self, from: Data(aerodactyl))

        XCTAssertEqual(result, expected)
    }    
}

//private extension XCTest {
//    // Does not check key order
//    func XCTAssertDeepEquivalent(_ lhs: JSONValue, _ rhs: JSONValue) throws {
//        switch (lhs, rhs) {
//        case (.array(let lhs), .array(let rhs)):
//            XCTAssertEqual(lhs.count, rhs.count)
//            for (l, r) in zip(lhs, rhs) {
//                try XCTAssertDeepEquivalent(l, r)
//            }
//
//        case (.object(let lhs), .object(let rhs)):
//            XCTAssertEqual(lhs.count, rhs.count)
//            for key in lhs.keys {
//                try XCTAssertDeepEquivalent(XCTUnwrap(lhs[key]), XCTUnwrap(rhs[key]))
//            }
//
//        default:
//            XCTAssertEqual(lhs, rhs)
//        }
//    }
//}
