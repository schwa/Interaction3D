import Foundation
import GeometryLite3D
import simd

public protocol TransformerProtocol {
    associatedtype Value
    func apply(to value: Value) -> Value
}

// MARK: -

public protocol ParameterizedTransformerProtocol: TransformerProtocol {
    static var parameters: [AnyTransformerParameter<Self>] { get }
}

public enum ParameterMetadata {
    case floatingPoint(range: ClosedRange<Double>? = nil, step: Double? = nil)
    case vector(componentRange: ClosedRange<Double>? = nil)
    case angle
}

public protocol TransformerParameterProtocol {
    associatedtype Transformer: TransformerProtocol
    associatedtype Value
    var keyPath: WritableKeyPath<Transformer, Value> { get }
    var name: String { get }
    var metadata: ParameterMetadata? { get }
}

public struct TransformerParameter<Transformer, T>: TransformerParameterProtocol where Transformer: TransformerProtocol {
    public var keyPath: WritableKeyPath<Transformer, T>
    public var name: String
    public var metadata: ParameterMetadata?
}

public struct AnyTransformerParameter<Transformer>: TransformerParameterProtocol where Transformer: TransformerProtocol {
    public typealias Value = Any
    public var keyPath: WritableKeyPath<Transformer, Any> {
        get { fatalError("keyPath not directly accessible") }
        set { fatalError("keyPath not directly accessible") }
    }
    public var name: String
    public var metadata: ParameterMetadata?
    public let getValue: (Transformer) -> Any
    public let setValue: (inout Transformer, Any) -> Void
}

public extension AnyTransformerParameter {
    init<T>(keyPath: WritableKeyPath<Transformer, T>, name: String, metadata: ParameterMetadata? = nil) {
        self.name = name
        self.metadata = metadata
        self.getValue = { $0[keyPath: keyPath] }
        self.setValue = { $0[keyPath: keyPath] = $1 as! T }
    }
}


