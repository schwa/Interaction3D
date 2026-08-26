import simd

struct SoftwareProjection {
    var viewMatrix: float4x4
    var projectionMatrix: float4x4
    var clipToScreenMatrix: float4x4

    func project(_ position: SIMD3<Float>, modelMatrix: float4x4 = matrix_identity_float4x4) -> SIMD2<Float>? {
        let clipPosition = projectionMatrix * viewMatrix * modelMatrix * SIMD4<Float>(position, 1)
        guard clipPosition.w > Float.leastNormalMagnitude, clipPosition.isFinite else {
            return nil
        }

        let screenPosition = clipToScreenMatrix * (clipPosition / clipPosition.w)
        guard abs(screenPosition.w) > Float.leastNormalMagnitude, screenPosition.isFinite else {
            return nil
        }

        let point = screenPosition / screenPosition.w
        return SIMD2(point.x, point.y)
    }

    func project(polygon: [SIMD3<Float>], modelMatrix: float4x4 = matrix_identity_float4x4) -> [SIMD2<Float>] {
        guard polygon.count >= 3 else {
            return []
        }

        let points = polygon.map { project($0, modelMatrix: modelMatrix) }
        guard points.allSatisfy({ $0 != nil }) else {
            return []
        }
        return points.compactMap(\.self)
    }
}

private extension SIMD4<Float> {
    var isFinite: Bool {
        x.isFinite && y.isFinite && z.isFinite && w.isFinite
    }
}
