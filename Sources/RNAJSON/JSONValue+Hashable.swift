//
//  File.swift
//  
//
//  Created by Rob Napier on 8/9/22.
//

import Foundation

// Tuples (JSONKeyValues) can't directly conform to Equatable, so do this by hand.
// Note that this is normalized equality. Use `===` for strict equality.
extension JSONValue: Equatable {
    public static func == (lhs: JSONValue, rhs: JSONValue) -> Bool {
        lhs.normalized() === rhs.normalized()
    }

    // Strict equality between JSONValues. Key order must be the same.
    public static func === (lhs: JSONValue, rhs: JSONValue) -> Bool {
        switch (lhs, rhs) {
        case (.string(let lhs), .string(let rhs)): return lhs == rhs
        case (.number(digits: let lhs), .number(digits: let rhs)): return lhs == rhs
        case (.bool(let lhs), .bool(let rhs)): return lhs == rhs
        case (.object(keyValues: let lhs), .object(keyValues: let rhs)):
            return lhs.count == rhs.count && lhs.elementsEqual(rhs, by: { lhs, rhs in
                lhs.key == rhs.key && lhs.value == rhs.value
            })
        case (.array(let lhs), .array(let rhs)): return lhs == rhs
        case (.null, .null): return true
        default: return false
        }
    }
}

// Tuples (JSONKeyValues) can't directly conform to Hashable, so do this by hand.
extension JSONValue: Hashable {
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .string(let string): hasher.combine(string)
        case .number(digits: let digits): hasher.combine(digits)
        case .bool(let value): hasher.combine(value)
        case .object(keyValues: let keyValues):
            for (key, value) in keyValues {
                hasher.combine(key)
                hasher.combine(value)
            }
        case .array(let array): hasher.combine(array)
        case .null: hasher.combine(0)
        }
    }
}
