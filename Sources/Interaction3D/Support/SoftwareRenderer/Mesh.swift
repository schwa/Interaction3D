import Foundation
import GeometryLite3D
import simd
import SwiftUI

public struct Mesh: Equatable, Sendable {
    public var vertices: [SIMD3<Float>]
    public var faces: [Face]

    public struct Edge: Hashable, Sendable {
        public var start: SIMD3<Float>
        public var end: SIMD3<Float>
    }

    public struct Face: Hashable, Sendable {
        public var vertices: [SIMD3<Float>]
    }

    public init(vertices: [SIMD3<Float>], faces: [[Int]]) {
        self.vertices = vertices
        self.faces = faces.map { indices in
            Face(vertices: indices.map { vertices[$0] })
        }
    }

    public init(vertices: [SIMD3<Float>], faces: [Face]) {
        self.vertices = vertices
        self.faces = faces
    }
}

public extension Mesh {
    var edges: [Edge] {
        var unique: Set<Edge> = []
        var result: [Edge] = []

        for face in faces {
            for edge in face.edges {
                if unique.insert(edge).inserted {
                    result.append(edge)
                }
            }
        }
        return result
    }

    var center: SIMD3<Float> {
        guard !vertices.isEmpty else {
            return SIMD3<Float>(repeating: 0)
        }
        return vertices.reduce(SIMD3<Float>(repeating: 0), +) / Float(vertices.count)
    }
}

public extension Mesh.Edge {
    var center: SIMD3<Float> {
        (start + end) / 2
    }
}

public extension Mesh.Face {
    var edges: [Mesh.Edge] {
        guard vertices.count > 1 else {
            return []
        }
        var result: [Mesh.Edge] = []
        let wrapped = vertices + [vertices.first!]
        for i in 0..<(wrapped.count - 1) {
            result.append(Mesh.Edge(start: wrapped[i], end: wrapped[i + 1]))
        }
        return result
    }

    var normal: SIMD3<Float> {
        guard vertices.count >= 3 else {
            return SIMD3<Float>(0, 0, 1)
        }

        let a = vertices[0]
        let b = vertices[1]
        let c = vertices[2]
        return simd_normalize(simd_cross(b - a, c - a))
    }

    var center: SIMD3<Float> {
        vertices.reduce(SIMD3<Float>(repeating: 0), +) / Float(vertices.count)
    }
}

public extension Mesh {
    func calculateLookAt(at vertex: SIMD3<Float>) -> simd_quatf {
        let direction = simd_normalize(vertex - center)
        let yaw = atan2(direction.x, direction.z)
        let horizontalLength = sqrt(direction.x * direction.x + direction.z * direction.z)
        let pitch = -atan2(direction.y, horizontalLength)
        return .fromPitchYaw(pitch: pitch, yaw: yaw)
    }
}

// public extension Mesh.Edge {
//    init(start: Int, end: Int) {
//        self.start = start
//        self.end = end
//    }
// }

public extension Mesh {
    static let cube = Mesh(
        vertices: [
            SIMD3<Float>(-1, -1, -1),
            SIMD3<Float>(1, -1, -1),
            SIMD3<Float>(1, 1, -1),
            SIMD3<Float>(-1, 1, -1),
            SIMD3<Float>(-1, -1, 1),
            SIMD3<Float>(1, -1, 1),
            SIMD3<Float>(1, 1, 1),
            SIMD3<Float>(-1, 1, 1)
        ].map { simd_normalize($0) },
        faces: [
            [0, 3, 2, 1], // front (facing -Z)
            [4, 5, 6, 7], // back (facing +Z)
            [0, 1, 5, 4], // bottom (facing -Y)
            [3, 7, 6, 2], // top (facing +Y)
            [1, 2, 6, 5], // right (facing +X)
            [0, 4, 7, 3]  // left (facing -X)
        ]
    )

    static let dodecahedron: Mesh = {
        let phi: Float = (1.0 + sqrt(5.0)) / 2.0
        let invPhi: Float = 1.0 / phi

        let vertices: [SIMD3<Float>] = [
            SIMD3<Float>(1, 1, 1),
            SIMD3<Float>(1, 1, -1),
            SIMD3<Float>(1, -1, 1),
            SIMD3<Float>(1, -1, -1),
            SIMD3<Float>(-1, 1, 1),
            SIMD3<Float>(-1, 1, -1),
            SIMD3<Float>(-1, -1, 1),
            SIMD3<Float>(-1, -1, -1),
            SIMD3<Float>(0, invPhi, phi),
            SIMD3<Float>(0, invPhi, -phi),
            SIMD3<Float>(0, -invPhi, phi),
            SIMD3<Float>(0, -invPhi, -phi),
            SIMD3<Float>(invPhi, phi, 0),
            SIMD3<Float>(invPhi, -phi, 0),
            SIMD3<Float>(-invPhi, phi, 0),
            SIMD3<Float>(-invPhi, -phi, 0),
            SIMD3<Float>(phi, 0, invPhi),
            SIMD3<Float>(phi, 0, -invPhi),
            SIMD3<Float>(-phi, 0, invPhi),
            SIMD3<Float>(-phi, 0, -invPhi)
        ].map { simd_normalize($0) }

        let faces: [[Int]] = [
            [0, 8, 10, 2, 16],
            [0, 16, 17, 1, 12],
            [0, 12, 14, 4, 8],
            [1, 17, 3, 11, 9],
            [1, 9, 5, 14, 12],
            [2, 10, 6, 15, 13],
            [2, 13, 3, 17, 16],
            [3, 13, 15, 7, 11],
            [4, 14, 5, 19, 18],
            [4, 18, 6, 10, 8],
            [5, 9, 11, 7, 19],
            [6, 18, 19, 7, 15]
        ]

        return Mesh(vertices: vertices, faces: faces)
    }()

    static let tetrahedron = Mesh(vertices: [SIMD3<Float>(1, 1, 1), SIMD3<Float>(-1, -1, 1), SIMD3<Float>(-1, 1, -1), SIMD3<Float>(1, -1, -1)].map { simd_normalize($0) }, faces: [[0, 1, 2], [0, 3, 1], [0, 2, 3], [1, 3, 2]])

    static let octahedron = Mesh(vertices: [SIMD3<Float>(1, 0, 0), SIMD3<Float>(-1, 0, 0), SIMD3<Float>(0, 1, 0), SIMD3<Float>(0, -1, 0), SIMD3<Float>(0, 0, 1), SIMD3<Float>(0, 0, -1)], faces: [[0, 2, 4], [0, 4, 3], [0, 3, 5], [0, 5, 2], [1, 2, 5], [1, 5, 3], [1, 3, 4], [1, 4, 2]])

    static let icosahedron: Mesh = {
        let phi: Float = (1.0 + sqrt(5.0)) / 2.0
        let vertices: [SIMD3<Float>] = [SIMD3<Float>(-1, phi, 0), SIMD3<Float>(1, phi, 0), SIMD3<Float>(-1, -phi, 0), SIMD3<Float>(1, -phi, 0), SIMD3<Float>(0, -1, phi), SIMD3<Float>(0, 1, phi), SIMD3<Float>(0, -1, -phi), SIMD3<Float>(0, 1, -phi), SIMD3<Float>(phi, 0, -1), SIMD3<Float>(phi, 0, 1), SIMD3<Float>(-phi, 0, -1), SIMD3<Float>(-phi, 0, 1)].map { simd_normalize($0) }
        let faces: [[Int]] = [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
        return Mesh(vertices: vertices, faces: faces)
    }()
}

public extension Mesh {
    func path(forFace face: Face, context: SoftwareRendererContext, modelMatrix: float4x4 = matrix_identity_float4x4) -> Path {
        context.path(polygon: face.vertices, modelMatrix: modelMatrix)
    }

    func isFrontFacing(face: Face, context: SoftwareRendererContext, modelMatrix: float4x4 = matrix_identity_float4x4) -> Bool {
        guard face.vertices.count >= 3 else {
            return false
        }

        let modelViewMatrix = context.viewMatrix * modelMatrix

        var viewVertices: [SIMD3<Float>] = []
        viewVertices.reserveCapacity(face.vertices.count)

        for vertex in face.vertices {
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
}

public struct MeshRenderState {
    public var rearFaces: [Mesh.Face] = []
    public var frontFaces: [Mesh.Face] = []
    public var rearEdges: Set<Mesh.Edge> = []
    public var frontEdges: Set<Mesh.Edge> = []
    public var rendererContext = SoftwareRendererContext()

    public init() {}

    public mutating func update(mesh: Mesh, rotation: simd_quatf, size: CGSize, verticalFOV: Double) {
        rearFaces = []
        frontFaces = []
        rearEdges = []
        frontEdges = []

        let perspectiveProjection = PerspectiveProjection(verticalAngleOfView: .degrees(Float(verticalFOV)), zClip: 1 ... 100)
        let projectionMatrix = perspectiveProjection.projectionMatrix(width: Float(size.width), height: Float(size.height))
        let clipToScreenMatrix = float4x4.clipToScreen(width: Float(size.width), height: Float(size.height))
        let cameraMatrix = rotation.matrix * float4x4(translation: [0, 0, 4])
        let viewMatrix = cameraMatrix.inverse
        rendererContext = SoftwareRendererContext(viewMatrix: viewMatrix, projectionMatrix: projectionMatrix, clipToScreenMatrix: clipToScreenMatrix)

        let modelMatrix = matrix_identity_float4x4
        for face in mesh.faces {
            if mesh.isFrontFacing(face: face, context: rendererContext, modelMatrix: modelMatrix) {
                frontFaces.append(face)
                frontEdges.formUnion(face.edges)
            }
            else {
                rearFaces.append(face)
                rearEdges.formUnion(face.edges)
            }
        }
    }

    public func color(for vector: SIMD3<Float>) -> Color? {
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

    public func label(for vector: SIMD3<Float>) -> String? {
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

