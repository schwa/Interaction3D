import GeometryLite3D
import simd
import SwiftUI

// MARK: - Controller

public struct NewInteractionController: ViewModifier {
    public enum Mode {
        case turntable(TurntableTransformer = TurntableTransformer())
        case arcball(ArcballTransformer = ArcballTransformer())
    }

    @Binding
    var rotation: simd_quatf

    @Binding
    var distance: Float

    @Binding
    var target: SIMD3<Float>

    var mode: Mode

    @State
    private var dragState: DragGestureModifier.DragState = .zero

    @State
    private var panTranslation: CGSize = .zero

    @State
    private var zoomDelta: Double = 0

    @State
    private var lastRotationTranslation: CGSize = .zero

    @State
    private var lastPanTranslation: CGSize = .zero

    @State
    private var lastZoomDelta: Double = 0

    @State
    private var viewSize: CGSize = .zero

    @State
    private var rotationAtDragStart: simd_quatf = simd_quatf(angle: 0, axis: [0, 1, 0])

    var rotationTransforms: InteractionAxisTransforms
    var panTransforms: InteractionAxisTransforms

    public init(
        rotation: Binding<simd_quatf>,
        distance: Binding<Float>,
        target: Binding<SIMD3<Float>>,
        mode: Mode = .turntable(),
        transforms: InteractionAxisTransforms = .default
    ) {
        self._rotation = rotation
        self._distance = distance
        self._target = target
        self.mode = mode
        self.rotationTransforms = transforms
        self.panTransforms = InteractionAxisTransforms(
            yaw: transforms.yaw,
            pitch: transforms.pitch,
            zoom: transforms.zoom,
            pan: transforms.pan
        )
    }

    public func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGSize.self, of: \.size) { viewSize = $0 }
            .modifier(DragGestureModifier(state: $dragState))
            .simultaneousGesture(panGesture)
            .simultaneousGesture(zoomGesture)
            .onChange(of: dragState) { oldValue, newValue in
                // Capture rotation at drag start
                if oldValue.startLocation == .zero && newValue.startLocation != .zero {
                    rotationAtDragStart = rotation
                }
                applyInteraction()
            }
            .onChange(of: panTranslation) { _, _ in
                applyInteraction()
            }
            .onChange(of: zoomDelta) { _, _ in
                applyInteraction()
            }
    }

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .modifiers(.command)
            .onChanged { value in
                panTranslation = value.translation
            }
            .onEnded { _ in
                lastPanTranslation = .zero
                panTranslation = .zero
            }
    }

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                zoomDelta = Double(value.magnification - 1)
            }
            .onEnded { _ in
                lastZoomDelta = 0
                zoomDelta = 0
            }
    }

    private func applyInteraction() {
        let rotationTranslation = dragState.translation

        var rotationDelta = CGSize(
            width: rotationTranslation.width - lastRotationTranslation.width,
            height: rotationTranslation.height - lastRotationTranslation.height
        )

        if rotationTranslation == .zero && lastRotationTranslation != .zero {
            rotationDelta = .zero
        }

        var panDelta = CGSize(
            width: panTranslation.width - lastPanTranslation.width,
            height: panTranslation.height - lastPanTranslation.height
        )

        if panTranslation == .zero && lastPanTranslation != .zero {
            panDelta = .zero
        }

        var zoomDeltaChange = zoomDelta - lastZoomDelta

        if zoomDelta == 0 && lastZoomDelta != 0 {
            zoomDeltaChange = 0
        }

        lastRotationTranslation = rotationTranslation
        lastPanTranslation = panTranslation
        lastZoomDelta = zoomDelta

        let hasRotationInput = rotationDelta != .zero || dragState.startLocation != .zero
        guard hasRotationInput || panDelta != .zero || zoomDeltaChange != 0 else {
            return
        }

        let input = InteractionInput(
            rotation: rotationDelta,
            pan: panDelta,
            zoom: zoomDeltaChange,
            startLocation: dragState.startLocation,
            currentLocation: dragState.currentLocation,
            viewSize: viewSize,
            rotationAtDragStart: rotationAtDragStart
        )

        let state = InteractionState(rotation: rotation, distance: distance, target: target)

        let updatedState: InteractionState
        switch mode {
        case .turntable(let transformer):
            var transformer = transformer
            transformer.input = input
            transformer.transforms = rotationTransforms
            updatedState = transformer.apply(to: state)
        case .arcball(let transformer):
            var transformer = transformer
            transformer.input = input
            transformer.transforms = rotationTransforms
            updatedState = transformer.apply(to: state)
        }

        rotation = updatedState.rotation
        distance = updatedState.distance
        target = updatedState.target
    }
}

public extension View {
    func newInteractionController(
        rotation: Binding<simd_quatf>,
        distance: Binding<Float>,
        target: Binding<SIMD3<Float>>,
        mode: NewInteractionController.Mode = .turntable(),
        transforms: InteractionAxisTransforms = .default
    ) -> some View {
        modifier(NewInteractionController(rotation: rotation, distance: distance, target: target, mode: mode, transforms: transforms))
    }

    func newInteractionController(
        cameraMatrix: Binding<simd_float4x4>,
        mode: NewInteractionController.Mode = .turntable(),
        transforms: InteractionAxisTransforms = .default
    ) -> some View {
        modifier(CameraMatrixInteractionController(cameraMatrix: cameraMatrix, mode: mode, transforms: transforms))
    }
}

// MARK: - Camera Matrix Adapter

/// Adapter that bridges between simd_float4x4 camera matrix and the rotation/distance/target state
struct CameraMatrixInteractionController: ViewModifier {
    @Binding
    var cameraMatrix: simd_float4x4

    var mode: NewInteractionController.Mode
    var transforms: InteractionAxisTransforms

    @State
    private var interactionState = InteractionState()

    @State
    private var isUpdatingCameraMatrix = false

    @State
    private var isUpdatingStateFromMatrix = false

    @State
    private var hasInitializedFromMatrix = false

    init(
        cameraMatrix: Binding<simd_float4x4>,
        mode: NewInteractionController.Mode,
        transforms: InteractionAxisTransforms = .default
    ) {
        self._cameraMatrix = cameraMatrix
        self.mode = mode
        self.transforms = transforms
    }

    func body(content: Content) -> some View {
        content
            .onChange(of: cameraMatrix, initial: true) { _, newValue in
                synchronizeState(from: newValue)
            }
            .modifier(
                NewInteractionController(
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
