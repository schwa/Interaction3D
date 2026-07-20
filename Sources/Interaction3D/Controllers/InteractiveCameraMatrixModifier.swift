import GeometryLite3D
import simd
import SwiftUI

// MARK: - Interactive Camera Matrix Modifier

/// Adapter that bridges between simd_float4x4 camera matrix and the rotation/distance/target state
public struct InteractiveCameraMatrixModifier: ViewModifier {
    @Binding
    var cameraMatrix: simd_float4x4

    var mode: InteractiveCameraModifier.Mode
    var transforms: InteractionAxisTransforms
    var target: SIMD3<Float>

    @State
    private var interactionState = InteractionState()

    @State
    private var hasInitializedFromMatrix = false

    public init(
        cameraMatrix: Binding<simd_float4x4>,
        mode: InteractiveCameraModifier.Mode,
        transforms: InteractionAxisTransforms = .default,
        target: SIMD3<Float> = .zero
    ) {
        self._cameraMatrix = cameraMatrix
        self.mode = mode
        self.transforms = transforms
        self.target = target
    }

    public func body(content: Content) -> some View {
        content
            .modifier(
                InteractiveCameraModifier(
                    rotation: $interactionState.rotation,
                    distance: $interactionState.distance,
                    target: $interactionState.target,
                    mode: mode,
                    transforms: transforms
                )
            )
            .onChange(of: interactionState) { _, newValue in
                guard hasInitializedFromMatrix else {
                    return
                }
                updateCameraMatrixFromInteraction()
            }
            .onAppear {
                guard !hasInitializedFromMatrix else {
                    return
                }
                initializeStateFromMatrix()
            }
    }

    private func initializeStateFromMatrix() {
        guard let components = cameraMatrix.decompose else {
            return
        }

        let position = components.translate
        let distance = max(length(target - position), 0.01)

        // Compute a lookAt rotation from position toward the target
        let forward = normalize(target - position)
        let worldUp = SIMD3<Float>(0, 1, 0)
        let right = normalize(cross(forward, worldUp))
        let up = cross(right, forward)
        // Build a rotation matrix where -Z is forward (camera convention)
        let rotationMatrix = simd_float3x3(columns: (right, up, -forward))
        let rotation = simd_normalize(simd_quatf(rotationMatrix))

        interactionState = InteractionState(rotation: rotation, distance: distance, target: target)
        hasInitializedFromMatrix = true
    }

    private func updateCameraMatrixFromInteraction() {
        let rotation = interactionState.rotation
        let forward = rotation.act(SIMD3<Float>(0, 0, -1))
        let position = interactionState.target - forward * interactionState.distance

        var newMatrix = rotation.matrix
        newMatrix.columns.3 = SIMD4<Float>(position, 1)

        cameraMatrix = newMatrix
    }

}

// MARK: - View Extension

public extension View {
    func interactiveCamera(
        cameraMatrix: Binding<simd_float4x4>,
        mode: InteractiveCameraModifier.Mode = .turntable(),
        transforms: InteractionAxisTransforms = .default,
        target: SIMD3<Float> = .zero
    ) -> some View {
        modifier(InteractiveCameraMatrixModifier(cameraMatrix: cameraMatrix, mode: mode, transforms: transforms, target: target))
    }
}
