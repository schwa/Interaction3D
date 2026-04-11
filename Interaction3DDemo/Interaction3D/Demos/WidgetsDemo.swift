import DemoKit
import Interaction3D
import simd
import SwiftUI

struct WidgetsDemo: View {
    @State private var rotation = simd_quatf(angle: 0, axis: [0, 1, 0])
    @State private var matrix: float4x4 = .init(diagonal: [1, 1, 1, 1])
    @State private var vector: SIMD3<Float> = [1, 2, 3]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Section("Rotation Widget") {
                    RotationWidget(rotation: $rotation)
                        .frame(width: 200, height: 200)
                }

                Divider()

                Section("Matrix View") {
                    MatrixView(value: matrix, style: .number.precision(.fractionLength(2)), colorize: true)
                        .monospaced()
                }

                Divider()

                Section("Matrix Editor") {
                    MatrixEditor(value: $matrix, style: .number.precision(.fractionLength(2)))
                        .monospaced()
                        .frame(maxWidth: 400)
                }

                Divider()

                Section("Vector Editor") {
                    VectorEditor(value: $vector, style: .number.precision(.fractionLength(2)), semantic: .point)
                        .frame(maxWidth: 400)
                }
            }
            .padding()
        }
    }
}

extension WidgetsDemo: DemoView {
    static var metadata = DemoMetadata(
        name: "Widgets",
        description: "Rotation widget, matrix view/editor, and vector editor.",
        group: "New"
    )
}
