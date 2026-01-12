import simd
import SwiftUI

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
