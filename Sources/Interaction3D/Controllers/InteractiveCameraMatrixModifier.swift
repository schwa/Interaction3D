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

    @State
    private var interactionState = InteractionState()

    @State
    private var hasInitializedFromMatrix = false

    public init(
        cameraMatrix: Binding<simd_float4x4>,
        mode: InteractiveCameraModifier.Mode,
        transforms: InteractionAxisTransforms = .default
    ) {
        self._cameraMatrix = cameraMatrix
        self.mode = mode
        self.transforms = transforms
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
                guard hasInitializedFromMatrix else { return }
                updateCameraMatrixFromInteraction()
            }
            .onAppear {
                guard !hasInitializedFromMatrix else { return }
                initializeStateFromMatrix()
            }
    }
    
    private func initializeStateFromMatrix() {
        guard let components = cameraMatrix.decompose else {
            return
        }
        
        let rotation = simd_normalize(components.rotation)
        let position = components.translate
        let defaultTarget = SIMD3<Float>(repeating: 0)
        let distance = max(length(defaultTarget - position), 0.01)
        
        interactionState = InteractionState(rotation: rotation, distance: distance, target: defaultTarget)
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
        transforms: InteractionAxisTransforms = .default
    ) -> some View {
        modifier(InteractiveCameraMatrixModifier(cameraMatrix: cameraMatrix, mode: mode, transforms: transforms))
    }
}
