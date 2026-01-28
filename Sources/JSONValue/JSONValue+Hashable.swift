//
//  JSONValue+Hashable.swift
//
//
//  Created by Rob Napier on 8/9/22.
//

// Tuples (JSONKeyValues) can't directly conform to Equatable, so do this by hand.
// Note that this is normalized equality. Use `===` for strict equality.
extension JSONValue: Equatable {
    public static func == (lhs: JSONValue, rhs: JSONValue) -> Bool {
        lhs.normalized() === rhs.normalized()
    }

    // Strict equality between JSONValues. Key order must be the same.
    public static func === (lhs: JSONValue, rhs: JSONValue) -> Bool {
        switch (lhs, rhs) {
        case let (.string(lhs), .string(rhs)): return lhs == rhs
        case let (.number(digits: lhs), .number(digits: rhs)): return lhs == rhs
        case let (.bool(lhs), .bool(rhs)): return lhs == rhs
        case let (.object(keyValues: lhs), .object(keyValues: rhs)):
            return lhs.count == rhs.count && lhs.elementsEqual(rhs, by: { lhs, rhs in
                lhs.key == rhs.key && lhs.value == rhs.value
            })
        case let (.array(lhs), .array(rhs)): return lhs == rhs
        case (.null, .null): return true
        default: return false
        }
    }
}

// Tuples (JSONKeyValues) can't directly conform to Hashable, so do this by hand.
extension JSONValue: Hashable {
    public func hash(into hasher: inout Hasher) {
        switch self {
        case let .string(string): hasher.combine(string)
        case let .number(digits: digits): hasher.combine(digits)
        case let .bool(value): hasher.combine(value)
        case let .object(keyValues: keyValues):
            for (key, value) in keyValues {
                hasher.combine(key)
                hasher.combine(value)
            }
        case let .array(array): hasher.combine(array)
        case .null: hasher.combine(0)
        }
    }
}

public extension JSONValue {
    // Sorts all nested objects by key and removes duplicate keys (keeping last value).
    func normalized() -> JSONValue {
        switch self {
        case let .object(keyValues: keyValues):
            return .object(keyValues:
                Dictionary(keyValues, uniquingKeysWith: { _, last in last })
                    .map { (key: $0, value: $1.normalized()) }
                    .sorted(by: { $0.key < $1.key }))

        case let .array(values):
            return .array(values.map { $0.normalized() })

        default: return self
        }
    }
}
