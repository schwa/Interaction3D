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
        let synchronizer = CameraMatrixSynchronizer(target: target)
        self._interactionState = State(initialValue: synchronizer.interactionState(from: cameraMatrix.wrappedValue) ?? InteractionState(target: target))
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
                let newMatrix = synchronizer.cameraMatrix(from: newValue)
                guard !matricesMatch(cameraMatrix, newMatrix) else {
                    return
                }
                cameraMatrix = newMatrix
            }
            .onChange(of: cameraMatrix) { _, newValue in
                let expectedMatrix = synchronizer.cameraMatrix(from: interactionState)
                guard !matricesMatch(newValue, expectedMatrix), let newState = synchronizer.interactionState(from: newValue) else {
                    return
                }
                interactionState = newState
            }
            .onChange(of: target) { _, _ in
                guard let newState = synchronizer.interactionState(from: cameraMatrix) else {
                    return
                }
                interactionState = newState
            }
    }

    private var synchronizer: CameraMatrixSynchronizer {
        CameraMatrixSynchronizer(target: target)
    }

    private func matricesMatch(_ lhs: simd_float4x4, _ rhs: simd_float4x4, tolerance: Float = 0.00001) -> Bool {
        length(lhs.columns.0 - rhs.columns.0) <= tolerance
            && length(lhs.columns.1 - rhs.columns.1) <= tolerance
            && length(lhs.columns.2 - rhs.columns.2) <= tolerance
            && length(lhs.columns.3 - rhs.columns.3) <= tolerance
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
