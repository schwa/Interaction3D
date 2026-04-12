import Foundation

public struct LoopTransformer: Transformer, Equatable {
    public var duration: TimeInterval

    public init(duration: TimeInterval) {
        self.duration = duration
    }

    public func transform(_ elapsed: TimeInterval) -> Double {
        (elapsed / duration).truncatingRemainder(dividingBy: 1.0)
    }
}
