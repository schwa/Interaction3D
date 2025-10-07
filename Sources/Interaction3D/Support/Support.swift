import simd
import SwiftUI

internal extension SIMD {
    var scalars: [Scalar] {
        get {
            (0..<scalarCount).map { self[$0] }
        }
        set {
            assert(newValue.count <= scalarCount, "New value has too many scalars")
            for i in 0..<Swift.min(scalarCount, newValue.count) {
                self[i] = newValue[i]
            }
        }
    }
}

internal extension simd_quatf {
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

}

internal extension SIMD3<Float> {
    func rounded(precision: Float = 1e-4) -> SIMD3<Float> {
        SIMD3<Float>((x / precision).rounded() * precision, (y / precision).rounded() * precision, (z / precision).rounded() * precision)
    }
}

// TODO: Move to GeometryLite3D
internal extension simd_float4x4 {
    /// Computes the yaw (rotation about Y-axis) from the transformation matrix.
    /// Assumes no shear and uniform scaling.
    var yaw: Float {
        atan2(columns.0.z, columns.2.z)
    }

    /// Computes the pitch (rotation about X-axis) from the transformation matrix.
    /// Assumes no shear and uniform scaling. Handles gimbal lock cases.
    var pitch: Float {
        let value = -columns.1.z
        return asin(clamp(value, min: -1.0, max: 1.0))  // Clamp to avoid domain errors
    }

    /// Detects if the matrix has shear (i.e., non-orthogonal basis vectors).
    var isShear: Bool {
        let x = SIMD3<Float>(columns.0.x, columns.0.y, columns.0.z)
        let y = SIMD3<Float>(columns.1.x, columns.1.y, columns.1.z)
        let z = SIMD3<Float>(columns.2.x, columns.2.y, columns.2.z)

        // Check if dot products are non-zero (non-orthogonal vectors indicate shear)
        let xyDot = simd_dot(x, y)
        let yzDot = simd_dot(y, z)
        let zxDot = simd_dot(z, x)

        return !isApproximatelyZero(xyDot) || !isApproximatelyZero(yzDot) || !isApproximatelyZero(zxDot)
    }

    /// Detects if the matrix has non-uniform scaling.
    var isNonUniformScale: Bool {
        let scaleX = length(SIMD3<Float>(columns.0.x, columns.0.y, columns.0.z))
        let scaleY = length(SIMD3<Float>(columns.1.x, columns.1.y, columns.1.z))
        let scaleZ = length(SIMD3<Float>(columns.2.x, columns.2.y, columns.2.z))

        // Non-uniform scaling if the scales are not equal
        return !isApproximatelyEqual(scaleX, scaleY) || !isApproximatelyEqual(scaleY, scaleZ)
    }

    /// Helper function to check if a value is approximately zero.
    private func isApproximatelyZero(_ value: Float, epsilon: Float = 1e-5) -> Bool {
        abs(value) < epsilon
    }

    /// Helper function to check if two values are approximately equal.
    private func isApproximatelyEqual(_ a: Float, _ b: Float, epsilon: Float = 1e-5) -> Bool {
        abs(a - b) < epsilon
    }

    /// Helper function to clamp values.
    private func clamp(_ value: Float, min: Float, max: Float) -> Float {
        Swift.max(min, Swift.min(max, value))
    }
}
