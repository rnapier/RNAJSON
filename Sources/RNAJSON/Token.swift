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
    case objectKey(String)
    case objectClose
    case `true`
    case `false`
    case null
    case string(String)
    case number(String)
}

extension JSONToken {
    public static func digits(_ digits: String) -> Self {
        .number(digits)
    }

    public static func key(_ key: String) -> Self {
        .objectKey(key)
    }
}

extension JSONToken: ExpressibleByStringLiteral {
    public init(stringLiteral value: StringLiteralType) {
        self = .string(value)
    }
}

extension JSONToken: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: IntegerLiteralType) {
        self = .number("\(value)")
    }
}

extension JSONToken: ExpressibleByFloatLiteral {
    public init(floatLiteral value: FloatLiteralType) {
        self = .number("\(value)")
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
        }
        return string
    }
    private func encodeCharacter(_ c: Character) -> String {
        switch c {
        case "\u{0}" ..< " ":
            switch c {
            case #"""#: return #"\""#
            case #"\"#: return #"\\"#
            case "\u{8}": return #"\b"#
            case "\u{c}": return #"\f"#
            case "\n": return #"\n"#
            case "\r": return #"\r"#
            case "\t": return #"\t"#
            default:
                func valueToAscii(_ value: UInt8) -> UInt8 {
                    switch value {
                    case 0 ... 9:
                        return value + UInt8(ascii: "0")
                    case 10 ... 15:
                        return value - 10 + UInt8(ascii: "a")
                    default:
                        preconditionFailure()
                    }
                }
                let value = c.asciiValue!
                let firstNibble = valueToAscii(value / 16)
                let secondNibble = valueToAscii(value % 16)
                return "\\u00\(firstNibble)\(secondNibble)"
            }
        default:
            return String(c)
        }
    }

    private func encodeString(_ string: String) -> String {
        "\"\(string.lazy.map(encodeCharacter).joined())\""
    }

    public var description: String {
        switch self {
        case .arrayOpen: return ".arrayOpen"
        case .arrayClose: return ".arrayClose"
        case .objectOpen: return ".objectOpen"
        case .objectKey(let string): return ".key(\(string.debugDescription))"
        case .objectClose: return ".objectClose"
        case .true: return "true"
        case .false: return "false"
        case .null: return ".null"
        case .string(let string): return string.debugDescription

        case .number(let digits):
            return digits.digitsDescription
        }
    }
}
