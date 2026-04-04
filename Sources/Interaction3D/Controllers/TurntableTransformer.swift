import simd
import SwiftUI

/// Turntable: rotation axes are fixed in world space (yaw around world Y, pitch around world X).
/// Like orbiting around a target - dragging left/right always rotates around world up.
/// Pitch is clamped to ±90° to prevent flipping over the poles.
public struct TurntableTransformer: InteractionTransformer {
    public var input: InteractionInput
    public var transforms: InteractionAxisTransforms

    public init(input: InteractionInput = InteractionInput(), transforms: InteractionAxisTransforms = .default) {
        self.input = input
        self.transforms = transforms
    }

    public func apply(to value: InteractionState) -> InteractionState {
        var state = value

        let yawDelta = Float(transforms.yaw(Double(input.rotation.width)))
        let pitchDelta = Float(transforms.pitch(Double(input.rotation.height)))

        if yawDelta != 0 || pitchDelta != 0 {
            // Decompose current rotation into yaw and pitch
            let (currentYaw, currentPitch) = decomposeYawPitch(state.rotation)

            // Apply deltas
            let newYaw = currentYaw - yawDelta

            // Clamp pitch to ±89°
            let maxPitch = Float.pi / 2 - 0.02
            let newPitch = max(-maxPitch, min(maxPitch, currentPitch - pitchDelta))

            // Reconstruct rotation from yaw and pitch
            state.rotation = composeYawPitch(yaw: newYaw, pitch: newPitch)
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

    /// Decompose a quaternion into yaw (around Y) and pitch (around X) angles
    private func decomposeYawPitch(_ q: simd_quatf) -> (yaw: Float, pitch: Float) {
        // Get the forward vector
        let forward = q.act(SIMD3<Float>(0, 0, -1))

        // Pitch is the angle from the horizontal plane
        let pitch = asin(clamp(forward.y, min: -1, max: 1))

        // Yaw is the angle in the XZ plane
        // Use -forward.z so that identity (forward = 0,0,-1) gives yaw = 0
        let yaw = atan2(-forward.x, -forward.z)

        return (yaw, pitch)
    }

    /// Compose a quaternion from yaw (around Y) and pitch (around X) angles
    private func composeYawPitch(yaw: Float, pitch: Float) -> simd_quatf {
        let yawQ = simd_quatf(angle: yaw, axis: SIMD3<Float>(0, 1, 0))
        let pitchQ = simd_quatf(angle: pitch, axis: SIMD3<Float>(1, 0, 0))
        return simd_normalize(yawQ * pitchQ)
    }

    private func clamp(_ value: Float, min minVal: Float, max maxVal: Float) -> Float {
        max(minVal, min(maxVal, value))
    }
}
