// MARK: - Transformer Protocol

public protocol Transformer {
    associatedtype Input
    associatedtype Output
    func transform(_ input: Input) -> Output
}


// MARK: - Parameterized Transformer

public protocol ParameterizedTransformer: Transformer {
    static var parameters: [AnyTransformerParameter<Self>] { get }
}


