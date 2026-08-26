import GeometryLite3D
import simd

struct CameraMatrixSynchronizer {
    let target: SIMD3<Float>
    let minimumDistance: Float

    init(target: SIMD3<Float>, minimumDistance: Float = 0.01) {
        self.target = target
        self.minimumDistance = minimumDistance
    }

    func interactionState(from cameraMatrix: simd_float4x4) -> InteractionState? {
        guard let components = cameraMatrix.decompose else {
            return nil
        }

        let position = components.translate
        let offset = target - position
        let rawDistance = length(offset)
        let rotation = rawDistance > Float.ulpOfOne
            ? lookRotation(forward: offset / rawDistance)
            : matrixRotation(cameraMatrix)

        return InteractionState(
            rotation: rotation,
            distance: max(rawDistance, minimumDistance),
            target: target
        )
    }

    func cameraMatrix(from interactionState: InteractionState) -> simd_float4x4 {
        let forward = interactionState.rotation.act(SIMD3<Float>(0, 0, -1))
        let position = interactionState.target - forward * interactionState.distance
        var matrix = interactionState.rotation.matrix
        matrix.columns.3 = SIMD4<Float>(position, 1)
        return matrix
    }

    private func lookRotation(forward: SIMD3<Float>) -> simd_quatf {
        let worldUp = SIMD3<Float>(0, 1, 0)
        let referenceUp = abs(dot(forward, worldUp)) > 0.999 ? SIMD3<Float>(0, 0, 1) : worldUp
        let right = normalize(cross(forward, referenceUp))
        let up = cross(right, forward)
        return simd_normalize(simd_quatf(simd_float3x3(columns: (right, up, -forward))))
    }

    private func matrixRotation(_ matrix: simd_float4x4) -> simd_quatf {
        let rotationMatrix = simd_float3x3(columns: (
            normalize(SIMD3<Float>(matrix.columns.0.x, matrix.columns.0.y, matrix.columns.0.z)),
            normalize(SIMD3<Float>(matrix.columns.1.x, matrix.columns.1.y, matrix.columns.1.z)),
            normalize(SIMD3<Float>(matrix.columns.2.x, matrix.columns.2.y, matrix.columns.2.z))
        ))
        return simd_normalize(simd_quatf(rotationMatrix))
    }
}
