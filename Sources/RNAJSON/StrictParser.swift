////
////  File.swift
////
////
////  Created by Rob Napier on 6/20/22.
////
//
//import Foundation
//
//public enum JSONParserError: Swift.Error, Hashable {
//    case dataCorrupted // FIXME: Better errors
//}
//
//internal struct ByteIterator: IteratorProtocol {
//    typealias Element = UInt8
//    var source: any IteratorProtocol<Element>
//    var peek: Element?
//    init(_ underlyingIterator: some IteratorProtocol<Element>) { source = underlyingIterator }
//
//    mutating func next() -> Element? {
//        defer { peek = nil }
//        if let peek { return peek }
//        return source.next()
//    }
//
//    mutating func nextAfterWhitespace() -> UInt8? {
//        repeat {
//            guard let nextByte = next() else { return nil }
//            if !whitespaceBytes.contains(nextByte) {
//                return nextByte
//            }
//        } while true
//    }
//}
//
//public struct StrictJSONParser {
//
//    public func parse(_ input: some Sequence<UInt8>) throws -> JSON {
//        var bytes = ByteIterator(input.makeIterator())
//
//        guard let first = bytes.nextAfterWhitespace() else {
//            throw JSONParserError.dataCorrupted
//        }
//
//        switch first {
//        case UInt8(ascii: "{"): return try parseOpenedObject(from: &bytes)
//        case UInt8(ascii: "["): return try parseOpenedArray(from: &bytes)
//        default: throw JSONParserError.dataCorrupted
//        }
//    }
//
//    private func parseJSON(from bytes: inout ByteIterator) throws -> JSON {
//
//    }
//
//    private func parseOpenedObject(from bytes: inout ByteIterator) throws -> JSON {
//        guard let first = bytes.nextAfterWhitespace() else {
//            throw JSONParserError.dataCorrupted
//        }
//
//        if first == UInt8(ascii: "}") { return .object(keyValues: []) }
//
//        guard first == UInt8(ascii: "\"") else { throw JSONParserError.dataCorrupted }
//        bytes.peek = first
//
//        var keyValues: [(String, JSON)] = []
//
//        repeat {
//            keyValues.append(try parseKeyValue(from: &bytes))
//
//            let terminator = bytes.nextAfterWhitespace()
//            switch terminator {
//            case UInt8(ascii: "}"): break
//            case UInt8(ascii: ","): continue
//            default: throw JSONParserError.dataCorrupted
//            }
//        } while true
//
//        return .object(keyValues: keyValues)
//    }
//
//    private func parseKeyValue(from bytes: inout ByteIterator) throws -> (String, JSON) {
//        let key = try parseString(from: &bytes)
//        guard let colon = bytes.nextAfterWhitespace(), colon == UInt8(ascii: ":") else {
//            throw JSONParserError.dataCorrupted
//        }
//
//        let value = try parseJSON(from: &bytes)
//
//        return (key, value)
//    }
//
//    private func parseString(from bytes: inout ByteIterator) throws -> String {
//        guard let quote = bytes.nextAfterWhitespace(), quote == UInt8(ascii: "\"") else {
//            throw JSONParserError.dataCorrupted
//        }
//
//        var string = Data()
//        while let byte = bytes.next() {
//            switch byte {
//            case UInt8(ascii: "\\"):
//                // Don't worry about what the next character is. At this point, we're not validating
//                // the string, just looking for an unescaped double-quote.
//                string.append(byte)
//                guard let escaped = bytes.next() else { break }
//                string.append(escaped)
//
//            case UInt8(ascii: "\""):
//                break
//
//            default:
//                string.append(byte)
//            }
//        }
//
//
//
//    }
//
//
//    private func parseOpenedArray(from bytes: inout ByteIterator) throws -> JSON {
//
//    }
//
//}
//
