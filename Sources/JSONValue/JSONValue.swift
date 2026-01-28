public enum JSONValue {
    case string(String)
    case number(digits: String)
    case bool(Bool)
    case object(keyValues: JSONKeyValues)
    case array(JSONArray)
    case null
}

public typealias JSONKeyValues = [(key: String, value: JSONValue)]
public typealias JSONArray = [JSONValue]

public enum JSONValueError: Error {
    // FIXME: Include better information in these error
    case typeMismatch
    case missingValue
}

extension JSONValue: CustomStringConvertible {
    public var description: String {
        switch self {
        case .null: return ".null"
        case let .string(string): return string.debugDescription
        case let .number(digits): return digits.digitsDescription
        case let .bool(value): return value ? "true" : "false"
        case let .object(keyValues: keyValues):
            if keyValues.isEmpty {
                return "[:]"
            } else {
                return "[" + keyValues.map { "\($0.key.debugDescription): \($0.value)" }.joined(separator: ", ") + "]"
            }
        case let .array(values):
            return "[" + values.map(\.description).joined(separator: ", ") + "]"
        }
    }
}

extension String {
    var digitsDescription: String {
        let interpreted = "\(self)"
        if let int = Int(interpreted), interpreted == "\(int)" {
            return interpreted
        }
        if let double = Double(interpreted), interpreted == "\(double)" {
            return interpreted
        }
        return """
        .digits("\(self)")
        """
    }
}
