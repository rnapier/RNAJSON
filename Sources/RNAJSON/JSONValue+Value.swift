//
//  File.swift
//  
//
//  Created by Rob Napier on 8/10/22.
//

import Foundation

// String
extension JSONValue {
    public func stringValue() throws -> String {
        guard case let .string(value) = self else { throw JSONValueError.typeMismatch }
        return value
    }
}

// Number
extension JSONValue {
    // Convenience constructor from digits.
    public static func digits(_ digits: String) -> Self {
        .number(digits: digits)
    }

    public func doubleValue() throws -> Double {
        guard let value = Double(try digits()) else { throw JSONValueError.typeMismatch }
        return value
    }

    public func decimalValue() throws -> Decimal {
        guard let value = Decimal(string: try digits()) else { throw JSONValueError.typeMismatch }
        return value
    }

    public func intValue() throws -> Int {
        guard let value = Int(try digits()) else { throw JSONValueError.typeMismatch }
        return value
    }

    public func digits() throws -> String {
        guard case let .number(digits) = self else { throw JSONValueError.typeMismatch }
        return digits
    }
}

// Bool
extension JSONValue {
    public func boolValue() throws -> Bool {
        guard case let .bool(value) = self else { throw JSONValueError.typeMismatch }
        return value
    }
}

// Object
extension JSONKeyValues {
    public var keys: [String] { self.map(\.key) }
    public var values: [JSONValue] { self.map(\.value) }

    // Treats KeyValues like a Dictionary. Operates only on first occurrence of key.
    // Using first occurrence is faster here. Compare, however, to `dictionaryValue()`
    // which uses last value by default.
    public subscript(_ key: String) -> JSONValue? {
        get { self.first(where: { $0.key == key })?.value }
        set {
            if let value = newValue {
                if let index = self.firstIndex(where: { $0.key == key}) {
                    self[index] = (key: key, value: value)
                } else {
                    self.append((key: key, value: value))
                }
            } else {
                if let index = self.firstIndex(where: { $0.key == key }) {
                    self.remove(at: index)
                }
            }
        }
    }
}

extension JSONValue {
    public func keyValues() throws -> JSONKeyValues {
        guard case let .object(keyValues) = self else { throw JSONValueError.typeMismatch }
        return keyValues
    }

    // Uniques keys using last value by default. This allows overrides.
    public func dictionaryValue(uniquingKeysWith: (JSONValue, JSONValue) -> JSONValue = { _, last in last })
    throws -> [String: JSONValue] {
        Dictionary(try keyValues(), uniquingKeysWith: uniquingKeysWith)
    }

    // Returns first value matching key.
    public func value(for key: String) throws -> JSONValue {
        guard let result = try keyValues().first(where: { $0.key == key })?.value else {
            throw JSONValueError.missingValue
        }
        return result
    }

    public func values(for key: String) throws -> [JSONValue] {
        try keyValues().filter({ $0.key == key }).map(\.value)
    }

    public subscript(_ key: String) -> JSONValue {
        get throws { try value(for: key) }
    }

    // TODO: Add setters?
}

// Array
extension JSONValue {
    public func arrayValue() throws -> [JSONValue] {
        guard case let .array(array) = self else { throw JSONValueError.typeMismatch }
        return array
    }

    public var count: Int {
        get throws {
            switch self {
            case let .array(array): return array.count
            case let .object(object): return object.count
            default: throw JSONValueError.typeMismatch
            }
        }
    }

    public func value(at index: Int) throws -> JSONValue {
        let array = try arrayValue()
        guard array.indices.contains(index) else { throw JSONValueError.missingValue }
        return array[index]
    }

    public subscript(_ index: Int) -> JSONValue {
        get throws { try value(at: index) }
    }

    // TODO: Add setters?
}

// Null
extension JSONValue {
    public var isNull: Bool { if case .null = self { return true } else { return false } }
}
