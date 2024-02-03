//
//  JSONCompactorTests.swift
//  
//
//  Created by Rob Napier on 2/3/24.
//

import XCTest
import RNAJSON

final class JSONCompactorTests: XCTestCase {

    func testLeadingAndTrailingWhitespaceIsSkipped() async throws {
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

        let expected = #"{"id":142,"name":"aerodactyl","types":[{"type":{"name":"rock","url":"https://pokeapi.co/api/v2/type/6/"},"slot":1},{"type":{"name":"flying","url":"https://pokeapi.co/api/v2/type/3/"},"slot":2}]}"#

        let compactor = JSONCompactor()
        let result = String(decoding: try compactor.compact(from: json), as: UTF8.self)
        XCTAssertEqual(result, expected)
    }

    func testComplexJSONIsLeftAlone() throws {
        let json = Array(#"""
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
        """#.utf8)

        let expected = ###"["JSON Test Pattern pass1",{"object with 1 member":["array with 1 element"]},{},[],-42,true,false,null,{"integer":1234567890,"real":-9876.543210,"e":0.123456789e-12,"E":1.234567890E+34,"":23456789012E66,"zero":0,"one":1,"space":" ","quote":"\"","backslash":"\\","controls":"\b\f\n\r\t","slash":"/ & \/","alpha":"abcdefghijklmnopqrstuvwyz","ALPHA":"ABCDEFGHIJKLMNOPQRSTUVWYZ","digit":"0123456789","0123456789":"digit","special":"`1~!@#$%^&*()_+-={':[,]}|;.</>?","hex":"\u0123\u4567\u89AB\uCDEF\uabcd\uef4A","true":true,"false":false,"null":null,"array":[],"object":{},"address":"50 St. James Street","url":"http://www.JSON.org/","comment":"// /* <!-- --","# -- --> */":" "," s p a c e d ":[1,2,3,4,5,6,7],"compact":[1,2,3,4,5,6,7],"jsontext":"{\"object with 1 member\":[\"array with 1 element\"]}","quotes":"&#34; \u0022 %22 0x22 034 &#x22;","\/\\\"\uCAFE\uBABE\uAB98\uFCDE\ubcda\uef4A\b\f\n\r\t`1~!@#$%^&*()_+-=[]{}|;:',./<>?":"A key can be any string"},0.5,98.6,99.44,1066,1e1,0.1e1,1e-1,1e00,2e+00,2e-00,"rosebud"]"###
        let compactor = JSONCompactor()
        let result = String(decoding: try compactor.compact(from: json), as: UTF8.self)
        XCTAssertEqual(result, expected)
    }

    func testArraySubscript() async throws {
        let json = Array(#"""
        [1, 2, 3]
        """#.utf8)

        let expected = ###"[1,2,3]"###

        let compactor = JSONCompactor()
        let result = String(decoding: try compactor.compact(from: json), as: UTF8.self)
        XCTAssertEqual(result, expected)
    }

    func testTrailingCommaArray() async throws {
        let json = Array(#"""
        [1, 2, 3, ]
        """#.utf8)

        let expected = ###"[1,2,3]"###

        let compactor = JSONCompactor()
        let result = String(decoding: try compactor.compact(from: json), as: UTF8.self)
        XCTAssertEqual(result, expected)
    }

    func testTrailingCommaObject() async throws {
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
            ],
        }


        """#.utf8)

        let expected = #"{"id":142,"name":"aerodactyl","types":[{"type":{"name":"rock","url":"https://pokeapi.co/api/v2/type/6/"},"slot":1},{"type":{"name":"flying","url":"https://pokeapi.co/api/v2/type/3/"},"slot":2}]}"#

        let compactor = JSONCompactor()
        let result = String(decoding: try compactor.compact(from: json), as: UTF8.self)
        XCTAssertEqual(result, expected)
    }

    func testEmptyArray() async throws {
        let json = Array(#"""
        [ ]
        """#.utf8)

        let expected = ###"[]"###

        let compactor = JSONCompactor()
        let result = String(decoding: try compactor.compact(from: json), as: UTF8.self)
        XCTAssertEqual(result, expected)
    }

    func testEmptyObject() async throws {
        let json = Array(#"""
        { }
        """#.utf8)

        let expected = ###"{}"###

        let compactor = JSONCompactor()
        let result = String(decoding: try compactor.compact(from: json), as: UTF8.self)
        XCTAssertEqual(result, expected)
    }

}
