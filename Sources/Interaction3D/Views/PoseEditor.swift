import SwiftUI

import Spatial

public struct ScaledPoseEditor: View {
    @Binding
    var value: ScaledPose3D

    public init(value: Binding<ScaledPose3D>) {
        self._value = value
    }

    public var body: some View {
        LabeledContent("Position") {
            let binding = Binding {
                value.position.vector
            }
            set: { newValue in
                value = ScaledPose3D(position: .init(newValue), rotation: value.rotation, scale: value.scale)
            }
            VectorEditor(value: binding, style: .number, semantic: .scale)
        }
        LabeledContent("Rotation") {
            let binding = Binding {
                value.rotation.vector
            }
            set: { newValue in
                value = ScaledPose3D(position: value.position, rotation: .init(newValue), scale: value.scale)
            }
            VectorEditor(value: binding, style: .number, semantic: .quaternion)
        }
        LabeledContent("Scale") {
            let binding = Binding {
                value.scale
            }
            set: { newValue in
                value = ScaledPose3D(position: value.position, rotation: value.rotation, scale: newValue)
            }
            TextField(value: binding, format: .number) {
                // This line intentionally left blank
            }
        }
    }
}


#Preview {
    @Previewable @State
    var pose: ScaledPose3D = {
        let matrix = float4x4(diagonal: [1, 1, 1, 1])
        guard let pose = ScaledPose3D(matrix) else {
            preconditionFailure("Failed to build preview pose from identity matrix")
        }
        return pose
    }()

    Form {
        ScaledPoseEditor(value: $pose)
    }
    .padding()
}
