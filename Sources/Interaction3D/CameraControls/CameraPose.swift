import simd

public struct CameraPose: Equatable, Sendable {
    public var position: SIMD3<Float>
    public var rotationDegrees: SIMD3<Float>

    public init(position: SIMD3<Float>, rotationDegrees: SIMD3<Float>) {
        self.position = position
        self.rotationDegrees = rotationDegrees
    }

    public init(matrix: simd_float4x4) {
        position = matrix.columns.3.xyz

        let yaw = asin(-matrix.columns.0.z)
        let pitch: Float
        let roll: Float
        if abs(cos(yaw)) > 0.0001 {
            pitch = atan2(matrix.columns.1.z, matrix.columns.2.z)
            roll = atan2(matrix.columns.0.y, matrix.columns.0.x)
        } else {
            pitch = atan2(-matrix.columns.2.y, matrix.columns.1.y)
            roll = 0
        }
        rotationDegrees = SIMD3<Float>(pitch, yaw, roll) * (180 / .pi)
    }

    public var matrix: simd_float4x4 {
        let radians = rotationDegrees * (.pi / 180)
        let rotationX = simd_float4x4(simd_quatf(angle: radians.x, axis: [1, 0, 0]))
        let rotationY = simd_float4x4(simd_quatf(angle: radians.y, axis: [0, 1, 0]))
        let rotationZ = simd_float4x4(simd_quatf(angle: radians.z, axis: [0, 0, 1]))
        var result = rotationZ * rotationY * rotationX
        result.columns.3 = SIMD4<Float>(position, 1)
        return result
    }
}

private extension SIMD4<Float> {
    var xyz: SIMD3<Float> {
        SIMD3<Float>(x, y, z)
    }
}
