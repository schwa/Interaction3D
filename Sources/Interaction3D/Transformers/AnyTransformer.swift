public struct AnyTransformer<Input, Output>: Transformer {
    private let transformFunction: (Input) -> Output

    public init<T: Transformer>(_ transformer: T) where T.Input == Input, T.Output == Output {
        self.transformFunction = transformer.transform
    }

    public init(_ transform: @escaping (Input) -> Output) {
        self.transformFunction = transform
    }

    public func transform(_ input: Input) -> Output {
        transformFunction(input)
    }
}
