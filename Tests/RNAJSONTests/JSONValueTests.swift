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
        """.utf8)
        let result = try await JSONValue(decoding: json)
        XCTAssertEqual(result, 1)
    }

    func testInteger() async throws {
        let json = Data("""
        10
        """.utf8)
        let result = try await JSONValue(decoding: json)
        XCTAssertEqual(result, 10)
    }
}
