//
//  File.swift
//  
//
//  Created by Rob Napier on 4/6/21.
//

import XCTest
import RNAJSON


final class JSONValueTests: XCTestCase {
    func testSingleDigit() async throws {
        let json = Data("""
        1
        """.utf8).async
        let result = try await JSONValue(from: json.jsonTokens)
        XCTAssertEqual(result, 1)
    }

    func testInteger() async throws {
        let json = Data("""
        10
        """.utf8).async
        let result = try await JSONValue(from: json.jsonTokens)
        XCTAssertEqual(result, 10)
    }


}
