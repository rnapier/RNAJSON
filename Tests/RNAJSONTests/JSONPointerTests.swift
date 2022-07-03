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
        let json1 = try JSONDecoder().decode(JSONValue.self, from: Data(aerodactyl))

        let tokens = AsyncJSONTokenSequence(aerodactyl.async)

        let json2 = try await JSONValue(from: tokens)

        XCTAssertEqual(json1, json2)
    }


}
