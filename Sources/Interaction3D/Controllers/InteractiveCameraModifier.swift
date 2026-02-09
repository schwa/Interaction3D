import GeometryLite3D
import simd
import SwiftUI

// MARK: - Interactive Camera Modifier

public struct InteractiveCameraModifier: ViewModifier {
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
            #if os(macOS)
            .simultaneousGesture(panGesture)
            #endif
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

    #if os(macOS)
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
    #endif

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

// MARK: - View Extension

public extension View {
    func interactiveCamera(
        rotation: Binding<simd_quatf>,
        distance: Binding<Float>,
        target: Binding<SIMD3<Float>>,
        mode: InteractiveCameraModifier.Mode = .turntable(),
        transforms: InteractionAxisTransforms = .default
    ) -> some View {
        modifier(InteractiveCameraModifier(rotation: rotation, distance: distance, target: target, mode: mode, transforms: transforms))
    }
}
