//
//  File.swift
//  
//
//  Created by Rob Napier on 8/10/22.
//

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
