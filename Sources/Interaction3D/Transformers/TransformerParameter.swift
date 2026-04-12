public enum ParameterMetadata {
    case floatingPoint(range: ClosedRange<Double>? = nil, step: Double? = nil)
    case vector(componentRange: ClosedRange<Double>? = nil)
    case angle
}

public protocol TransformerParameterProtocol {
    associatedtype Base: Transformer
    associatedtype Value

    var keyPath: WritableKeyPath<Base, Value> { get }
    var name: String { get }
    var metadata: ParameterMetadata? { get }
}

public struct TransformerParameter<T, V>: TransformerParameterProtocol where T: Transformer {
    public typealias Base = T

    public var keyPath: WritableKeyPath<T, V>
    public var name: String
    public var metadata: ParameterMetadata?
}

public struct AnyTransformerParameter<T>: TransformerParameterProtocol where T: Transformer {
    public typealias Base = T
    public typealias Value = Any

    public var keyPath: WritableKeyPath<T, Any> {
        get { fatalError("keyPath not directly accessible") }
        // swiftlint:disable:next unused_setter_value
        set { fatalError("keyPath not directly accessible") }
    }
    public var name: String
    public var metadata: ParameterMetadata?

    public let getValue: (T) -> Any
    public let setValue: (inout T, Any) -> Void
}

public extension AnyTransformerParameter {
    init<V>(keyPath: WritableKeyPath<T, V>, name: String, metadata: ParameterMetadata? = nil) {
        self.name = name
        self.metadata = metadata
        self.getValue = { $0[keyPath: keyPath] }
        // swiftlint:disable:next force_cast
        self.setValue = { $0[keyPath: keyPath] = $1 as! V }
    }
}
