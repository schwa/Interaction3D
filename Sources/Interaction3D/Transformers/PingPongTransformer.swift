import Foundation

public struct PingPongTransformer: TransformerProtocol, Equatable {
    public var duration: TimeInterval

    public init(duration: TimeInterval) {
        self.duration = duration
    }

    public func apply(to elapsed: TimeInterval) -> Double {
        let cycle = (elapsed / duration).truncatingRemainder(dividingBy: 2.0)
        return cycle < 1.0 ? cycle : 2.0 - cycle
    }
}
