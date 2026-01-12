import DemoKit
import GeometryLite3D
import Interaction3D
import simd
import SwiftFormats
import SwiftUI

struct PitchYawDemoView: View {
    @State
    private var rotation: simd_quatf = simd_quatf(angle: 0, axis: [0, 1, 0])

    @State
    private var distance: Float = 5.0

    @State
    private var target: SIMD3<Float> = .zero

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

    @State
    private var cubeScale: Float = 1.0

    private var mode: NewInteractionController.Mode {
        return .trackball()
    }

    private var transforms: InteractionAxisTransforms {
        let pitchSign = invertPitch ? -1.0 : 1.0
        let yawSign = invertYaw ? -1.0 : 1.0
        let zoomSign = invertZoom ? -1.0 : 1.0
        return InteractionAxisTransforms(
            yaw: { $0 * 0.01 * yawScale * yawSign },
            pitch: { $0 * 0.01 * pitchScale * pitchSign },
            zoom: { $0 * 0.5 * zoomScale * zoomSign },
            pan: { delta in SIMD3<Float>(Float(delta.x * 0.02), Float(-delta.y * 0.02), 0) }
        )
    }

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                renderColoredCube(context: context, size: size, rotation: rotation, distance: distance, modelMatrix: float4x4(scale: [cubeScale, cubeScale, cubeScale]))
            }
            .background(Color.black)
        }
        .newInteractionController(
            rotation: $rotation,
            distance: $distance,
            target: $target,
            mode: mode,
            transforms: transforms
        )
        .overlay(alignment: .topTrailing) {
            RotationWidget(rotation: $rotation)
                .frame(width: 120, height: 120)
                .padding()
                .background(Color.black, in: RoundedRectangle(cornerRadius: 8))
                .padding()
        }
        .overlay(alignment: .bottom) {
            controlsPanel
        }
        .overlay(alignment: .topLeading) {
            cubePanel
        }
    }

    private var controlsPanel: some View {
        Form {
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
                    VectorEditor(value: $target, style: .number, semantic: .point)
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
        .frame(width: 450)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .padding()
    }

    private var cubePanel: some View {
        Form {
            LabeledContent("Cube Scale") {
                HStack {
                    Slider(value: Binding(
                        get: { Double(cubeScale) },
                        set: { cubeScale = Float($0) }
                    ), in: 0.1...5.0)
                    Text(Double(cubeScale), format: .number.precision(.fractionLength(2)))
                        .frame(width: 50, alignment: .trailing)
                }
            }
        }
        .frame(width: 300)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .padding()
    }
}

extension PitchYawDemoView: DemoView {
    static var metadata = DemoMetadata(
        name: "Interaction Controller",
        systemImage: "rotate.3d",
        description: "Demo of the interaction controller with arcball, trackball, and first-person modes.",
        group: "Interaction",
        keywords: ["interaction", "arcball", "trackball", "rotation", "zoom"]
    )
}
