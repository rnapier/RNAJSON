import Foundation

extension JSONValue: Decodable {
    public init(from decoder: Decoder) throws {
        let matchers = [decodeNil, decodeString, decodeNumber, decodeBool, decodeObject, decodeArray]

        for matcher in matchers {
            do {
                self = try matcher(decoder)
                return
            } catch DecodingError.typeMismatch { continue }
        }

        throw DecodingError.typeMismatch(JSONValue.self,
                                         .init(codingPath: decoder.codingPath,
                                               debugDescription: "Unknown JSON type"))
    }
}

extension JSONValue: Encodable {
    public func encode(to encoder: Encoder) throws {
        switch self {
        case let .string(string):
            var container = encoder.singleValueContainer()
            try container.encode(string)

        case .number:
            var container = encoder.singleValueContainer()
            try container.encode(decimalValue())

        case let .bool(value):
            var container = encoder.singleValueContainer()
            try container.encode(value)

        case let .object(keyValues: keyValues):
            var container = encoder.container(keyedBy: StringKey.self)
            for (key, value) in keyValues {
                try container.encode(value, forKey: StringKey(key))
            }

        case let .array(values):
            var container = encoder.unkeyedContainer()
            for value in values {
                try container.encode(value)
            }

        case .null:
            var container = encoder.singleValueContainer()
            try container.encodeNil()
        }
    }
}

private func decodeString(decoder: Decoder) throws -> JSONValue {
    try .string(decoder.singleValueContainer().decode(String.self))
}

private func decodeNumber(decoder: Decoder) throws -> JSONValue {
    try .number(digits: decoder.singleValueContainer().decode(Decimal.self).description)
}

private func decodeBool(decoder: Decoder) throws -> JSONValue {
    try .bool(decoder.singleValueContainer().decode(Bool.self))
}

private func decodeObject(decoder: Decoder) throws -> JSONValue {
    let object = try decoder.container(keyedBy: StringKey.self)
    let pairs = try object.allKeys.map(\.stringValue).map { key in
        try (key, object.decode(JSONValue.self, forKey: StringKey(key)))
    }
    return .object(keyValues: pairs)
}

private func decodeArray(decoder: Decoder) throws -> JSONValue {
    var array = try decoder.unkeyedContainer()
    var result: [JSONValue] = []
    if let count = array.count { result.reserveCapacity(count) }
    while !array.isAtEnd {
        try result.append(array.decode(JSONValue.self))
    }
    return .array(result)
}

private func decodeNil(decoder: Decoder) throws -> JSONValue {
    if try decoder.singleValueContainer().decodeNil() { return .null }
    else { throw DecodingError.typeMismatch(JSONValue.self,
                                            .init(codingPath: decoder.codingPath,
                                                  debugDescription: "Did not find nil")) }
}

// MARK: - StringKey

private struct StringKey: CodingKey, Hashable, CustomStringConvertible {
    var description: String { stringValue }

    let stringValue: String
    init(_ string: String) { stringValue = string }
    init?(stringValue: String) { self.init(stringValue) }
    var intValue: Int? { nil }
    init?(intValue _: Int) { nil }
}
