import simd
import SwiftUI

extension simd_quatf {
    var matrix: simd_float4x4 {
        get {
            simd_float4x4(self)
        }
        set {
            self = simd_quatf(newValue)
        }
    }

    static func fromPitchYaw(pitch: Float, yaw: Float) -> simd_quatf {
        let pitchQuat = simd_quatf(angle: pitch, axis: [1, 0, 0])
        let yawQuat = simd_quatf(angle: yaw, axis: [0, 1, 0])
        return yawQuat * pitchQuat
    }

    func extractPitchYaw() -> (pitch: Float, yaw: Float) {
        let matrix = self.matrix
        let pitch = asin(-matrix[2][1])
        let yaw = atan2(matrix[2][0], matrix[2][2])
        return (pitch, yaw)
    }

    func slerpShortest(to target: simd_quatf, t: Float) -> simd_quatf {
        let dotProduct = real * target.real + simd_dot(imag, target.imag)
        let adjustedTarget = dotProduct < 0 ? simd_quatf(ix: -target.imag.x, iy: -target.imag.y, iz: -target.imag.z, r: -target.real) : target
        return simd_slerp(self, adjustedTarget, t)
    }
}

extension SIMD3<Float> {
    func rounded(precision: Float = 0.0001) -> SIMD3<Float> {
        SIMD3<Float>((x / precision).rounded() * precision, (y / precision).rounded() * precision, (z / precision).rounded() * precision)
    }
}
