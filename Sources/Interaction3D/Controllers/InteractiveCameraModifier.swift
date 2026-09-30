import simd
import SwiftUI

public struct InteractiveCameraModifier: ViewModifier {
    public enum Mode {
        case turntable(TurntableTransformer = TurntableTransformer())
        case arcball(ArcballTransformer = ArcballTransformer())

        /// The transforms tuned for this mode, used when the caller does not pass any.
        public var defaultTransforms: InteractionAxisTransforms {
            switch self {
            case .turntable:
                .turntableDefault

            case .arcball:
                .default
            }
        }
    }

    var controls: CameraControlsModifier<Float>

    /// - Parameters:
    ///   - zoom: How scroll and magnify change `distance`. Use `.multiplicative` for scenes whose scale spans orders
    ///     of magnitude.
    ///   - distanceRange: Limits for `distance`. Defaults to `0.01...`.
    ///   - panEnabled: Whether Command-drag pans `target`.
    public init(
        rotation: Binding<simd_quatf>,
        distance: Binding<Float>,
        target: Binding<SIMD3<Float>>,
        mode: Mode = .turntable(),
        transforms: InteractionAxisTransforms? = nil,
        zoom: CameraZoomModel = .additive,
        distanceRange: ClosedRange<Float> = 0.01...Float.greatestFiniteMagnitude,
        panEnabled: Bool = true
    ) {
        controls = CameraControlsModifier(
            rotation: rotation,
            distance: distance,
            target: panEnabled ? target : nil,
            mode: mode,
            transforms: transforms ?? mode.defaultTransforms,
            zoom: zoom,
            distanceRange: distanceRange
        )
    }

    public func body(content: Content) -> some View {
        content.modifier(controls)
    }
}

/// Rotation, pan and zoom gestures for any floating-point distance and target type.
struct CameraControlsModifier<Scalar: BinaryFloatingPoint & SIMDScalar>: ViewModifier {
    @Binding var rotation: simd_quatf
    @Binding var distance: Scalar
    var target: Binding<SIMD3<Scalar>>?

    var mode: InteractiveCameraModifier.Mode
    var transforms: InteractionAxisTransforms
    var zoom: CameraZoomModel
    var distanceRange: ClosedRange<Scalar>

    init(
        rotation: Binding<simd_quatf>,
        distance: Binding<Scalar>,
        target: Binding<SIMD3<Scalar>>?,
        mode: InteractiveCameraModifier.Mode,
        transforms: InteractionAxisTransforms,
        zoom: CameraZoomModel,
        distanceRange: ClosedRange<Scalar>
    ) {
        self._rotation = rotation
        self._distance = distance
        self.target = target
        self.mode = mode
        self.transforms = transforms
        self.zoom = zoom
        self.distanceRange = distanceRange
    }

    func body(content: Content) -> some View {
        content
            .modifier(CameraRotationModifier(rotation: $rotation, mode: mode, transforms: transforms))
            #if os(macOS)
            .modifier(OptionalCameraPanModifier(target: target, transforms: transforms))
            #endif
            .modifier(CameraZoomModifier(distance: $distance, transforms: transforms, zoom: zoom, distanceRange: distanceRange))
    }
}

struct CameraPanTransformer: Transformer {
    var transforms: InteractionAxisTransforms

    func transform(_ input: CGSize) -> SIMD3<Float> {
        transforms.pan(SIMD2(Double(input.width), Double(input.height)))
    }
}

struct OptionalCameraPanModifier<Scalar: BinaryFloatingPoint & SIMDScalar>: ViewModifier {
    var target: Binding<SIMD3<Scalar>>?
    var transforms: InteractionAxisTransforms

    func body(content: Content) -> some View {
        if let target {
            content.modifier(CameraPanModifier(target: target, transforms: transforms))
        } else {
            content
        }
    }
}

private struct CameraPanModifier<Scalar: BinaryFloatingPoint & SIMDScalar>: ViewModifier {
    @Binding var target: SIMD3<Scalar>
    var transforms: InteractionAxisTransforms

    @State private var targetAtDragStart: SIMD3<Scalar>?

    func body(content: Content) -> some View {
        content.modifier(
            CoreDragModifier(modifiers: .command, minimumDistance: 10, momentum: false) { translation in
                let startTarget = targetAtDragStart ?? target
                targetAtDragStart = startTarget
                target = startTarget + SIMD3<Scalar>(CameraPanTransformer(transforms: transforms).transform(translation))
            } onEnded: {
                targetAtDragStart = nil
            }
        )
    }
}

struct CameraZoomTransformer: Transformer {
    var transforms: InteractionAxisTransforms
    var magnitude: Double

    func transform(_ input: Double) -> Float {
        Float(transforms.zoom(input * magnitude))
    }
}

struct CameraRotationSession {
    private(set) var rotationAtDragStart: simd_quatf?
    private var lastTranslation: CGSize = .zero

    mutating func input(
        for drag: CoreDragValue,
        rotation: simd_quatf,
        mode: InteractiveCameraModifier.Mode,
        viewSize: CGSize
    ) -> InteractionInput {
        let startRotation = rotationAtDragStart ?? rotation
        rotationAtDragStart = startRotation
        defer { lastTranslation = drag.translation }

        switch mode {
        case .turntable:
            return InteractionInput(
                rotation: drag.translation - lastTranslation,
                rotationAtDragStart: startRotation
            )
        case .arcball:
            return InteractionInput(
                startLocation: drag.startLocation,
                currentLocation: drag.currentLocation,
                viewSize: viewSize,
                rotationAtDragStart: startRotation
            )
        }
    }

    mutating func end() {
        rotationAtDragStart = nil
        lastTranslation = .zero
    }
}

private struct CameraRotationModifier: ViewModifier {
    @Binding var rotation: simd_quatf

    var mode: InteractiveCameraModifier.Mode
    var transforms: InteractionAxisTransforms

    @State private var viewSize: CGSize = .zero
    @State private var session = CameraRotationSession()

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGSize.self, of: \.size) { viewSize = $0 }
            .modifier(
                CoreDragModifier(
                    modifiers: [],
                    minimumDistance: 10,
                    momentum: true,
                    onValueChanged: updateRotation,
                    onEnded: endRotation
                )
            )
    }

    private func updateRotation(_ drag: CoreDragValue) {
        let input = session.input(for: drag, rotation: rotation, mode: mode, viewSize: viewSize)
        rotation = transformedRotation(input: input)
    }

    private func transformedRotation(input: InteractionInput) -> simd_quatf {
        let state = InteractionState(rotation: rotation)
        switch mode {
        case .turntable(var transformer):
            transformer.input = input
            transformer.transforms = transforms
            return transformer.transform(state).rotation
        case .arcball(var transformer):
            transformer.input = input
            transformer.transforms = transforms
            return transformer.transform(state).rotation
        }
    }

    private func endRotation() {
        session.end()
    }
}

public extension View {
    /// Orbit camera controls: drag rotates, scroll and magnify zoom, Command-drag pans the target.
    ///
    /// `distance` and `target` can be `Float` or `Double`; use `Double` for large-scale scenes. Pass `nil` for
    /// `target` to disable pan, for example when orbiting a fixed object.
    func interactiveCamera<Scalar: BinaryFloatingPoint & SIMDScalar>(
        rotation: Binding<simd_quatf>,
        distance: Binding<Scalar>,
        target: Binding<SIMD3<Scalar>>?,
        mode: InteractiveCameraModifier.Mode = .turntable(),
        transforms: InteractionAxisTransforms? = nil,
        zoom: CameraZoomModel = .additive,
        distanceRange: ClosedRange<Scalar> = 0.01...Scalar.greatestFiniteMagnitude
    ) -> some View {
        modifier(
            CameraControlsModifier(
                rotation: rotation,
                distance: distance,
                target: target,
                mode: mode,
                transforms: transforms ?? mode.defaultTransforms,
                zoom: zoom,
                distanceRange: distanceRange
            )
        )
    }
}

private extension CGSize {
    static func - (lhs: Self, rhs: Self) -> Self {
        CGSize(width: lhs.width - rhs.width, height: lhs.height - rhs.height)
    }
}
