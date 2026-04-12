public struct IdentityTransformer<T>: Transformer {
    public init() {
        // intentionally empty
    }

    public func transform(_ input: T) -> T {
        input
    }
}
