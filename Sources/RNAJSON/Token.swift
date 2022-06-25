//
//  File.swift
//  
//
//  Created by Rob Napier on 6/20/22.
//

public enum JSONToken: Hashable {
    case arrayOpen
    case arrayClose
    case objectOpen
    case objectKey([UInt8])
    case objectClose
    case `true`
    case `false`
    case null
    case string([UInt8])
    case number([UInt8])
}

extension JSONToken {
    public static func digits(_ digits: String) -> Self {
        .number(Array(digits.utf8))
    }

    public static func key(_ key: String) -> Self {
        .objectKey(Array(key.utf8))
    }
}

extension JSONToken: ExpressibleByStringLiteral {
    public init(stringLiteral value: StringLiteralType) {
        self = .string(Array(value.utf8))
    }
}

extension JSONToken: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: IntegerLiteralType) {
        self = .number(Array("\(value)".utf8))
    }
}

extension JSONToken: ExpressibleByFloatLiteral {
    public init(floatLiteral value: FloatLiteralType) {
        self = .number(Array("\(value)".utf8))
    }
}

extension JSONToken: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self = .null
    }
}

extension JSONToken: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: BooleanLiteralType) {
        self = value ? .true : .false
    }
}

extension JSONToken: CustomStringConvertible {
    private func describeString(_ data: ([UInt8])) -> String {
        let string = String(decoding: data, as: Unicode.UTF8.self)
        if !string.contains("\u{FFFD}") {
            if string.contains("\\") {
                return """
                        #"\(string)"#
                        """
            } else {
                return """
                        "\(string)"
                        """
            }
        } else {
            let bytes = data.map { "\($0)" }.joined(separator: ", ")
            return """
                    .string(Data([\(bytes)]))
                    """
        }
    }

    public var description: String {
        switch self {
        case .arrayOpen: return ".arrayOpen"
        case .arrayClose: return ".arrayClose"
        case .objectOpen: return ".objectOpen"
        case .objectKey(let data): return ".key(\(describeString(data)))"
        case .objectClose: return ".objectClose"
        case .true: return "true"
        case .false: return "false"
        case .null: return ".null"
        case .string(let data): return describeString(data)

        case .number(let data):
            let digits = String(decoding: data, as: Unicode.UTF8.self)
            return digits.digitsDescription            
        }
    }
}

internal extension String {
    var digitsDescription: String {
        let interpreted = "\(self)"
        if let int = Int(interpreted), "\(int)" == interpreted {
            return interpreted
        }
        if let double = Double(interpreted), "\(double)" == interpreted {
            return interpreted
        }
        return """
                .digits("\(self)")
                """

    }
}
