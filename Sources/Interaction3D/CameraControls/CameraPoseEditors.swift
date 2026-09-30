import simd
import SwiftUI

public struct CameraPositionEditor: View {
    @Binding private var matrix: simd_float4x4

    public init(matrix: Binding<simd_float4x4>) {
        self._matrix = matrix
    }

    public var body: some View {
        HStack {
            ScrubbableValueField("X", value: $matrix[cameraPose: \.position.x], sensitivity: 0.01, precision: 3)
            ScrubbableValueField("Y", value: $matrix[cameraPose: \.position.y], sensitivity: 0.01, precision: 3)
            ScrubbableValueField("Z", value: $matrix[cameraPose: \.position.z], sensitivity: 0.01, precision: 3)
        }
    }
}

public struct CameraOrientationEditor: View {
    @Binding private var matrix: simd_float4x4

    public init(matrix: Binding<simd_float4x4>) {
        self._matrix = matrix
    }

    public var body: some View {
        HStack {
            ScrubbableValueField("Pitch", value: $matrix[cameraPose: \.rotationDegrees.x], suffix: "°", range: -180 ... 180, sensitivity: 0.2)
            ScrubbableValueField("Yaw", value: $matrix[cameraPose: \.rotationDegrees.y], suffix: "°", range: -180 ... 180, sensitivity: 0.2)
            ScrubbableValueField("Roll", value: $matrix[cameraPose: \.rotationDegrees.z], suffix: "°", range: -180 ... 180, sensitivity: 0.2)
        }
    }
}

private extension simd_float4x4 {
    subscript(cameraPose keyPath: WritableKeyPath<CameraPose, Float>) -> Double {
        get { Double(CameraPose(matrix: self)[keyPath: keyPath]) }
        set {
            var pose = CameraPose(matrix: self)
            pose[keyPath: keyPath] = Float(newValue)
            self = pose.matrix
        }
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
