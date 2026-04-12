import Foundation

public struct PingPongTransformer: Transformer, Equatable {
    public var duration: TimeInterval

    public init(duration: TimeInterval) {
        self.duration = duration
    }

    public func transform(_ elapsed: TimeInterval) -> Double {
        let cycle = (elapsed / duration).truncatingRemainder(dividingBy: 2.0)
        return cycle < 1.0 ? cycle : 2.0 - cycle
    }
}
