import Foundation

public struct OnceTransformer: TransformerProtocol, Equatable {
    public var duration: TimeInterval

    public init(duration: TimeInterval) {
        self.duration = duration
    }

    public func apply(to elapsed: TimeInterval) -> Double {
        min(elapsed / duration, 1.0)
    }
}
