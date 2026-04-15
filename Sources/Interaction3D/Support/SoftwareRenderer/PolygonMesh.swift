import Foundation
import GeometryLite3D
import simd
import SwiftUI

// MARK: - CubeRenderState

struct CubeRenderState {
    var rearFaceIndices: [Int] = []
    var frontFaceIndices: [Int] = []
    var rearEdges: Set<CubeEdge> = []
    var frontEdges: Set<CubeEdge> = []
    var rendererContext = SoftwareRendererContext()

    mutating func update(cube: Cube, rotation: simd_quatf, size: CGSize, verticalFOV: Double) {
        rearFaceIndices = []
        frontFaceIndices = []
        rearEdges = []
        frontEdges = []

        let perspectiveProjection = PerspectiveProjection(verticalAngleOfView: .degrees(Float(verticalFOV)))
        let projectionMatrix = perspectiveProjection.projectionMatrix(width: Float(size.width), height: Float(size.height))
        let clipToScreenMatrix = float4x4.clipToScreen(width: Float(size.width), height: Float(size.height))
        let cameraMatrix = rotation.matrix * float4x4(translation: [0, 0, 4])
        let viewMatrix = cameraMatrix.inverse
        rendererContext = SoftwareRendererContext(viewMatrix: viewMatrix, projectionMatrix: projectionMatrix, clipToScreenMatrix: clipToScreenMatrix)

        let modelMatrix = matrix_identity_float4x4
        for faceIndex in 0..<cube.faces.count {
            if cube.isFrontFacing(face: faceIndex, context: rendererContext, modelMatrix: modelMatrix) {
                frontFaceIndices.append(faceIndex)
                frontEdges.formUnion(cube.faceEdges(faceIndex))
            }
            else {
                rearFaceIndices.append(faceIndex)
                rearEdges.formUnion(cube.faceEdges(faceIndex))
            }
        }
    }

    func color(for vector: SIMD3<Float>) -> Color? {
        switch normalize(vector).rounded() {
        case [1, 0, 0]:
            return .red
        case [-1, 0, 0]:
            return .red.opacity(0.5)
        case [0, 1, 0]:
            return .green
        case [0, -1, 0]:
            return .green.opacity(0.5)
        case [0, 0, 1]:
            return .blue
        case [0, 0, -1]:
            return .blue.opacity(0.5)
        default:
            return nil
        }
    }

    func label(for vector: SIMD3<Float>) -> String? {
        switch normalize(vector).rounded() {
        case [1, 0, 0]:
            return "+X"
        case [-1, 0, 0]:
            return "-X"
        case [0, 1, 0]:
            return "+Y"
        case [0, -1, 0]:
            return "-Y"
        case [0, 0, 1]:
            return "+Z"
        case [0, 0, -1]:
            return "-Z"
        default:
            return nil
        }
    }
}
