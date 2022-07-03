import Foundation

@dynamicMemberLookup
public enum JSONValue {
    case string(String)
    case number(digits: String)
    case bool(Bool)
    case object(keyValues: JSONKeyValues)
    case array(JSONArray)
    case null

    public init(_ convertible: LosslessJSONConvertible) { self = convertible.jsonValue() }
    public init(_ convertible: JSONConvertible) throws { self = try convertible.jsonValue() }
}

//extension JSONValue {
//    public var isValue: Bool {
//        switch self {
//        case .array, .object:
//            return false
//        case .null, .number, .string, .bool:
//            return true
//        }
//    }
//
//    public var isContainer: Bool {
//        switch self {
//        case .array, .object:
//            return true
//        case .null, .number, .string, .bool:
//            return false
//        }
//    }
//}

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
        guard case let .string(value) = self else { throw JSONError.typeMismatch }
        return value
    }
}

// Number
extension JSONValue {
    public func doubleValue() throws -> Double {
        guard case let .number(digits) = self, let value = Double(digits) else { throw JSONError.typeMismatch }
        return value
    }

    public func decimalValue() throws -> Decimal {
        guard case let .number(digits) = self, let value = Decimal(string: digits) else { throw JSONError.typeMismatch }
        return value
    }

    public func intValue() throws -> Int {
        guard case let .number(digits) = self, let value = Int(digits) else { throw JSONError.typeMismatch }
        return value
    }

    public func digits() throws -> String {
        guard case let .number(digits) = self else { throw JSONError.typeMismatch }
        return digits
    }

    public static func digits(_ digits: String) -> Self {
        .number(digits: digits)
    }
}

// Bool
extension JSONValue {
    public func boolValue() throws -> Bool {
        guard case let .bool(value) = self else { throw JSONError.typeMismatch }
        return value
    }
}

// Object

public typealias JSONKeyValues = [(key: String, value: JSONValue)]

extension JSONKeyValues {
    public var keys: [String] { self.map(\.key) }

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
        guard case let .object(object) = self else { throw JSONError.typeMismatch }
        return object
    }

    // Uniques keys using last value
    public func dictionaryValue() throws -> [String: JSONValue] {
        guard case let .object(object) = self else { throw JSONError.typeMismatch }
        return Dictionary(object, uniquingKeysWith: { _, last in last })
    }

    public func value(for key: String) throws -> JSONValue {
        guard let value = self[key] else { throw JSONError.missingValue }
        return value
    }

    public func values(for key: String) throws -> [JSONValue] {
        guard case let .object(object) = self else { throw JSONError.typeMismatch }
        return object.filter({ $0.key == key }).map(\.value)
    }

    public subscript(_ key: String) -> JSONValue? {
        guard case let .object(object) = self else { return nil }
        return object.first(where: { $0.key == key })?.value
    }

    public subscript(dynamicMember key: String) -> JSONValue {
        self[key] ?? .null
    }
}

// Array

public typealias JSONArray = [JSONValue]

extension JSONValue {
    public func arrayValue() throws -> [JSONValue] {
        guard case let .array(array) = self else { throw JSONError.typeMismatch }
        return array
    }

    public var count: Int {
        get throws {
            switch self {
            case let .array(array): return array.count
            case let .object(object): return object.count
            default: throw JSONError.typeMismatch
            }
        }
    }

    public func value(at index: Int) throws -> JSONValue {
        guard case let .array(array) = self else { throw JSONError.typeMismatch }
        guard array.indices.contains(index) else { throw JSONError.missingValue }
        return array[index]
    }

    public subscript(_ index: Int) -> JSONValue {
        (try? value(at: index)) ?? .null
    }
}

// Null
extension JSONValue {
    public var isNull: Bool {
        guard case .null = self else { return false }
        return true
    }
}

// Tuples (JSONKeyValues) can't directly conform to Equatable, so do this by hand
// Note that this is strict equality. Key order and duplication must be identical for objects.
// Use `.normalized()` to sort keys and remove duplicates for "equivalent" comparison.
extension JSONValue: Equatable {
    public static func == (lhs: JSONValue, rhs: JSONValue) -> Bool {
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
            guard let value = $0 as? JSONConvertible else { throw JSONError.typeMismatch }
            return try value.jsonValue()
        })
    }
}

extension NSDictionary: JSONConvertible {
    public func jsonValue() throws -> JSONValue {
        guard let dict = self as? [String: JSONConvertible] else { throw JSONError.typeMismatch }
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

extension JSONValue: Decodable {
    public init(from decoder: Decoder) throws {
        if let string = try? decoder.singleValueContainer().decode(String.self) { self = .string(string) }

        else if let number = try? decoder.singleValueContainer().decode(Decimal.self) { self = .number(digits: "\(number)") }

        else if let bool = try? decoder.singleValueContainer().decode(Bool.self) { self = .bool(bool) }

        else if let object = try? decoder.container(keyedBy: StringKey.self) {
            let pairs = try object.allKeys.map(\.stringValue).map { key in
                (key, try object.decode(JSONValue.self, forKey: StringKey(key)))
            }
            self = .object(keyValues: pairs)
        }

        else if var array = try? decoder.unkeyedContainer() {
            var result: [JSONValue] = []
            while !array.isAtEnd {
                result.append(try array.decode(JSONValue.self))
            }
            self = .array(result)
        }

        else if let isNull = try? decoder.singleValueContainer().decodeNil(), isNull { self = .null }

        else { throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [],
                                                                       debugDescription: "Unknown JSON type")) }
    }
}

extension JSONValue {
    public init<S: AsyncSequence>(from tokens: S) async throws
    where S.Element == JSONToken {
        var tokenIterator = tokens.makeAsyncIterator()

        guard let value = try await JSONValue(iterator: &tokenIterator) else { throw JSONError.missingValue }
        guard try await tokenIterator.next() == nil else { throw JSONError.typeMismatch } // FIXME: Fix error

        self = value
    }

    private init?<I: AsyncIteratorProtocol>(iterator: inout I) async throws
    where I.Element == JSONToken {

        guard let token = try await iterator.next() else { return nil }
        print("Read \(token)")
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
}

// MARK: - StringKey
private struct StringKey: CodingKey, Hashable, Comparable, CustomStringConvertible, ExpressibleByStringLiteral {
    public var description: String { stringValue }

    public let stringValue: String
    public init(_ string: String) { self.stringValue = string }
    public init?(stringValue: String) { self.init(stringValue) }
    public var intValue: Int? { nil }
    public init?(intValue: Int) { nil }

    public static func < (lhs: StringKey, rhs: StringKey) -> Bool { lhs.stringValue < rhs.stringValue }

    public init(stringLiteral value: String) { self.init(value) }
}
