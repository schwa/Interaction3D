import Foundation

public struct LoopTransformer: TransformerProtocol, Equatable {
    public var duration: TimeInterval

    public init(duration: TimeInterval) {
        self.duration = duration
    }

    public func apply(to elapsed: TimeInterval) -> Double {
        (elapsed / duration).truncatingRemainder(dividingBy: 1.0)
    }
}
