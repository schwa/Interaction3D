import Foundation
import GeometryLite3D
import simd

public protocol Interpolatable {
    static func interpolate(from: Self, to: Self, t: Double) -> Self
}

extension Float: Interpolatable {
    public static func interpolate(from: Self, to: Self, t: Double) -> Float {
        from + Float(t) * (to - from)
    }
}

extension Double: Interpolatable {
    public static func interpolate(from: Self, to: Self, t: Double) -> Double {
        from + t * (to - from)
    }
}

extension AngleF: Interpolatable {
    public static func interpolate(from: Self, to: Self, t: Double) -> AngleF {
        AngleF(radians: from.radians + Float(t) * (to.radians - from.radians))
    }
}

extension SIMD3<Float>: Interpolatable {
    public static func interpolate(from: Self, to: Self , t: Double) -> SIMD3<Float> {
        simd_mix(from, to, SIMD3<Float>(repeating: Float(t)))
    }
}
