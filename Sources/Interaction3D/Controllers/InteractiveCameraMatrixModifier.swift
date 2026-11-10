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
    var zoom: CameraZoomModel
    var distanceRange: ClosedRange<Float>
    var panEnabled: Bool

    // Seeded from cameraMatrix on appear, not in init, because init runs on every parent update.
    @State
    private var interactionState = InteractionState()

    // The state last read from cameraMatrix. It is never written back to cameraMatrix.
    //
    // Why: cameraMatrix and interactionState each update the other. Callers often pass a binding that changes what
    // it is given (SceneSprockets clamps it to camera limits), and matrix -> state -> matrix is not exact in Float.
    // A tolerance check alone can't stop that: far from the origin, Float error is bigger than the tolerance. The
    // two onChange handlers then fire each other forever and the app hangs (this hung SceneView on iOS at launch).
    // Don't remove this guard, and don't add another write-back path without one like it.
    @State
    private var stateFromMatrix: InteractionState?

    public init(
        cameraMatrix: Binding<simd_float4x4>,
        mode: InteractiveCameraModifier.Mode,
        transforms: InteractionAxisTransforms? = nil,
        target: SIMD3<Float> = .zero,
        zoom: CameraZoomModel = .additive,
        distanceRange: ClosedRange<Float> = 0.01...Float.greatestFiniteMagnitude,
        panEnabled: Bool = true
    ) {
        self._cameraMatrix = cameraMatrix
        self.mode = mode
        self.transforms = transforms ?? mode.defaultTransforms
        self.target = target
        self.zoom = zoom
        self.distanceRange = distanceRange
        self.panEnabled = panEnabled
    }

    public func body(content: Content) -> some View {
        content
            .modifier(
                InteractiveCameraModifier(
                    rotation: $interactionState.rotation,
                    distance: $interactionState.distance,
                    target: $interactionState.target,
                    mode: mode,
                    transforms: transforms,
                    zoom: zoom,
                    distanceRange: distanceRange,
                    panEnabled: panEnabled
                )
            )
            .onChange(of: interactionState) { _, newValue in
                // This change came from cameraMatrix; writing it back would restart the loop.
                guard newValue != stateFromMatrix else {
                    return
                }
                let newMatrix = synchronizer.cameraMatrix(from: newValue)
                guard !matricesMatch(cameraMatrix, newMatrix) else {
                    return
                }
                cameraMatrix = newMatrix
            }
            .onChange(of: cameraMatrix, initial: true) { _, newValue in
                let expectedMatrix = synchronizer.cameraMatrix(from: interactionState)
                guard !matricesMatch(newValue, expectedMatrix), let newState = synchronizer.interactionState(from: newValue) else {
                    return
                }
                // Set before interactionState so the handler above knows not to write it back.
                stateFromMatrix = newState
                interactionState = newState
            }
            .onChange(of: target) { _, _ in
                guard let newState = synchronizer.interactionState(from: cameraMatrix) else {
                    return
                }
                stateFromMatrix = newState
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
    /// Orbit camera controls for a camera matrix. `target` is the point the camera orbits.
    func interactiveCamera(
        cameraMatrix: Binding<simd_float4x4>,
        mode: InteractiveCameraModifier.Mode = .turntable(),
        transforms: InteractionAxisTransforms? = nil,
        target: SIMD3<Float> = .zero,
        zoom: CameraZoomModel = .additive,
        distanceRange: ClosedRange<Float> = 0.01...Float.greatestFiniteMagnitude,
        panEnabled: Bool = true
    ) -> some View {
        modifier(
            InteractiveCameraMatrixModifier(
                cameraMatrix: cameraMatrix,
                mode: mode,
                transforms: transforms,
                target: target,
                zoom: zoom,
                distanceRange: distanceRange,
                panEnabled: panEnabled
            )
        )
    }
}
