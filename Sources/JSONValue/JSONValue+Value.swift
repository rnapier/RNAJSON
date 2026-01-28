import Foundation

// String
public extension JSONValue {
    func stringValue() throws -> String {
        guard case let .string(value) = self else { throw JSONValueError.typeMismatch }
        return value
    }
}

// Number
public extension JSONValue {
    // Convenience constructor from digits.
    static func digits(_ digits: String) -> Self {
        .number(digits: digits)
    }

    func doubleValue() throws -> Double {
        guard let value = try Double(digits()) else { throw JSONValueError.typeMismatch }
        return value
    }

    func decimalValue() throws -> Decimal {
        guard let value = try Decimal(string: digits()) else { throw JSONValueError.typeMismatch }
        return value
    }

    func intValue() throws -> Int {
        guard let value = try Int(digits()) else { throw JSONValueError.typeMismatch }
        return value
    }

    func digits() throws -> String {
        guard case let .number(digits) = self else { throw JSONValueError.typeMismatch }
        return digits
    }
}

// Bool
public extension JSONValue {
    func boolValue() throws -> Bool {
        guard case let .bool(value) = self else { throw JSONValueError.typeMismatch }
        return value
    }
}

// Object
public extension JSONValue {
    func keyValues() throws -> JSONKeyValues {
        guard case let .object(keyValues) = self else { throw JSONValueError.typeMismatch }
        return keyValues
    }

    // Uniques keys using last value by default. This allows overrides.
    func dictionaryValue(uniquingKeysWith: (JSONValue, JSONValue) -> JSONValue = { _, last in last })
        throws -> [String: JSONValue]
    {
        try Dictionary(keyValues(), uniquingKeysWith: uniquingKeysWith)
    }

    // Returns first value matching key.
    func value(for key: String) throws -> JSONValue {
        guard let result = try keyValues().first(where: { $0.key == key })?.value else {
            throw JSONValueError.missingValue
        }
        return result
    }

    func values(for key: String) throws -> [JSONValue] {
        try keyValues().filter { $0.key == key }.map(\.value)
    }

    subscript(_ key: String) -> JSONValue {
        get throws { try value(for: key) }
    }

    // TODO: Add setters?
}

// Array
public extension JSONValue {
    func arrayValue() throws -> [JSONValue] {
        guard case let .array(array) = self else { throw JSONValueError.typeMismatch }
        return array
    }

    var count: Int {
        get throws {
            switch self {
            case let .array(array): return array.count
            case let .object(object): return object.count
            default: throw JSONValueError.typeMismatch
            }
        }
    }

    func value(at index: Int) throws -> JSONValue {
        let array = try arrayValue()
        guard array.indices.contains(index) else { throw JSONValueError.missingValue }
        return array[index]
    }

    subscript(_ index: Int) -> JSONValue {
        get throws { try value(at: index) }
    }

    // TODO: Add setters?
}

// Null
public extension JSONValue {
    var isNull: Bool { if case .null = self { return true } else { return false } }
}
