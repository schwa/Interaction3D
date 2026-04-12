import Foundation
import simd

public struct LerpPositionTransformer: Transformer, Equatable {
    public var start: SIMD3<Float>
    public var end: SIMD3<Float>
    public var t: Float

    public init(start: SIMD3<Float>, end: SIMD3<Float>, t: Float) {
        self.start = start
        self.end = end
        self.t = t
    }

    public func transform(_ value: SIMD3<Float>) -> SIMD3<Float> {
        simd_mix(start, end, SIMD3<Float>(repeating: t))
    }
}

extension LerpPositionTransformer: ParameterizedTransformer {
    public static var parameters: [AnyTransformerParameter<LerpPositionTransformer>] {
        [
            AnyTransformerParameter(keyPath: \LerpPositionTransformer.start, name: "start", metadata: .vector()),
            AnyTransformerParameter(keyPath: \LerpPositionTransformer.end, name: "end", metadata: .vector()),
            AnyTransformerParameter(keyPath: \LerpPositionTransformer.t, name: "t", metadata: .floatingPoint(range: 0...1))
        ]
    }
}
