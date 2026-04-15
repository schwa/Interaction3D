import simd
import SwiftUI

// MARK: - Hardcoded cube for the rotation widget

/// A simple hardcoded cube mesh for software rendering.
/// Replaces the SwiftMesh dependency — only a unit cube is needed.
public struct Cube: Equatable, Sendable {
    /// The 8 vertices of a unit cube (normalized to unit sphere).
    public let positions: [SIMD3<Float>] = [
        simd_normalize(SIMD3(-1, -1, -1)),
        simd_normalize(SIMD3( 1, -1, -1)),
        simd_normalize(SIMD3( 1,  1, -1)),
        simd_normalize(SIMD3(-1,  1, -1)),
        simd_normalize(SIMD3(-1, -1,  1)),
        simd_normalize(SIMD3( 1, -1,  1)),
        simd_normalize(SIMD3( 1,  1,  1)),
        simd_normalize(SIMD3(-1,  1,  1)),
    ]

    /// The 6 quad faces as vertex index arrays.
    public let faces: [[Int]] = [
        [0, 3, 2, 1], // -Z
        [4, 5, 6, 7], // +Z
        [0, 1, 5, 4], // -Y
        [3, 7, 6, 2], // +Y
        [1, 2, 6, 5], // +X
        [0, 4, 7, 3], // -X
    ]

    public init() {}

    /// Centroid of all vertices.
    public var center: SIMD3<Float> {
        positions.reduce(.zero, +) / Float(positions.count)
    }

    /// Positions for a given face index.
    public func facePositions(_ faceIndex: Int) -> [SIMD3<Float>] {
        faces[faceIndex].map { positions[$0] }
    }

    /// Face normal via Newell's method.
    public func faceNormal(_ faceIndex: Int) -> SIMD3<Float> {
        let pts = facePositions(faceIndex)
        var normal = SIMD3<Float>.zero
        for i in 0..<pts.count {
            let current = pts[i]
            let next = pts[(i + 1) % pts.count]
            normal.x += (current.y - next.y) * (current.z + next.z)
            normal.y += (current.z - next.z) * (current.x + next.x)
            normal.z += (current.x - next.x) * (current.y + next.y)
        }
        let len = simd_length(normal)
        return len > 0 ? normal / len : SIMD3(0, 0, 1)
    }

    /// Centroid of a face.
    public func faceCentroid(_ faceIndex: Int) -> SIMD3<Float> {
        let pts = facePositions(faceIndex)
        return pts.reduce(.zero, +) / Float(pts.count)
    }

    /// All unique undirected edges as position pairs.
    public var renderEdges: [CubeEdge] {
        var seen = Set<Int>()
        var result: [CubeEdge] = []
        let vertexCount = positions.count
        for face in faces {
            for i in 0..<face.count {
                let a = face[i]
                let b = face[(i + 1) % face.count]
                let key = min(a, b) * vertexCount + max(a, b)
                if seen.insert(key).inserted {
                    result.append(CubeEdge(start: positions[a], end: positions[b]))
                }
            }
        }
        return result
    }

    /// Edges for a specific face.
    public func faceEdges(_ faceIndex: Int) -> [CubeEdge] {
        let verts = facePositions(faceIndex)
        return (0..<verts.count).map { i in
            CubeEdge(start: verts[i], end: verts[(i + 1) % verts.count])
        }
    }

    /// Project a path for a face.
    public func path(forFace faceIndex: Int, context: SoftwareRendererContext, modelMatrix: float4x4 = matrix_identity_float4x4) -> Path {
        context.path(polygon: facePositions(faceIndex), modelMatrix: modelMatrix)
    }

    /// Test if a face is front-facing relative to the camera.
    public func isFrontFacing(face faceIndex: Int, context: SoftwareRendererContext, modelMatrix: float4x4 = matrix_identity_float4x4) -> Bool {
        let verts = facePositions(faceIndex)
        guard verts.count >= 3 else { return false }

        let modelViewMatrix = context.viewMatrix * modelMatrix
        var viewVertices: [SIMD3<Float>] = []
        viewVertices.reserveCapacity(verts.count)

        for vertex in verts {
            let transformed = modelViewMatrix * SIMD4<Float>(vertex, 1)
            guard abs(transformed.w) > Float.leastNormalMagnitude else { return false }
            viewVertices.append((transformed / transformed.w).xyz)
        }

        let edgeA = viewVertices[1] - viewVertices[0]
        let edgeB = viewVertices[2] - viewVertices[0]
        let normal = simd_cross(edgeA, edgeB)
        let centroidView = viewVertices.reduce(.zero, +) / Float(viewVertices.count)
        return simd_dot(normal, -centroidView) > 0
    }

    /// Calculate a look-at quaternion for a point on the cube.
    public func calculateLookAt(at vertex: SIMD3<Float>) -> simd_quatf {
        let direction = simd_normalize(vertex - center)
        let yaw = atan2(direction.x, direction.z)
        let horizontalLength = sqrt(direction.x * direction.x + direction.z * direction.z)
        let pitch = -atan2(direction.y, horizontalLength)
        return .fromPitchYaw(pitch: pitch, yaw: yaw)
    }
}

// MARK: - CubeEdge

public struct CubeEdge: Hashable, Sendable {
    public var start: SIMD3<Float>
    public var end: SIMD3<Float>

    public var center: SIMD3<Float> {
        (start + end) / 2
    }
}
