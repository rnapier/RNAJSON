//
//  File.swift
//  
//
//  Created by Rob Napier on 6/20/22.
//

import Foundation

public enum JSONToken: Hashable {
    case arrayOpen
    case arrayClose
    case objectOpen
    case objectClose
    case colon
    case comma
    case `true`
    case `false`
    case null
    case string(Data)
    case number(Data)
}

extension JSONToken {
    public static func digits(_ digits: String) -> Self {
        .number(Data(digits.utf8))
    }
}

extension JSONToken: ExpressibleByStringLiteral {
    public init(stringLiteral value: StringLiteralType) {
        self = .string(Data(value.utf8))
    }
}

extension JSONToken: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: IntegerLiteralType) {
        self = .number(Data("\(value)".utf8))
    }
}

extension JSONToken: ExpressibleByFloatLiteral {
    public init(floatLiteral value: FloatLiteralType) {
        self = .number(Data("\(value)".utf8))
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
    public var description: String {
        switch self {
        case .arrayOpen: return ".arrayOpen"
        case .arrayClose: return ".arrayClose"
        case .objectOpen: return ".objectOpen"
        case .objectClose: return ".objectClose"
        case .colon: return ".colon"
        case .comma: return ".comma"
        case .true: return "true"
        case .false: return "false"
        case .null: return ".null"
        case .string(let data):
            if let string = String(data: data, encoding: .utf8) {
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

        case .number(let data):
            if let digits = String(data: data, encoding: .utf8) {
                return digits.digitsDescription
            } else {
                let bytes = data.map { "\($0)" }.joined(separator: ", ")
                return """
                    .number(Data([\(bytes)]))
                    """
            }
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
