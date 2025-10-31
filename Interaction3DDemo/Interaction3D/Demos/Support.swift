import simd
import SwiftUI
import GeometryLite3D
import Interaction3D

func colorForFace(_ face: Mesh.Face) -> Color {
    // Calculate face normal to determine which axis it's aligned with
    let normal = face.normal
    let absNormal = SIMD3<Float>(abs(normal.x), abs(normal.y), abs(normal.z))

    // Find which axis has the largest component
    if absNormal.x > absNormal.y && absNormal.x > absNormal.z {
        return .red.opacity(0.7)  // X-axis faces
    } else if absNormal.y > absNormal.x && absNormal.y > absNormal.z {
        return .green.opacity(0.7)  // Y-axis faces
    } else {
        return .blue.opacity(0.7)  // Z-axis faces
    }
}

func renderColoredCube(context: GraphicsContext, size: CGSize, rotation: simd_quatf, distance: Float, modelMatrix: simd_float4x4 = float4x4(scale: [2, 2, 2])) {
    // Set up perspective projection
    let perspectiveProjection = PerspectiveProjection(verticalAngleOfView: .degrees(60))
    let projectionMatrix = perspectiveProjection.projectionMatrix(width: Float(size.width), height: Float(size.height))
    let clipToScreenMatrix = float4x4.clipToScreen(width: Float(size.width), height: Float(size.height))

    // Set up camera
    let cameraMatrix = rotation.matrix * float4x4(translation: [0, 0, distance])
    let viewMatrix = cameraMatrix.inverse

    let rendererContext = SoftwareRendererContext(viewMatrix: viewMatrix, projectionMatrix: projectionMatrix, clipToScreenMatrix: clipToScreenMatrix)

    let mesh = Mesh.cube

    // Render back faces first
    for face in mesh.faces {
        if !mesh.isFrontFacing(face: face, context: rendererContext, modelMatrix: modelMatrix) {
            let path = mesh.path(forFace: face, context: rendererContext, modelMatrix: modelMatrix)
            let color = colorForFace(face)
            context.fill(path, with: .color(color.opacity(0.3)))
        }
    }

    // Render edges
    for edge in mesh.edges {
        guard let start = rendererContext.project(edge.start, modelMatrix: modelMatrix), let end = rendererContext.project(edge.end, modelMatrix: modelMatrix) else {
            continue
        }
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        context.stroke(path, with: .color(.white.opacity(0.5)), lineWidth: 1)
    }

    // Render front faces
    for face in mesh.faces {
        if mesh.isFrontFacing(face: face, context: rendererContext, modelMatrix: modelMatrix) {
            let path = mesh.path(forFace: face, context: rendererContext, modelMatrix: modelMatrix)
            let color = colorForFace(face)
            context.fill(path, with: .color(color))
        }
    }
}
