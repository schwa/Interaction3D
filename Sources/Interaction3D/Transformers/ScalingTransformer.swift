public struct ScalingTransformer<T>: Transformer where T: Numeric {
    public var magnitude: T

    public init(magnitude: T) {
        self.magnitude = magnitude
    }

    public func transform(_ input: T) -> T {
        input * magnitude
    }
}
