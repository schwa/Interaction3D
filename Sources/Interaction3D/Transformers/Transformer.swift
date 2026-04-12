// MARK: - Transformer Protocol

public protocol Transformer {
    associatedtype Input
    associatedtype Output
    func transform(_ input: Input) -> Output
}

@available(*, deprecated, renamed: "Transformer")
public typealias TransformerProtocol = Transformer

// MARK: - Parameterized Transformer

public protocol ParameterizedTransformer: Transformer {
    static var parameters: [AnyTransformerParameter<Self>] { get }
}

@available(*, deprecated, renamed: "ParameterizedTransformer")
public typealias ParameterizedTransformerProtocol = ParameterizedTransformer

