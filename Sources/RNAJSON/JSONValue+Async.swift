//
//  File.swift
//  
//
//  Created by Rob Napier on 8/9/22.
//

import Foundation

extension JSONValue {
    public init<S: AsyncSequence>(from tokens: S) async throws
    where S.Element == JSONToken {
        var tokenIterator = tokens.makeAsyncIterator()

        guard let value = try await JSONValue(iterator: &tokenIterator) else { throw JSONValueError.missingValue }
        guard try await tokenIterator.next() == nil else { throw JSONValueError.typeMismatch } // FIXME: Fix error

        self = value
    }

    private init?<I: AsyncIteratorProtocol>(iterator: inout I) async throws
    where I.Element == JSONToken {

        guard let token = try await iterator.next() else { return nil }
        switch token {

        case .arrayOpen:
            var values: JSONArray = []
            while let value = try await JSONValue(iterator: &iterator) {
                values.append(value)
            }
            self = .array(values)

        case .arrayClose:
            return nil

        case .objectOpen:
            var keyValues: JSONKeyValues = []

            while case let .objectKey(key) = try await iterator.next(),
                  let value = try await JSONValue(iterator: &iterator)
            {
                keyValues.append((key: key, value: value))
            }
            self = .object(keyValues: keyValues)

        case .objectKey(_):
            fatalError()
        case .objectClose:
            return nil
        case .true:
            self = .bool(true)
        case .false:
            self = .bool(false)
        case .null:
            self = .null
        case .string(let string):
            self = .string(string)
        case .number(let digits):
            self = .number(digits: digits)
        }
    }

    public init(decoding sequence: some Sequence<UInt8>, strict: Bool = false) async throws {
        try await self.init(from: AsyncJSONTokenSequence(sequence))
    }
}
