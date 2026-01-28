//
//  JSONValue+KeyValues.swift
//
//
//  Created by Rob Napier on 8/10/22.
//

public extension JSONKeyValues {
    var keys: [String] { map(\.key) }
    var values: [JSONValue] { map(\.value) }

    // Treats KeyValues like a Dictionary. Operates only on first occurrence of key.
    // Using first occurrence is faster here. Compare, however, to `dictionaryValue()`
    // which uses last value by default.
    subscript(_ key: String) -> JSONValue? {
        get { first(where: { $0.key == key })?.value }
        set {
            if let value = newValue {
                if let index = firstIndex(where: { $0.key == key }) {
                    self[index] = (key: key, value: value)
                } else {
                    append((key: key, value: value))
                }
            } else {
                if let index = firstIndex(where: { $0.key == key }) {
                    remove(at: index)
                }
            }
        }
    }
}
