//
//  File.swift
//  
//
//  Created by Rob Napier on 8/9/22.
//

import Foundation

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
        DynamicJSONValue((try? _jsonValue[key]) ?? .null)
    }

    public subscript(_ index: Int) -> Self {
        DynamicJSONValue((try? _jsonValue[index]) ?? .null)
    }
}

extension DynamicJSONValue: CustomStringConvertible {
    public var description: String { _jsonValue.description }
}

extension JSONValue {
    public var dynamic: DynamicJSONValue { DynamicJSONValue(self) }
}
