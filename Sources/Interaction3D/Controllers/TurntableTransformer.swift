import simd
import SwiftUI

/// Turntable: rotation axes are fixed in world space (yaw around the world up axis, pitch around the camera's
/// horizontal axis). Like orbiting around a target - dragging left/right always rotates around world up.
/// Pitch is clamped to ±90° to prevent flipping over the poles.
///
/// The up axis defaults to +Y. Set `upAxis` for Z-up (or any other) worlds.
public struct TurntableTransformer: InteractionTransformer {
    public var input: InteractionInput
    public var transforms: InteractionAxisTransforms
    public var upAxis: SIMD3<Float>

    public init(input: InteractionInput = InteractionInput(), transforms: InteractionAxisTransforms = .default, upAxis: SIMD3<Float> = [0, 1, 0]) {
        self.input = input
        self.transforms = transforms
        self.upAxis = upAxis
    }

    public func transform(_ value: InteractionState) -> InteractionState {
        var state = value

        let yawDelta = Float(transforms.yaw(Double(input.rotation.width)))
        let pitchDelta = Float(transforms.pitch(Double(input.rotation.height)))

        if yawDelta != 0 || pitchDelta != 0 {
            let (currentYaw, currentPitch) = Self.yawPitch(of: state.rotation, upAxis: upAxis)

            let newYaw = currentYaw - yawDelta

            // Clamp pitch to ±89°
            let maxPitch = Float.pi / 2 - 0.02
            let newPitch = max(-maxPitch, min(maxPitch, currentPitch - pitchDelta))

            state.rotation = Self.rotation(yaw: newYaw, pitch: newPitch, upAxis: upAxis)
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

// MARK: - Yaw and pitch

public extension TurntableTransformer {
    /// Decomposes a camera rotation into yaw around `upAxis` and pitch above the plane perpendicular to it.
    ///
    /// Yaw and pitch describe the camera's forward (-Z) direction. With the default +Y up axis, the identity rotation
    /// (looking down -Z) has yaw and pitch of zero, and positive yaw turns the camera to its left.
    static func yawPitch(of rotation: simd_quatf, upAxis: SIMD3<Float> = [0, 1, 0]) -> (yaw: Float, pitch: Float) {
        let local = basis(upAxis: upAxis).inverse * rotation
        let forward = local.act(SIMD3<Float>(0, 0, -1))
        let pitch = asin(max(-1, min(1, forward.y)))
        let yaw = atan2(-forward.x, -forward.z)
        return (yaw, pitch)
    }

    /// Composes a camera rotation from yaw around `upAxis` and pitch. The inverse of ``yawPitch(of:upAxis:)``.
    static func rotation(yaw: Float, pitch: Float, upAxis: SIMD3<Float> = [0, 1, 0]) -> simd_quatf {
        let yawRotation = simd_quatf(angle: yaw, axis: SIMD3<Float>(0, 1, 0))
        let pitchRotation = simd_quatf(angle: pitch, axis: SIMD3<Float>(1, 0, 0))
        return simd_normalize(basis(upAxis: upAxis) * yawRotation * pitchRotation)
    }

    /// Rotation taking +Y to `upAxis`. Yaw and pitch are computed in the +Y-up frame and mapped through it.
    internal static func basis(upAxis: SIMD3<Float>) -> simd_quatf {
        let yAxis = SIMD3<Float>(0, 1, 0)
        let up = simd_normalize(upAxis)
        if simd_dot(up, yAxis) < -0.9999 {
            return simd_quatf(angle: .pi, axis: SIMD3<Float>(1, 0, 0))
        }
        return simd_quatf(from: yAxis, to: up)
    }
}
