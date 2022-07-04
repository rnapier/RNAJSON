//public struct JSONTokenSequence<Base: Sequence>: Sequence where Base.Element == UInt8 {
//
//    public typealias Element = Result<JSONToken, JSONError>
//    var base: Base
//    var strict: Bool
//
//    public struct Iterator: IteratorProtocol {
//        public typealias Element = JSONTokenSequence.Element
//
//        var strict: Bool
//        var byteSource: Base.Iterator
//
//        internal init(underlyingIterator: Base.Iterator, strict: Bool) {
//            byteSource = underlyingIterator
//            self.strict = strict
//        }
//
//        public mutating func next() -> Element? {
//            let result = Task {
//                try await
//            }
//        }
//
//    }
//
//    public func makeIterator() -> Iterator {
//        return Iterator(underlyingIterator: base.makeIterator(), strict: strict)
//    }
//
//    public init(_ base: Base, strict: Bool = false) {
//        self.base = base
//        self.strict = strict
//    }
//
//}
