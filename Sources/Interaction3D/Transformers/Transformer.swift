// MARK: - Transformer Protocol

public protocol Transformer<Input, Output> {
    associatedtype Input
    associatedtype Output
    func transform(_ input: Input) -> Output
}

// MARK: - Parameterized Transformer

public protocol ParameterizedTransformer: Transformer {
    static var parameters: [AnyTransformerParameter<Self>] { get }
}
