import Foundation
import GeometryLite3D
import simd
import SwiftMesh
import SwiftUI

// MARK: - Edge type for software rendering

public struct MeshEdge: Hashable, Sendable {
    public var start: SIMD3<Float>
    public var end: SIMD3<Float>

    public var center: SIMD3<Float> {
        (start + end) / 2
    }
}

// MARK: - Mesh extensions for software rendering

public extension Mesh {
    /// All unique undirected edges with their endpoint positions.
    var renderEdges: [MeshEdge] {
        topology.undirectedEdges().map { (a, b) in
            MeshEdge(start: positions[a.raw], end: positions[b.raw])
        }
    }

    /// Edges for a specific face.
    func faceEdges(_ face: HalfEdgeTopology.FaceID) -> [MeshEdge] {
        let verts = facePositions(face)
        guard verts.count >= 2 else { return [] }
        var result: [MeshEdge] = []
        for i in 0..<verts.count {
            let next = (i + 1) % verts.count
            result.append(MeshEdge(start: verts[i], end: verts[next]))
        }
        return result
    }
}

// MARK: - Software rendering helpers

public extension Mesh {
    func path(forFace faceID: HalfEdgeTopology.FaceID, context: SoftwareRendererContext, modelMatrix: float4x4 = matrix_identity_float4x4) -> Path {
        context.path(polygon: facePositions(faceID), modelMatrix: modelMatrix)
    }

    func isFrontFacing(face faceID: HalfEdgeTopology.FaceID, context: SoftwareRendererContext, modelMatrix: float4x4 = matrix_identity_float4x4) -> Bool {
        let verts = facePositions(faceID)
        guard verts.count >= 3 else {
            return false
        }

        let modelViewMatrix = context.viewMatrix * modelMatrix

        var viewVertices: [SIMD3<Float>] = []
        viewVertices.reserveCapacity(verts.count)

        for vertex in verts {
            let position = SIMD4<Float>(vertex, 1)
            let transformed = modelViewMatrix * position
            guard abs(transformed.w) > Float.leastNormalMagnitude else {
                return false
            }
            let viewPosition = (transformed / transformed.w).xyz
            viewVertices.append(viewPosition)
        }

        let edgeA = viewVertices[1] - viewVertices[0]
        let edgeB = viewVertices[2] - viewVertices[0]
        let normal = simd_cross(edgeA, edgeB)

        let centroidView = viewVertices.reduce(SIMD3<Float>(repeating: 0)) { $0 + $1 } / Float(viewVertices.count)
        let toCamera = -centroidView

        return simd_dot(normal, toCamera) > 0
    }

    func calculateLookAt(at vertex: SIMD3<Float>) -> simd_quatf {
        let direction = simd_normalize(vertex - center)
        let yaw = atan2(direction.x, direction.z)
        let horizontalLength = sqrt(direction.x * direction.x + direction.z * direction.z)
        let pitch = -atan2(direction.y, horizontalLength)
        return .fromPitchYaw(pitch: pitch, yaw: yaw)
    }
}

// MARK: - MeshRenderState

struct MeshRenderState {
    var rearFaceIDs: [HalfEdgeTopology.FaceID] = []
    var frontFaceIDs: [HalfEdgeTopology.FaceID] = []
    var rearEdges: Set<MeshEdge> = []
    var frontEdges: Set<MeshEdge> = []
    var rendererContext = SoftwareRendererContext()

    mutating func update(mesh: Mesh, rotation: simd_quatf, size: CGSize, verticalFOV: Double) {
        rearFaceIDs = []
        frontFaceIDs = []
        rearEdges = []
        frontEdges = []

        let perspectiveProjection = PerspectiveProjection(verticalAngleOfView: .degrees(Float(verticalFOV)))
        let projectionMatrix = perspectiveProjection.projectionMatrix(width: Float(size.width), height: Float(size.height))
        let clipToScreenMatrix = float4x4.clipToScreen(width: Float(size.width), height: Float(size.height))
        let cameraMatrix = rotation.matrix * float4x4(translation: [0, 0, 4])
        let viewMatrix = cameraMatrix.inverse
        rendererContext = SoftwareRendererContext(viewMatrix: viewMatrix, projectionMatrix: projectionMatrix, clipToScreenMatrix: clipToScreenMatrix)

        let modelMatrix = matrix_identity_float4x4
        for face in mesh.topology.faces {
            let faceID = face.id
            if mesh.isFrontFacing(face: faceID, context: rendererContext, modelMatrix: modelMatrix) {
                frontFaceIDs.append(faceID)
                frontEdges.formUnion(mesh.faceEdges(faceID))
            }
            else {
                rearFaceIDs.append(faceID)
                rearEdges.formUnion(mesh.faceEdges(faceID))
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
