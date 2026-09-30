import SwiftUI

public extension View {
    /// Turntable orbit controls for a camera stored as yaw and pitch angles instead of a rotation.
    ///
    /// Yaw and pitch are the camera's forward direction, as in ``TurntableTransformer/yawPitch(of:upAxis:)``: positive
    /// yaw turns the camera to its left, positive pitch tilts it up. Dragging orbits the camera around its target;
    /// pitch is clamped to `pitchRange`. Scroll and magnify zoom `distance`, and Command-drag pans `target` unless
    /// it is `nil`.
    ///
    /// Use ``TurntableTransformer/rotation(yaw:pitch:upAxis:)`` to turn the angles into a rotation.
    func interactiveCamera<Scalar: BinaryFloatingPoint & SIMDScalar>(
        yaw: Binding<Angle>,
        pitch: Binding<Angle>,
        distance: Binding<Scalar>,
        target: Binding<SIMD3<Scalar>>? = nil,
        pitchRange: ClosedRange<Angle> = .degrees(-89)...(.degrees(89)),
        transforms: InteractionAxisTransforms = .turntableDefault,
        zoom: CameraZoomModel = .additive,
        distanceRange: ClosedRange<Scalar> = 0.01...Scalar.greatestFiniteMagnitude
    ) -> some View {
        modifier(
            YawPitchDragModifier(
                yaw: yaw,
                pitch: pitch,
                pitchRange: pitchRange,
                yawDelta: { -transforms.yaw($0) },
                pitchDelta: { -transforms.pitch($0) }
            )
        )
        #if os(macOS)
        .modifier(OptionalCameraPanModifier(target: target, transforms: transforms))
        #endif
        .modifier(CameraZoomModifier(distance: distance, transforms: transforms, zoom: zoom, distanceRange: distanceRange))
    }

    /// Look-around controls for a camera at a fixed position: dragging changes only where it looks.
    ///
    /// Dragging moves the scene with the pointer, like grabbing the sky: drag right to turn left, drag down to look
    /// up. `yaw` and `pitch` use the same convention as ``interactiveCamera(yaw:pitch:distance:target:pitchRange:transforms:zoom:distanceRange:)``.
    /// `transforms.yaw` and `transforms.pitch` convert points dragged to radians.
    func interactiveLook(
        yaw: Binding<Angle>,
        pitch: Binding<Angle>,
        pitchRange: ClosedRange<Angle> = .degrees(-89)...(.degrees(89)),
        transforms: InteractionAxisTransforms = .default
    ) -> some View {
        modifier(
            YawPitchDragModifier(
                yaw: yaw,
                pitch: pitch,
                pitchRange: pitchRange,
                yawDelta: { transforms.yaw($0) },
                pitchDelta: { transforms.pitch($0) }
            )
        )
    }
}

/// Applies drag deltas to yaw and pitch angles directly, with momentum and a pitch clamp.
struct YawPitchDragModifier: ViewModifier {
    @Binding var yaw: Angle
    @Binding var pitch: Angle
    var pitchRange: ClosedRange<Angle>
    /// Radians of yaw and pitch for points dragged horizontally and vertically.
    var yawDelta: (Double) -> Double
    var pitchDelta: (Double) -> Double

    @State private var session = YawPitchDragSession()

    func body(content: Content) -> some View {
        content.modifier(
            CoreDragModifier(modifiers: [], minimumDistance: 10, momentum: true) { translation in
                let delta = session.delta(for: translation)
                let angles = YawPitchDragSession.apply(
                    delta: delta,
                    to: (yaw, pitch),
                    pitchRange: pitchRange,
                    yawDelta: yawDelta,
                    pitchDelta: pitchDelta
                )
                yaw = angles.yaw
                pitch = angles.pitch
            } onEnded: {
                session.end()
            }
        )
    }
}

/// Turns cumulative drag translations into per-update deltas.
struct YawPitchDragSession {
    private var lastTranslation: CGSize = .zero

    mutating func delta(for translation: CGSize) -> CGSize {
        defer { lastTranslation = translation }
        return CGSize(width: translation.width - lastTranslation.width, height: translation.height - lastTranslation.height)
    }

    mutating func end() {
        lastTranslation = .zero
    }

    static func apply(
        delta: CGSize,
        to angles: (yaw: Angle, pitch: Angle),
        pitchRange: ClosedRange<Angle>,
        yawDelta: (Double) -> Double,
        pitchDelta: (Double) -> Double
    ) -> (yaw: Angle, pitch: Angle) {
        let yaw = angles.yaw + .radians(yawDelta(delta.width))
        let pitch = angles.pitch + .radians(pitchDelta(delta.height))
        return (yaw, min(max(pitch, pitchRange.lowerBound), pitchRange.upperBound))
    }
}
