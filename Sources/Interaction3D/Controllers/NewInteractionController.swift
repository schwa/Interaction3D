import GeometryLite3D
import simd
import SwiftUI

// MARK: - Interaction State & Inputs

public struct InteractionState: Equatable, Sendable {
    public var rotation: simd_quatf
    public var distance: Float
    public var target: SIMD3<Float>

    public init(rotation: simd_quatf = simd_quatf(angle: 0, axis: [0, 1, 0]), distance: Float = 5, target: SIMD3<Float> = .zero) {
        self.rotation = rotation
        self.distance = distance
        self.target = target
    }
}

public struct InteractionInput: Equatable, Sendable {
    public var rotation: CGSize
    public var pan: CGSize
    public var zoom: Double

    public init(rotation: CGSize = .zero, pan: CGSize = .zero, zoom: Double = 0) {
        self.rotation = rotation
        self.pan = pan
        self.zoom = zoom
    }
}

// MARK: - Axis Transforms

public struct InteractionAxisTransforms: Sendable {
    public typealias AxisTransform = @Sendable (Double) -> Double
    public typealias PanTransform = @Sendable (SIMD2<Double>) -> SIMD3<Float>

    public var yaw: AxisTransform
    public var pitch: AxisTransform
    public var zoom: AxisTransform
    public var pan: PanTransform

    public init(
        yaw: @escaping AxisTransform = InteractionAxisTransforms.defaultYaw,
        pitch: @escaping AxisTransform = InteractionAxisTransforms.defaultPitch,
        zoom: @escaping AxisTransform = InteractionAxisTransforms.defaultZoom,
        pan: @escaping PanTransform = InteractionAxisTransforms.defaultPan
    ) {
        self.yaw = yaw
        self.pitch = pitch
        self.zoom = zoom
        self.pan = pan
    }
}

public extension InteractionAxisTransforms {
    static let `default` = InteractionAxisTransforms()

    static let defaultYaw: AxisTransform = { delta in
        delta * 0.005
    }

    static let defaultPitch: AxisTransform = { delta in
        delta * 0.005
    }

    static let defaultZoom: AxisTransform = { delta in
        -delta * 0.01
    }

    static let defaultPan: PanTransform = { delta in
        SIMD3<Float>(Float(delta.x * 0.01), Float(-delta.y * 0.01), 0)
    }

    static let arcballDefault = InteractionAxisTransforms(
        yaw: { $0 * 0.01 },
        pitch: { $0 * 0.01 },
        zoom: { -$0 * 0.5 },
        pan: { delta in SIMD3<Float>(Float(delta.x * 0.02), Float(-delta.y * 0.02), 0) }
    )

    static let trackballDefault = InteractionAxisTransforms(
        yaw: { $0 * 0.01 },
        pitch: { $0 * 0.01 },
        zoom: { -$0 * 0.5 },
        pan: { delta in SIMD3<Float>(Float(delta.x * 0.02), Float(-delta.y * 0.02), 0) }
    )


}

// MARK: - Transformers

public protocol InteractionTransformer: TransformerProtocol where Value == InteractionState {
    var input: InteractionInput { get set }
    var transforms: InteractionAxisTransforms { get set }
}

/// Arcball: rotation axes follow the camera's local orientation.
/// Pitch is around the camera's right axis - like grabbing a ball in front of you and rotating it.
public struct ArcBallTransformer: InteractionTransformer {
    public var input: InteractionInput
    public var transforms: InteractionAxisTransforms

    public init(input: InteractionInput = InteractionInput(), transforms: InteractionAxisTransforms = .default) {
        self.input = input
        self.transforms = transforms
    }

    public func apply(to value: InteractionState) -> InteractionState {
        var state = value

        let yawDelta = transforms.yaw(Double(input.rotation.width))
        let pitchDelta = transforms.pitch(Double(input.rotation.height))

        if yawDelta != 0 || pitchDelta != 0 {
            let yawRotation = simd_quatf(angle: Float(-yawDelta), axis: SIMD3<Float>(0, 1, 0))
            let rightAxis = state.rotation.act(SIMD3<Float>(1, 0, 0))
            let pitchRotation = simd_quatf(angle: Float(-pitchDelta), axis: normalize(rightAxis))
            state.rotation = simd_normalize(pitchRotation * yawRotation * state.rotation)
        }

        if input.zoom != 0 {
            let delta = Float(transforms.zoom(input.zoom))
            state.distance = max(0.01, state.distance + delta)
        }

        if input.pan != .zero {
            let delta = SIMD2<Double>(Double(input.pan.width), Double(input.pan.height))
            let offset = transforms.pan(delta)
            let rotatedOffset = state.rotation.act(offset)
            state.target += rotatedOffset
        }

        return state
    }
}

/// Trackball: rotation axes are fixed in world space (yaw around world Y, pitch around world X).
/// Like a physical trackball sitting on a table - dragging left/right always rotates around world up.
public struct TrackballTransformer: InteractionTransformer {
    public var input: InteractionInput
    public var transforms: InteractionAxisTransforms

    public init(input: InteractionInput = InteractionInput(), transforms: InteractionAxisTransforms = .default) {
        self.input = input
        self.transforms = transforms
    }

    public func apply(to value: InteractionState) -> InteractionState {
        var state = value

        let yawDelta = transforms.yaw(Double(input.rotation.width))
        let pitchDelta = transforms.pitch(Double(input.rotation.height))

        if yawDelta != 0 || pitchDelta != 0 {
            let yawRotation = simd_quatf(angle: Float(-yawDelta), axis: SIMD3<Float>(0, 1, 0))
            let pitchRotation = simd_quatf(angle: Float(-pitchDelta), axis: SIMD3<Float>(1, 0, 0))
            state.rotation = simd_normalize(pitchRotation * state.rotation * yawRotation)
        }

        if input.zoom != 0 {
            let delta = Float(transforms.zoom(input.zoom))
            state.distance = max(0.01, state.distance + delta)
        }

        if input.pan != .zero {
            let delta = SIMD2<Double>(Double(input.pan.width), Double(input.pan.height))
            let offset = transforms.pan(delta)
            state.target += offset
        }

        return state
    }
}

// MARK: - Controller

public struct NewInteractionController: ViewModifier {
    public enum Mode {
        case arcball(ArcBallTransformer = ArcBallTransformer())
        case trackball(TrackballTransformer = TrackballTransformer())
    }

    @Binding
    var rotation: simd_quatf

    @Binding
    var distance: Float

    @Binding
    var target: SIMD3<Float>

    var mode: Mode

    @State
    private var rotationTranslation: CGSize = .zero

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

    var rotationTransforms: InteractionAxisTransforms
    var panTransforms: InteractionAxisTransforms

    public init(
        rotation: Binding<simd_quatf>,
        distance: Binding<Float>,
        target: Binding<SIMD3<Float>>,
        mode: Mode = .arcball(),
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
            .modifier(DragGestureModifier(translation: $rotationTranslation))
            .simultaneousGesture(panGesture)
            .simultaneousGesture(zoomGesture)
            .onChange(of: rotationTranslation) { _, _ in
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

        guard rotationDelta != .zero || panDelta != .zero || zoomDeltaChange != 0 else {
            return
        }

        let input = InteractionInput(
            rotation: rotationDelta,
            pan: panDelta,
            zoom: zoomDeltaChange
        )

        let state = InteractionState(rotation: rotation, distance: distance, target: target)

        let updatedState: InteractionState
        switch mode {
        case .arcball(let transformer):
            var transformer = transformer
            transformer.input = input
            transformer.transforms = rotationTransforms
            updatedState = transformer.apply(to: state)
        case .trackball(let transformer):
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
        mode: NewInteractionController.Mode = .arcball(),
        transforms: InteractionAxisTransforms = .default
    ) -> some View {
        modifier(NewInteractionController(rotation: rotation, distance: distance, target: target, mode: mode, transforms: transforms))
    }
}
