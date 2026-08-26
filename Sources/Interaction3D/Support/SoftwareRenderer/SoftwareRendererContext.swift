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

    private var projection: SoftwareProjection {
        SoftwareProjection(
            viewMatrix: viewMatrix,
            projectionMatrix: projectionMatrix,
            clipToScreenMatrix: clipToScreenMatrix
        )
    }

    public func project(_ position: SIMD3<Float>, modelMatrix: float4x4 = matrix_identity_float4x4) -> CGPoint? {
        projection.project(position, modelMatrix: modelMatrix).map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) }
    }

    public func path(polygon: [SIMD3<Float>], modelMatrix: float4x4 = matrix_identity_float4x4) -> Path {
        let projected = projection.project(polygon: polygon, modelMatrix: modelMatrix)
        guard !projected.isEmpty else {
            return Path()
        }
        let points = projected.map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) }

        var path = Path()
        path.move(to: points[0])
        for point in points.dropFirst() {
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
