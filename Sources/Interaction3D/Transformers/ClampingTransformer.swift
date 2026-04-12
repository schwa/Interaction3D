public struct ClampingTransformer<T>: Transformer where T: Comparable {
    public var range: ClosedRange<T>

    public init(range: ClosedRange<T>) {
        self.range = range
    }

    public func transform(_ input: T) -> T {
        input.clamped(to: range)
    }
}
