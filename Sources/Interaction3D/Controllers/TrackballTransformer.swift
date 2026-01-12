import simd
import SwiftUI

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
