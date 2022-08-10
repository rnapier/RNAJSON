import Foundation

public enum JSONValue {
    case string(String)
    case number(digits: String)
    case bool(Bool)
    case object(keyValues: JSONKeyValues)
    case array(JSONArray)
    case null
}

public enum JSONValueError: Error {
    // FIXME: Include better information in these error
    case typeMismatch
    case missingValue
}

extension JSONValue {
    public init(_ convertible: LosslessJSONConvertible) { self = convertible.jsonValue() }
    public init(_ convertible: JSONConvertible) throws { self = try convertible.jsonValue() }
}

extension JSONValue {
    // Sorts all nested objects by key and removes duplicate keys (keeping last value).
    public func normalized() -> JSONValue {
        switch self {
        case .object(keyValues: let keyValues):
            return .object(keyValues:
                            Dictionary(keyValues, uniquingKeysWith: { _, last in last })
                .map { (key: $0, value: $1.normalized()) }
                .sorted(by: { $0.key < $1.key }))

        case .array(let values):
            return .array(values.map { $0.normalized() })

        default: return self
        }
    }
}

// ExpressibleBy...Literal
extension JSONValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: StringLiteralType) {
        self = .string(value)
    }
}

extension JSONValue: ExpressibleByUnicodeScalarLiteral {
    public init(unicodeScalarLiteral value: String) {
        self = .string(String(value))
    }
}

extension JSONValue: ExpressibleByExtendedGraphemeClusterLiteral {
    public init(extendedGraphemeClusterLiteral value: String) {
        self = .string(String(value))
    }
}

extension JSONValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: IntegerLiteralType) {
        self = .number(digits: "\(value)")
    }
}

extension JSONValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: FloatLiteralType) {
        self = .number(digits: "\(value)")
    }
}

extension JSONValue: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self = .null
    }
}

extension JSONValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: BooleanLiteralType) {
        self = .bool(value)
    }
}

extension JSONValue: ExpressibleByArrayLiteral {
    public typealias ArrayLiteralElement = JSONValue
    public init(arrayLiteral elements: ArrayLiteralElement...) {
        self = .array(elements)
    }
}

extension JSONValue: ExpressibleByDictionaryLiteral {
    public typealias Key = String
    public typealias Value = JSONValue
    public init(dictionaryLiteral elements: (Key, Value)...) {
        self = .object(keyValues: elements)
    }
}

// String
extension JSONValue {
    public func stringValue() throws -> String {
        guard case let .string(value) = self else { throw JSONValueError.typeMismatch }
        return value
    }
}

// Number
extension JSONValue {
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

    public static func digits(_ digits: String) -> Self {
        .number(digits: digits)
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

public typealias JSONKeyValues = [(key: String, value: JSONValue)]

extension JSONKeyValues {
    public var keys: [String] { self.map(\.key) }

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
    public func dictionaryValue(uniquingKeysWith: (JSONValue, JSONValue) -> JSONValue = { _, last in last }) throws -> [String: JSONValue] {
        return Dictionary(try keyValues(), uniquingKeysWith: uniquingKeysWith)
    }

    // Returns first value matching key.
    public func value(for key: String) throws -> JSONValue {
        guard let result = try keyValues().first(where: { $0.key == key })?.value else {
            throw JSONValueError.missingValue
        }
        return result
    }

    public func values(for key: String) throws -> [JSONValue] {
        return try keyValues().filter({ $0.key == key }).map(\.value)
    }

    public subscript(_ key: String) -> JSONValue {
        get throws { try value(for: key) }
    }

    // TODO: Add setters?
}

// Array

public typealias JSONArray = [JSONValue]

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
    public var isNull: Bool { self == .null }
}

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

// JSONConvertible

public protocol JSONConvertible {
    func jsonValue() throws -> JSONValue
}

public protocol LosslessJSONConvertible: JSONConvertible {
    func jsonValue() -> JSONValue
}

extension String: LosslessJSONConvertible {
    public func jsonValue() -> JSONValue { .string(self) }
}

extension BinaryInteger {
    public func jsonValue() -> JSONValue { .number(digits: "\(self)") }
}

extension Int: LosslessJSONConvertible {}
extension Int8: LosslessJSONConvertible {}
extension Int16: LosslessJSONConvertible {}
extension Int32: LosslessJSONConvertible {}
extension Int64: LosslessJSONConvertible {}
extension UInt: LosslessJSONConvertible {}
extension UInt8: LosslessJSONConvertible {}
extension UInt16: LosslessJSONConvertible {}
extension UInt32: LosslessJSONConvertible {}
extension UInt64: LosslessJSONConvertible {}

extension BinaryFloatingPoint {
    public func jsonValue() -> JSONValue { .number(digits: "\(self)") }
}

extension Float: LosslessJSONConvertible {}
extension Double: LosslessJSONConvertible {}

extension Decimal: LosslessJSONConvertible {
    public func jsonValue() -> JSONValue {
        var decimal = self
        return .number(digits: NSDecimalString(&decimal, nil))
    }
}

extension JSONValue: LosslessJSONConvertible {
    public func jsonValue() -> JSONValue { self }
}

extension Bool: LosslessJSONConvertible {
    public func jsonValue() -> JSONValue { .bool(self) }
}

extension Sequence where Element: LosslessJSONConvertible {
    public func jsonValue() -> JSONValue { .array(self.map { $0.jsonValue() }) }
}

extension Sequence where Element: JSONConvertible {
    public func jsonValue() throws -> JSONValue { .array(try self.map { try $0.jsonValue() }) }
}

extension NSArray: JSONConvertible {
    public func jsonValue() throws -> JSONValue {
        .array(try self.map {
            guard let value = $0 as? JSONConvertible else { throw JSONValueError.typeMismatch }
            return try value.jsonValue()
        })
    }
}

extension NSDictionary: JSONConvertible {
    public func jsonValue() throws -> JSONValue {
        guard let dict = self as? [String: JSONConvertible] else { throw JSONValueError.typeMismatch }
        return try dict.jsonValue()
    }
}

extension Array: LosslessJSONConvertible where Element: LosslessJSONConvertible {}
extension Array: JSONConvertible where Element: JSONConvertible {}

public extension Sequence where Element == (key: String, value: LosslessJSONConvertible) {
    func jsonValue() -> JSONValue {
        return .object(keyValues: self.map { ($0.key, $0.value.jsonValue()) } )
    }
}

public extension Sequence where Element == (key: String, value: JSONConvertible) {
    func jsonValue() throws -> JSONValue {
        return .object(keyValues: try self.map { ($0.key, try $0.value.jsonValue()) } )
    }
}

public extension Dictionary where Key == String, Value: LosslessJSONConvertible {
    func jsonValue() -> JSONValue {
        return .object(keyValues: self.map { ($0.key, $0.value.jsonValue()) } )
    }
}

public extension Dictionary where Key == String, Value: JSONConvertible {
    func jsonValue() throws -> JSONValue {
        return .object(keyValues: try self.map { ($0.key, try $0.value.jsonValue()) } )
    }
}

extension JSONValue: CustomStringConvertible {
    public var description: String {
        switch self {
        case .null: return ".null"
        case .string(let string): return string.debugDescription
        case .number(let digits): return digits.digitsDescription
        case .bool(let value): return value ? "true" : "false"
        case .object(keyValues: let keyValues):
            if keyValues.isEmpty {
                return "[:]"
            } else {
                return "[" + keyValues.map { "\($0.key.debugDescription): \($0.value)" }.joined(separator: ", ") + "]"
            }
        case .array(let values):
            return "[" + values.map(\.description).joined(separator: ", ") + "]"
        }
    }
}
