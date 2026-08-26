import DemoKit
import GeometryLite3D
import Interaction3D
import simd
import SwiftUI

// MARK: - Turntable Drag Modifier

/// Turntable rotation via the gesture manager. Drag → yaw/pitch, accumulated as quaternion.
/// Handles yaw/pitch decomposition internally since quaternion rotation isn't additive.
private struct TurntableDragModifier: ViewModifier {
    let modifiers: EventModifiers?
    let sensitivity: CGFloat

    @Binding var rotation: simd_quatf

    @State private var rotationAtDragStart: simd_quatf = .init(angle: 0, axis: [0, 1, 0])
    @State private var isDragging = false

    func body(content: Content) -> some View {
        content.modifier(CoreDragModifier(modifiers: modifiers, minimumDistance: 10, momentum: true) { translation in
            if !isDragging {
                rotationAtDragStart = rotation
                isDragging = true
            }
            applyRotation(translation)
        } onEnded: {
            isDragging = false
        })
    }

    private func applyRotation(_ translation: CGSize) {
        let (startYaw, startPitch) = decomposeYawPitch(rotationAtDragStart)
        let yawDelta = Float(translation.width * sensitivity)
        let pitchDelta = Float(translation.height * sensitivity)
        let maxPitch = Float.pi / 2 - 0.02
        let newYaw = startYaw - yawDelta
        let newPitch = max(-maxPitch, min(maxPitch, startPitch - pitchDelta))
        rotation = composeYawPitch(yaw: newYaw, pitch: newPitch)
    }

    private func decomposeYawPitch(_ q: simd_quatf) -> (yaw: Float, pitch: Float) {
        let forward = q.act(SIMD3<Float>(0, 0, -1))
        let pitch = asin(min(max(forward.y, -1), 1))
        let yaw = atan2(-forward.x, -forward.z)
        return (yaw, pitch)
    }

    private func composeYawPitch(yaw: Float, pitch: Float) -> simd_quatf {
        let yawQ = simd_quatf(angle: yaw, axis: SIMD3<Float>(0, 1, 0))
        let pitchQ = simd_quatf(angle: pitch, axis: SIMD3<Float>(1, 0, 0))
        return simd_normalize(yawQ * pitchQ)
    }
}

// MARK: - Pan Drag Modifier

/// Command-drag → pan target in world XY.
private struct PanDragModifier: ViewModifier {
    let modifiers: EventModifiers?
    let sensitivity: CGFloat

    @Binding var target: SIMD3<Float>

    @State private var targetAtDragStart: SIMD3<Float> = .zero
    @State private var isDragging = false

    func body(content: Content) -> some View {
        content.modifier(CoreDragModifier(modifiers: modifiers, minimumDistance: 10, momentum: true) { translation in
            if !isDragging {
                targetAtDragStart = target
                isDragging = true
            }
            target = targetAtDragStart + SIMD3<Float>(
                Float(translation.width * sensitivity),
                Float(-translation.height * sensitivity),
                0
            )
        } onEnded: {
            isDragging = false
        })
    }
}

// MARK: - View Extensions

private extension View {
    func turntableDrag(_ modifiers: EventModifiers? = nil, sensitivity: CGFloat = 0.005, rotation: Binding<simd_quatf>) -> some View {
        modifier(TurntableDragModifier(modifiers: modifiers, sensitivity: sensitivity, rotation: rotation))
    }

    func panDrag(_ modifiers: EventModifiers? = nil, sensitivity: CGFloat = 0.01, target: Binding<SIMD3<Float>>) -> some View {
        modifier(PanDragModifier(modifiers: modifiers, sensitivity: sensitivity, target: target))
    }
}

// MARK: - Demo

struct TurntableDemo: View {
    @State private var rotation = simd_quatf(angle: 0, axis: [0, 1, 0])
    @State private var distance: Double = 5.0
    @State private var target: SIMD3<Float> = .zero
    @State private var showInspector = true

    var body: some View {
        Canvas { context, size in
            renderColoredCube(context: context, size: size, rotation: rotation, distance: Float(distance), target: target)
            renderTargetCrosshair(context: context, size: size)
        }
        .background(Color.black)
        .turntableDrag([], rotation: $rotation)
        .panDrag(.command, target: $target)
        #if os(macOS)
        .transformedScrollGesture(transformer: ScalingTransformer(magnitude: -0.01), writes: $distance)
        #endif
        .transformedMagnifyGesture(transformer: ScalingTransformer(magnitude: -1.0), writes: $distance)
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
                            Slider(value: $distance, in: 0.5...20)
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
        let perspectiveProjection = PerspectiveProjection(verticalAngleOfView: .degrees(60))
        let projectionMatrix = perspectiveProjection.projectionMatrix(width: Float(size.width), height: Float(size.height))
        let clipToScreenMatrix = float4x4.clipToScreen(width: Float(size.width), height: Float(size.height))
        let cameraMatrix = float4x4(translation: target) * rotation.matrix * float4x4(translation: [0, 0, Float(distance)])
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
        description: "Turntable camera with composable gestures.",
        group: "Interaction"
    )
}
