// Returns value or null
@dynamicMemberLookup
public struct DynamicJSONValue {
    public var _jsonValue: JSONValue
    public init(_ jsonValue: JSONValue) {
        _jsonValue = jsonValue
    }

    public subscript(dynamicMember key: String) -> Self {
        self[key]
    }

    public subscript(_ key: String) -> Self {
        Self((try? _jsonValue[key]) ?? .null)
    }

    public subscript(_ index: Int) -> Self {
        Self((try? _jsonValue[index]) ?? .null)
    }
}

extension DynamicJSONValue: CustomStringConvertible {
    public var description: String { _jsonValue.description }
}

extension JSONValue {
    public var dynamic: DynamicJSONValue { DynamicJSONValue(self) }
}
