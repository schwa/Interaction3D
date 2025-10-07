import DemoKit
import GeometryLite3D
import Interaction3D
import simd
import SwiftUI

struct RotationWidgetDemoView: View {
    @State
    private var rotation: simd_quatf = .identity

    enum MeshType: CaseIterable {
        case tetrahedron
        case cube
        case octahedron
        case dodecahedron
        case icosahedron

        var mesh: Mesh {
            switch self {
            case .tetrahedron: return .tetrahedron
            case .cube: return .cube
            case .octahedron: return .octahedron
            case .dodecahedron: return .dodecahedron
            case .icosahedron: return .icosahedron
            }
        }

        var title: String {
            switch self {
            case .tetrahedron: return "Tetrahedron"
            case .cube: return "Cube"
            case .octahedron: return "Octahedron"
            case .dodecahedron: return "Dodecahedron"
            case .icosahedron: return "Icosahedron"
            }
        }
    }

    @State
    private var meshType: MeshType = .cube

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .bottomTrailing) {
                RotationWidget(rotation: $rotation, mesh: meshType.mesh)
                    .frame(width: 120, height: 120)
                    .padding()
                    .background(Color.black, in: RoundedRectangle(cornerRadius: 8))
                    .padding()
            }
            .toolbar {
                Picker("Mesh Type", selection: $meshType) {
                    ForEach(MeshType.allCases, id: \.self) { type in
                        Text(type.title).tag(type)
                    }
                }
            }
    }
}

extension RotationWidgetDemoView: DemoView {
    static var metadata = DemoMetadata(
        name: "Wireframe Cube",
        systemImage: "cube",
        description: "Canvas-rendered wireframe cube with adjustable pitch and yaw.",
        group: "Interaction3D",
        keywords: ["cube", "canvas", "wireframe"],
        color: .teal
    )
}
