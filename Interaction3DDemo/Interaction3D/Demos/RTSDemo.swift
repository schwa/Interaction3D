import DemoKit
import Interaction3D
import simd
import SwiftUI

struct RTSDemo: View {
    @State private var pose = RTSCameraPose()
    @State private var showInspector = true

    var body: some View {
        Canvas { context, size in
            renderColoredCube(context: context, size: size, cameraMatrix: pose.cameraMatrix)
        }
        .background(Color.black)
        .rtsMovement(pose: $pose)
        .overlay(alignment: .bottom) {
            VStack(spacing: 4) {
                Text("WASD or arrows to pan, Q/E to rotate, R/F or scroll to zoom")
                Text("Move the cursor to the edge to pan, Shift for faster, Home to reset")
            }
            .font(.body)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            .padding()
            .allowsHitTesting(false)
        }
        .toolbar {
            Toggle(isOn: $showInspector) {
                Label("Inspector", systemImage: "sidebar.trailing")
            }
        }
        .inspector(isPresented: $showInspector) {
            Form {
                Section("Camera") {
                    LabeledContent("Target") {
                        Text("\(pose.target.x, format: .number.precision(.fractionLength(2))), \(pose.target.z, format: .number.precision(.fractionLength(2)))")
                            .monospacedDigit()
                    }
                    LabeledContent("Yaw") {
                        Text(Angle(radians: Double(pose.yaw)).degrees, format: .number.precision(.fractionLength(0)))
                            .monospacedDigit()
                    }
                    LabeledContent("Pitch") {
                        Slider(value: Binding { Double(pose.pitch) } set: { pose.pitch = Float($0) }, in: 0.1...(Double.pi / 2 - 0.01))
                    }
                    LabeledContent("Distance") {
                        Text(pose.distance, format: .number.precision(.fractionLength(2)))
                            .monospacedDigit()
                    }
                }
                Section {
                    Button("Reset") {
                        pose = RTSCameraPose()
                    }
                }
            }
            .inspectorColumnWidth(min: 250, ideal: 300, max: 400)
        }
    }
}

extension RTSDemo: DemoView {
    static var metadata = DemoMetadata(
        name: "RTS Camera",
        description: "Real-time strategy style camera with keyboard, scroll, and edge panning.",
        group: "Interaction"
    )
}
