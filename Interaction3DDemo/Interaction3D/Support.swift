import GeometryLite3D
import Interaction3D
import simd
import SwiftMesh
import SwiftUI

func colorForFace(normal: SIMD3<Float>) -> Color {
    // Calculate face normal to determine which axis it's aligned with
    let absNormal = SIMD3<Float>(abs(normal.x), abs(normal.y), abs(normal.z))

    // Find which axis has the largest component
    if absNormal.x > absNormal.y, absNormal.x > absNormal.z {
        return .red.opacity(0.7)  // X-axis faces
    }
    if absNormal.y > absNormal.x, absNormal.y > absNormal.z {
        return .green.opacity(0.7)  // Y-axis faces
    }
    return .blue.opacity(0.7)
}

func renderColoredCube(context: GraphicsContext, size: CGSize, cameraMatrix: simd_float4x4, modelMatrix: simd_float4x4 = float4x4(scale: [2, 2, 2])) {
    let perspectiveProjection = PerspectiveProjection(verticalAngleOfView: .degrees(60))
    let projectionMatrix = perspectiveProjection.projectionMatrix(width: Float(size.width), height: Float(size.height))
    let clipToScreenMatrix = float4x4.clipToScreen(width: Float(size.width), height: Float(size.height))
    let viewMatrix = cameraMatrix.inverse
    let rendererContext = SoftwareRendererContext(viewMatrix: viewMatrix, projectionMatrix: projectionMatrix, clipToScreenMatrix: clipToScreenMatrix)
    renderWorldAxes(context: context, rendererContext: rendererContext)
    let mesh = Mesh.cube
    for face in mesh.topology.faces where !mesh.isFrontFacing(face: face.id, context: rendererContext, modelMatrix: modelMatrix) {
        let path = mesh.path(forFace: face.id, context: rendererContext, modelMatrix: modelMatrix)
        let color = colorForFace(normal: mesh.faceNormal(face.id))
        context.fill(path, with: .color(color.opacity(0.3)))
    }
    for edge in mesh.renderEdges {
        guard let start = rendererContext.project(edge.start, modelMatrix: modelMatrix), let end = rendererContext.project(edge.end, modelMatrix: modelMatrix) else {
            continue
        }
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        context.stroke(path, with: .color(.white.opacity(0.5)), lineWidth: 1)
    }
    for face in mesh.topology.faces where mesh.isFrontFacing(face: face.id, context: rendererContext, modelMatrix: modelMatrix) {
        let path = mesh.path(forFace: face.id, context: rendererContext, modelMatrix: modelMatrix)
        let color = colorForFace(normal: mesh.faceNormal(face.id))
        context.fill(path, with: .color(color))
    }
}

func renderColoredCube(context: GraphicsContext, size: CGSize, rotation: simd_quatf, distance: Float, target: SIMD3<Float> = .zero, modelMatrix: simd_float4x4 = float4x4(scale: [2, 2, 2])) {
    // Set up perspective projection
    let perspectiveProjection = PerspectiveProjection(verticalAngleOfView: .degrees(60))
    let projectionMatrix = perspectiveProjection.projectionMatrix(width: Float(size.width), height: Float(size.height))
    let clipToScreenMatrix = float4x4.clipToScreen(width: Float(size.width), height: Float(size.height))

    // Set up camera: translate to target, apply rotation, then pull back by distance
    let cameraMatrix = float4x4(translation: target) * rotation.matrix * float4x4(translation: [0, 0, distance])
    let viewMatrix = cameraMatrix.inverse

    let rendererContext = SoftwareRendererContext(viewMatrix: viewMatrix, projectionMatrix: projectionMatrix, clipToScreenMatrix: clipToScreenMatrix)

    // Render world axes at origin
    renderWorldAxes(context: context, rendererContext: rendererContext)

    let mesh = Mesh.cube

    // Render back faces first
    for face in mesh.topology.faces where !mesh.isFrontFacing(face: face.id, context: rendererContext, modelMatrix: modelMatrix) {
        let path = mesh.path(forFace: face.id, context: rendererContext, modelMatrix: modelMatrix)
        let color = colorForFace(normal: mesh.faceNormal(face.id))
        context.fill(path, with: .color(color.opacity(0.3)))
    }

    // Render edges
    for edge in mesh.renderEdges {
        guard let start = rendererContext.project(edge.start, modelMatrix: modelMatrix), let end = rendererContext.project(edge.end, modelMatrix: modelMatrix) else {
            continue
        }
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        context.stroke(path, with: .color(.white.opacity(0.5)), lineWidth: 1)
    }

    // Render front faces
    for face in mesh.topology.faces where mesh.isFrontFacing(face: face.id, context: rendererContext, modelMatrix: modelMatrix) {
        let path = mesh.path(forFace: face.id, context: rendererContext, modelMatrix: modelMatrix)
        let color = colorForFace(normal: mesh.faceNormal(face.id))
        context.fill(path, with: .color(color))
    }
}

func renderWorldAxes(context: GraphicsContext, rendererContext: SoftwareRendererContext, axisLength: Float = 3.0) {
    let xStart = SIMD3<Float>(-axisLength, 0, 0)
    let xEnd = SIMD3<Float>(axisLength, 0, 0)
    let yStart = SIMD3<Float>(0, -axisLength, 0)
    let yEnd = SIMD3<Float>(0, axisLength, 0)
    let zStart = SIMD3<Float>(0, 0, -axisLength)
    let zEnd = SIMD3<Float>(0, 0, axisLength)

    let identityMatrix = matrix_identity_float4x4

    // X axis (red)
    if let xStartScreen = rendererContext.project(xStart, modelMatrix: identityMatrix),
        let xEndScreen = rendererContext.project(xEnd, modelMatrix: identityMatrix) {
        var path = Path()
        path.move(to: xStartScreen)
        path.addLine(to: xEndScreen)
        context.stroke(path, with: .color(.red), lineWidth: 2)
    }

    // Y axis (green)
    if let yStartScreen = rendererContext.project(yStart, modelMatrix: identityMatrix),
        let yEndScreen = rendererContext.project(yEnd, modelMatrix: identityMatrix) {
        var path = Path()
        path.move(to: yStartScreen)
        path.addLine(to: yEndScreen)
        context.stroke(path, with: .color(.green), lineWidth: 2)
    }

    // Z axis (blue)
    if let zStartScreen = rendererContext.project(zStart, modelMatrix: identityMatrix),
        let zEndScreen = rendererContext.project(zEnd, modelMatrix: identityMatrix) {
        var path = Path()
        path.move(to: zStartScreen)
        path.addLine(to: zEndScreen)
        context.stroke(path, with: .color(.blue), lineWidth: 2)
    }
}
