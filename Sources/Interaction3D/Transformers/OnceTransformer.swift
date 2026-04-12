import Foundation

public struct OnceTransformer: Transformer, Equatable {
    public var duration: TimeInterval

    public init(duration: TimeInterval) {
        self.duration = duration
    }

    public func transform(_ elapsed: TimeInterval) -> Double {
        min(elapsed / duration, 1.0)
    }
}
