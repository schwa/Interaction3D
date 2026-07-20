import simd
import SwiftUI

/// A debug panel for inspecting and controlling interactive camera state
public struct InteractiveCameraDebugView: View {
    @Binding
    var rotation: simd_quatf

    @Binding
    var distance: Float

    @Binding
    var target: SIMD3<Float>

    @Binding
    var mode: InteractiveCameraModifier.Mode

    @Binding
    var transforms: InteractionAxisTransforms

    @State
    private var pitchScale: Double = 1.0

    @State
    private var yawScale: Double = 1.0

    @State
    private var zoomScale: Double = 1.0

    @State
    private var invertPitch: Bool = false

    @State
    private var invertYaw: Bool = false

    @State
    private var invertZoom: Bool = true

    public init(
        rotation: Binding<simd_quatf>,
        distance: Binding<Float>,
        target: Binding<SIMD3<Float>>,
        mode: Binding<InteractiveCameraModifier.Mode>,
        transforms: Binding<InteractionAxisTransforms>
    ) {
        self._rotation = rotation
        self._distance = distance
        self._target = target
        self._mode = mode
        self._transforms = transforms
    }

    public var body: some View {
        Form {
            stateSection
            modeSection
            transformOptionsSection
        }
        .onChange(of: pitchScale) { updateTransforms() }
        .onChange(of: yawScale) { updateTransforms() }
        .onChange(of: zoomScale) { updateTransforms() }
        .onChange(of: invertPitch) { updateTransforms() }
        .onChange(of: invertYaw) { updateTransforms() }
        .onChange(of: invertZoom) { updateTransforms() }
    }

    private var stateSection: some View {
        Section("State") {
            LabeledContent("Distance") {
                HStack {
                    Slider(value: Binding(
                        get: { Double(distance) },
                        set: { distance = Float($0) }
                    ), in: 0.1...20)
                    Text(Double(distance), format: .number.precision(.fractionLength(2)))
                        .frame(width: 50, alignment: .trailing)
                }
            }

            LabeledContent("Target") {
                Text("[\(target.x, format: .number.precision(.fractionLength(2))), \(target.y, format: .number.precision(.fractionLength(2))), \(target.z, format: .number.precision(.fractionLength(2)))]")
            }

            LabeledContent("Rotation") {
                Text("[\(rotation.vector.x, format: .number.precision(.fractionLength(2))), \(rotation.vector.y, format: .number.precision(.fractionLength(2))), \(rotation.vector.z, format: .number.precision(.fractionLength(2))), \(rotation.vector.w, format: .number.precision(.fractionLength(2)))]")
            }

            Button("Reset") {
                rotation = simd_quatf(angle: 0, axis: [0, 1, 0])
                distance = 5.0
                target = .zero
            }
        }
    }

    private var modeSection: some View {
        Section("Mode") {
            Picker("Interaction Mode", selection: modeBinding) {
                Text("Turntable").tag(0)
                Text("Arcball").tag(1)
            }
            .pickerStyle(.segmented)
        }
    }

    private var modeBinding: Binding<Int> {
        Binding(
            get: {
                switch mode {
                case .turntable: return 0
                case .arcball: return 1
                }
            },
            set: { newValue in
                switch newValue {
                case 0: mode = .turntable()
                case 1: mode = .arcball()
                default: mode = .turntable()
                }
            }
        )
    }

    private var transformOptionsSection: some View {
        Section("Transform Options") {
            LabeledContent("Pitch Scale") {
                HStack {
                    Slider(value: $pitchScale, in: 0.1...5.0)
                    Text(pitchScale, format: .number.precision(.fractionLength(2)))
                        .frame(width: 50, alignment: .trailing)
                }
            }

            LabeledContent("Yaw Scale") {
                HStack {
                    Slider(value: $yawScale, in: 0.1...5.0)
                    Text(yawScale, format: .number.precision(.fractionLength(2)))
                        .frame(width: 50, alignment: .trailing)
                }
            }

            LabeledContent("Zoom Scale") {
                HStack {
                    Slider(value: $zoomScale, in: 0.1...5.0)
                    Text(zoomScale, format: .number.precision(.fractionLength(2)))
                        .frame(width: 50, alignment: .trailing)
                }
            }

            Toggle("Invert Pitch", isOn: $invertPitch)
            Toggle("Invert Yaw", isOn: $invertYaw)
            Toggle("Invert Zoom", isOn: $invertZoom)
        }
    }

    private func updateTransforms() {
        let pitchSign = invertPitch ? -1.0 : 1.0
        let yawSign = invertYaw ? -1.0 : 1.0
        let zoomSign = invertZoom ? -1.0 : 1.0
        let capturedYawScale = yawScale
        let capturedPitchScale = pitchScale
        let capturedZoomScale = zoomScale
        transforms = InteractionAxisTransforms(
            yaw: { $0 * 0.01 * capturedYawScale * yawSign },
            pitch: { $0 * 0.01 * capturedPitchScale * pitchSign },
            zoom: { $0 * 0.5 * capturedZoomScale * zoomSign },
            pan: { delta in SIMD3<Float>(Float(delta.x * 0.02), Float(-delta.y * 0.02), 0) }
        )
    }
}

#Preview {
    @Previewable @State
    var rotation: simd_quatf = .identity

    @Previewable @State
    var distance: Float = 5

    @Previewable @State
    var target: SIMD3<Float> = .zero

    @Previewable @State
    var mode: InteractiveCameraModifier.Mode = .turntable()

    @Previewable @State
    var transforms: InteractionAxisTransforms = .default

    InteractiveCameraDebugView(rotation: $rotation, distance: $distance, target: $target, mode: $mode, transforms: $transforms)
}
