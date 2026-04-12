import Foundation
import GeometryLite3D
import simd

public struct OrbitTransformer: Transformer, Equatable {
    public var center: SIMD3<Float>
    public var radius: Float
    public var angle: AngleF
    public var normal: SIMD3<Float>

    public init(center: SIMD3<Float>, radius: Float, angle: AngleF, normal: SIMD3<Float> = [0, 0, 1]) {
        self.center = center
        self.radius = radius
        self.angle = angle
        self.normal = normalize(normal)
    }

    public func transform(_ value: SIMD3<Float>) -> SIMD3<Float> {
        let normalizedNormal = normalize(normal)
        let up = abs(dot(normalizedNormal, [0, 1, 0])) < 0.999 ? SIMD3<Float>([0, 1, 0]) : SIMD3<Float>([1, 0, 0])
        let right = normalize(cross(up, normalizedNormal))
        let forward = cross(normalizedNormal, right)
        return center + right * (radius * cos(angle.radians)) + forward * (radius * sin(angle.radians))
    }
}

extension OrbitTransformer: ParameterizedTransformer {
    public static var parameters: [AnyTransformerParameter<OrbitTransformer>] {
        [
            AnyTransformerParameter(keyPath: \OrbitTransformer.center, name: "center", metadata: .vector()),
            AnyTransformerParameter(keyPath: \OrbitTransformer.radius, name: "radius", metadata: .floatingPoint(range: 0...200)),
            AnyTransformerParameter(keyPath: \OrbitTransformer.angle, name: "angle", metadata: .angle),
            AnyTransformerParameter(keyPath: \OrbitTransformer.normal, name: "normal", metadata: .vector())
        ]
    }
}
