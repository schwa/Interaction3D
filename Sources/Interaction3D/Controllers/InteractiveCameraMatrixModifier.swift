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
    private var isUpdatingCameraMatrix = false

    @State
    private var isUpdatingStateFromMatrix = false

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
            .onChange(of: cameraMatrix, initial: true) { _, newValue in
                synchronizeState(from: newValue)
            }
            .modifier(
                InteractiveCameraModifier(
                    rotation: Binding(
                        get: { interactionState.rotation },
                        set: { interactionState.rotation = $0 }
                    ),
                    distance: Binding(
                        get: { interactionState.distance },
                        set: { interactionState.distance = max($0, 0.01) }
                    ),
                    target: Binding(
                        get: { interactionState.target },
                        set: { interactionState.target = $0 }
                    ),
                    mode: mode,
                    transforms: transforms
                )
            )
            .onChange(of: interactionState) { _, newValue in
                updateCameraMatrix(from: newValue)
            }
    }

    private func synchronizeState(from matrix: simd_float4x4) {
        guard !isUpdatingCameraMatrix else {
            return
        }

        isUpdatingStateFromMatrix = true
        defer { isUpdatingStateFromMatrix = false }

        let rotationMatrix = simd_float3x3(
            SIMD3<Float>(matrix.columns.0.x, matrix.columns.0.y, matrix.columns.0.z),
            SIMD3<Float>(matrix.columns.1.x, matrix.columns.1.y, matrix.columns.1.z),
            SIMD3<Float>(matrix.columns.2.x, matrix.columns.2.y, matrix.columns.2.z)
        )
        let rotation = simd_quaternion(rotationMatrix)
        interactionState.rotation = simd_normalize(rotation)

        let position = matrix.columns.3.xyz

        if !hasInitializedFromMatrix {
            let defaultTarget = SIMD3<Float>(repeating: 0)
            let distance = max(length(defaultTarget - position), 0.01)
            interactionState.distance = distance
            interactionState.target = defaultTarget
            hasInitializedFromMatrix = true
        }
        else {
            let forward = interactionState.rotation.act(SIMD3<Float>(0, 0, -1))
            let target = position + forward * interactionState.distance
            interactionState.target = target
        }
    }

    private func updateCameraMatrix(from state: InteractionState) {
        guard !isUpdatingStateFromMatrix else {
            return
        }

        isUpdatingCameraMatrix = true
        defer { isUpdatingCameraMatrix = false }

        let forward = state.rotation.act(SIMD3<Float>(0, 0, -1))
        let right = state.rotation.act(SIMD3<Float>(1, 0, 0))
        let up = state.rotation.act(SIMD3<Float>(0, 1, 0))
        let position = state.target - forward * state.distance

        let newMatrix = simd_float4x4(
            SIMD4<Float>(right.x, right.y, right.z, 0),
            SIMD4<Float>(up.x, up.y, up.z, 0),
            SIMD4<Float>(-forward.x, -forward.y, -forward.z, 0),
            SIMD4<Float>(position.x, position.y, position.z, 1)
        )

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
