import simd
import SwiftUI

/// Arcball: Based on Ken Shoemake's Graphics Gems IV arcball.
/// Maps mouse positions to a virtual sphere and computes rotation from two points on the sphere.
/// Allows free rotation in any direction - no gimbal lock, no axis constraints.
public struct ArcballTransformer: InteractionTransformer {
    public var input: InteractionInput
    public var transforms: InteractionAxisTransforms

    public init(
        input: InteractionInput = InteractionInput(),
        transforms: InteractionAxisTransforms = .default
    ) {
        self.input = input
        self.transforms = transforms
    }

    public func apply(to value: InteractionState) -> InteractionState {
        var state = value

        // Compute arcball rotation from absolute positions
        if input.startLocation != .zero && input.currentLocation != .zero && input.viewSize != .zero {
            let from = projectToSphere(input.startLocation)
            let to = projectToSphere(input.currentLocation)
            let dragRotation = quaternionFromSpherePoints(from: from, to: to)
            state.rotation = simd_normalize(dragRotation * input.rotationAtDragStart)
        }

        // Zoom (same as turntable)
        if input.zoom != 0 {
            let delta = Float(transforms.zoom(input.zoom))
            state.distance = max(0.01, state.distance + delta)
        }

        // Pan (same as turntable)
        if input.pan != .zero {
            let delta = SIMD2<Double>(Double(input.pan.width), Double(input.pan.height))
            let offset = transforms.pan(delta)
            state.target += offset
        }

        return state
    }
}

// MARK: - Arcball Math

private extension ArcballTransformer {
    /// Project a screen point onto the virtual sphere.
    /// Normalizes coordinates to [-1, 1] with center at (0, 0).
    /// Points inside the sphere radius project onto the hemisphere.
    /// Points outside clamp to the edge (z = 0).
    func projectToSphere(_ point: CGPoint) -> SIMD3<Float> {
        let radius = min(input.viewSize.width, input.viewSize.height) / 2
        let center = CGPoint(x: input.viewSize.width / 2, y: input.viewSize.height / 2)

        // Normalize to [-1, 1]
        var x = Float((point.x - center.x) / radius)
        var y = Float(-(point.y - center.y) / radius) // Flip Y for right-handed coords

        let magSquared = x * x + y * y

        if magSquared > 1.0 {
            // Outside the sphere - project to edge
            let scale = 1.0 / sqrt(magSquared)
            x *= scale
            y *= scale
            return SIMD3<Float>(x, y, 0)
        } else {
            // On the sphere - compute Z
            let z = sqrt(1.0 - magSquared)
            return SIMD3<Float>(x, y, z)
        }
    }

    /// Compute quaternion rotation from two points on the unit sphere.
    /// Uses cross product for rotation axis, dot product relates to angle.
    func quaternionFromSpherePoints(from: SIMD3<Float>, to: SIMD3<Float>) -> simd_quatf {
        let axis = cross(from, to)
        let dot = simd_dot(from, to)
        // Quaternion: (axis.x, axis.y, axis.z, dot) then normalize
        return simd_normalize(simd_quatf(ix: axis.x, iy: axis.y, iz: axis.z, r: dot))
    }
}
