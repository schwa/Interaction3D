import simd
import SwiftUI

public struct InteractiveCameraModifier: ViewModifier {
    public enum Mode {
        case turntable(TurntableTransformer = TurntableTransformer())
        case arcball(ArcballTransformer = ArcballTransformer())
    }

    @Binding var rotation: simd_quatf
    @Binding var distance: Float
    @Binding var target: SIMD3<Float>

    var mode: Mode
    var transforms: InteractionAxisTransforms

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
        self.transforms = transforms
    }

    public func body(content: Content) -> some View {
        content
            .modifier(CameraRotationModifier(rotation: $rotation, mode: mode, transforms: transforms))
            #if os(macOS)
            .modifier(CameraPanModifier(target: $target, transforms: transforms))
            .transformedScrollGesture(
                transformer: CameraZoomTransformer(transforms: transforms, magnitude: 1),
                writes: clampedDistance
            )
            #endif
            .transformedMagnifyGesture(
                transformer: CameraZoomTransformer(transforms: transforms, magnitude: 100),
                writes: clampedDistance
            )
    }

    private var clampedDistance: Binding<Float> {
        Binding {
            distance
        } set: { newDistance in
            distance = max(0.01, newDistance)
        }
    }
}

struct CameraPanTransformer: Transformer {
    var transforms: InteractionAxisTransforms

    func transform(_ input: CGSize) -> SIMD3<Float> {
        transforms.pan(SIMD2(Double(input.width), Double(input.height)))
    }
}

private struct CameraPanModifier: ViewModifier {
    @Binding var target: SIMD3<Float>
    var transforms: InteractionAxisTransforms

    @State private var targetAtDragStart: SIMD3<Float>?

    func body(content: Content) -> some View {
        content.modifier(
            CoreDragModifier(modifiers: .command, minimumDistance: 10, momentum: false) { translation in
                let startTarget = targetAtDragStart ?? target
                targetAtDragStart = startTarget
                target = startTarget + CameraPanTransformer(transforms: transforms).transform(translation)
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

private extension CGSize {
    static func - (lhs: Self, rhs: Self) -> Self {
        CGSize(width: lhs.width - rhs.width, height: lhs.height - rhs.height)
    }
}
