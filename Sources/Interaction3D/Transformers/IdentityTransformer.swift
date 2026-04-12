public struct IdentityTransformer<T>: Transformer {
    public init() {}

    public func transform(_ input: T) -> T {
        input
    }
}
