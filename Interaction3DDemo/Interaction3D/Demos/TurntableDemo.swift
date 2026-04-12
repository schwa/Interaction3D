import DemoKit
import GeometryLite3D
import Interaction3D
import simd
import SwiftUI

struct TurntableDemo: View {
    @State private var rotation = simd_quatf(angle: 0, axis: [0, 1, 0])
    @State private var distance: Float = 5.0
    @State private var target: SIMD3<Float> = .zero

    @State private var showInspector = true

    var body: some View {
        GeometryReader { _ in
            Canvas { context, size in
                renderColoredCube(context: context, size: size, rotation: rotation, distance: distance, target: target)
                renderTargetCrosshair(context: context, size: size)
            }
            .background(Color.black)
        }
        .interactiveCamera(
            rotation: $rotation,
            distance: $distance,
            target: $target,
            mode: .turntable()
        )
        .overlay(alignment: .topTrailing) {
            RotationWidget(rotation: $rotation)
                .frame(width: 100, height: 100)
                .padding(8)
                .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                .padding()
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: 4) {
                Text("Drag to orbit around the target")
                Text("Scroll wheel or pinch to zoom in and out")
                Text("⌘-Drag to pan the target point")
            }
            .font(.body)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            .padding()
        }
        .toolbar {
            Toggle(isOn: $showInspector) {
                Label("Inspector", systemImage: "sidebar.trailing")
            }
        }
        .inspector(isPresented: $showInspector) {
            Form {
                Section("Camera State") {
                    LabeledContent("Distance") {
                        HStack {
                            Slider(value: Binding(
                                get: { Double(distance) },
                                set: { distance = Float($0) }
                            ), in: 0.5...20)
                            Text(Double(distance), format: .number.precision(.fractionLength(2)))
                                .monospacedDigit()
                                .frame(width: 50, alignment: .trailing)
                        }
                    }

                    LabeledContent("Target") {
                        VectorEditor(value: $target, style: .number.precision(.fractionLength(2)), semantic: .point)
                    }

                    LabeledContent("Rotation") {
                        Text("[\(rotation.vector.x, format: .number.precision(.fractionLength(2))), \(rotation.vector.y, format: .number.precision(.fractionLength(2))), \(rotation.vector.z, format: .number.precision(.fractionLength(2))), \(rotation.vector.w, format: .number.precision(.fractionLength(2)))]")
                            .monospacedDigit()
                    }
                }

                Section("Actions") {
                    Button("Reset") {
                        withAnimation {
                            rotation = simd_quatf(angle: 0, axis: [0, 1, 0])
                            distance = 5.0
                            target = .zero
                        }
                    }
                }
            }
            .inspectorColumnWidth(min: 250, ideal: 300, max: 400)
        }
    }

    private func renderTargetCrosshair(context: GraphicsContext, size: CGSize) {
        // Project the target point to screen space
        let perspectiveProjection = PerspectiveProjection(verticalAngleOfView: .degrees(60))
        let projectionMatrix = perspectiveProjection.projectionMatrix(width: Float(size.width), height: Float(size.height))
        let clipToScreenMatrix = float4x4.clipToScreen(width: Float(size.width), height: Float(size.height))
        let cameraMatrix = float4x4(translation: target) * rotation.matrix * float4x4(translation: [0, 0, distance])
        let viewMatrix = cameraMatrix.inverse
        let rendererContext = SoftwareRendererContext(viewMatrix: viewMatrix, projectionMatrix: projectionMatrix, clipToScreenMatrix: clipToScreenMatrix)

        guard let screenPoint = rendererContext.project(target, modelMatrix: matrix_identity_float4x4) else {
            return
        }

        let crosshairSize: CGFloat = 10
        var horizontal = Path()
        horizontal.move(to: CGPoint(x: screenPoint.x - crosshairSize, y: screenPoint.y))
        horizontal.addLine(to: CGPoint(x: screenPoint.x + crosshairSize, y: screenPoint.y))
        var vertical = Path()
        vertical.move(to: CGPoint(x: screenPoint.x, y: screenPoint.y - crosshairSize))
        vertical.addLine(to: CGPoint(x: screenPoint.x, y: screenPoint.y + crosshairSize))

        context.stroke(horizontal, with: .color(.yellow), lineWidth: 1)
        context.stroke(vertical, with: .color(.yellow), lineWidth: 1)
    }
}

extension TurntableDemo: DemoView {
    static var metadata = DemoMetadata(
        name: "Turntable",
        description: "Turntable camera with editable rotation, distance, and target.",
        group: "Interaction"
    )
}
