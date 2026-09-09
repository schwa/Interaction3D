import simd
import SwiftUI

public struct CameraPositionEditor: View {
    @Binding private var matrix: simd_float4x4

    public init(matrix: Binding<simd_float4x4>) {
        self._matrix = matrix
    }

    public var body: some View {
        HStack {
            ScrubbableValueField("X", value: component(\.position.x), sensitivity: 0.01, precision: 3)
            ScrubbableValueField("Y", value: component(\.position.y), sensitivity: 0.01, precision: 3)
            ScrubbableValueField("Z", value: component(\.position.z), sensitivity: 0.01, precision: 3)
        }
    }

    private func component(_ keyPath: WritableKeyPath<CameraPose, Float>) -> Binding<Double> {
        Binding(
            get: { Double(CameraPose(matrix: matrix)[keyPath: keyPath]) },
            set: { newValue in
                var pose = CameraPose(matrix: matrix)
                pose[keyPath: keyPath] = Float(newValue)
                matrix = pose.matrix
            }
        )
    }
}

public struct CameraOrientationEditor: View {
    @Binding private var matrix: simd_float4x4

    public init(matrix: Binding<simd_float4x4>) {
        self._matrix = matrix
    }

    public var body: some View {
        HStack {
            ScrubbableValueField("Pitch", value: component(\.rotationDegrees.x), suffix: "°", range: -180 ... 180, sensitivity: 0.2)
            ScrubbableValueField("Yaw", value: component(\.rotationDegrees.y), suffix: "°", range: -180 ... 180, sensitivity: 0.2)
            ScrubbableValueField("Roll", value: component(\.rotationDegrees.z), suffix: "°", range: -180 ... 180, sensitivity: 0.2)
        }
    }

    private func component(_ keyPath: WritableKeyPath<CameraPose, Float>) -> Binding<Double> {
        Binding(
            get: { Double(CameraPose(matrix: matrix)[keyPath: keyPath]) },
            set: { newValue in
                var pose = CameraPose(matrix: matrix)
                pose[keyPath: keyPath] = Float(newValue)
                matrix = pose.matrix
            }
        )
    }
}

#Preview {
    @Previewable @State var matrix = matrix_identity_float4x4

    Form {
        CameraPositionEditor(matrix: $matrix)
        CameraOrientationEditor(matrix: $matrix)
    }
    .cameraControlStyle(.compact)
}
