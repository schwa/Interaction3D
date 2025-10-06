import simd
import SwiftUI

public struct SoftwareRendererContext {
    public let viewMatrix: float4x4
    public let projectionMatrix: float4x4
    public let clipToScreenMatrix: float4x4

    public init() {
        viewMatrix = .identity
        projectionMatrix = .identity
        clipToScreenMatrix = .identity
    }

    public init(viewMatrix: float4x4, projectionMatrix: float4x4, clipToScreenMatrix: float4x4) {
        self.viewMatrix = viewMatrix
        self.projectionMatrix = projectionMatrix
        self.clipToScreenMatrix = clipToScreenMatrix
    }

    public func project(_ position: SIMD3<Float>, modelMatrix: float4x4 = matrix_identity_float4x4) -> CGPoint? {
        let worldPosition = modelMatrix * SIMD4<Float>(position, 1)
        let viewPosition = viewMatrix * worldPosition
        let clipPosition = projectionMatrix * viewPosition
        let w = clipPosition.w

        guard abs(w) > Float.leastNormalMagnitude else {
            return nil
        }

        var ndc = clipPosition / w
        ndc = clipToScreenMatrix * ndc
        let transformedW = ndc.w
        guard abs(transformedW) > Float.leastNormalMagnitude else {
            return nil
        }
        ndc /= transformedW

        return CGPoint(x: CGFloat(ndc.x), y: CGFloat(ndc.y))
    }

    public func path(polygon: [SIMD3<Float>], modelMatrix: float4x4 = matrix_identity_float4x4) -> Path {
        let projected = polygon.compactMap { project($0, modelMatrix: modelMatrix) }
        guard projected.count >= 3 else {
            return Path()
        }

        var path = Path()
        path.move(to: projected[0])
        for point in projected.dropFirst() {
            path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }
}

public extension float4x4 {
    var upperLeft3x3: float3x3 {
        float3x3(
            SIMD3<Float>(columns.0.x, columns.0.y, columns.0.z),
            SIMD3<Float>(columns.1.x, columns.1.y, columns.1.z),
            SIMD3<Float>(columns.2.x, columns.2.y, columns.2.z)
        )
    }

    static func clipToScreen(width: Float, height: Float) -> float4x4 {
        let halfWidth = width * 0.5
        let halfHeight = height * 0.5
        return float4x4(
            SIMD4<Float>(halfWidth, 0, 0, 0),
            SIMD4<Float>(0, -halfHeight, 0, 0),
            SIMD4<Float>(0, 0, 1, 0),
            SIMD4<Float>(halfWidth, halfHeight, 0, 1)
        )
    }
}
