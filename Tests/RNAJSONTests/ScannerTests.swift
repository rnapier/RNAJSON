//
//  ScannerTests.swift
//  
//
//  Created by Rob Napier on 7/24/22.
//

import XCTest
import RNAJSON

final class ScannerTests: XCTestCase {

    func testArrayOfObjects() async throws {
        let json = Array(#"""



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


        """#.utf8)

        let expected = Array(#"""
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
        """#.utf8)

        var scanner = JSONScanner(bytes: json)
        let result = Array(try scanner.dataForBody())
        XCTAssertEqual(result, expected)
    }

}
