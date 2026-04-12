public struct WrappingTransformer<T>: Transformer where T: FloatingPoint {
    public var range: ClosedRange<T>

    public init(range: ClosedRange<T>) {
        self.range = range
    }

    public func transform(_ input: T) -> T {
        input.wrapped(to: range)
    }
}
