import GeometryLite3D
import simd
import SwiftUI

public struct TurntableCameraController: ViewModifier {
    @State private var constraint = TurntableControllerConstraint(target: .zero, radius: 10)

    @Binding
    var transform: simd_float4x4

    public init(transform: Binding<simd_float4x4>) {
        self._transform = transform
        // TODO: #132 compute pitch yaw from transform
    }

    public func body(content: Content) -> some View {
        // Convert DraggableValueBehavior to transform closures
        let pitchTransform: (Angle) -> Angle = { angle in
            switch constraint.pitchBehavior {
            case .linear:
                return angle
            case .clamping(let range):
                return Angle(degrees: angle.degrees.clamped(to: range))
            case .wrapping(let range):
                let rangeWidth = range.upperBound - range.lowerBound
                var normalized = (angle.degrees - range.lowerBound).truncatingRemainder(dividingBy: rangeWidth)
                if normalized < 0 {
                    normalized += rangeWidth
                }
                return Angle(degrees: range.lowerBound + normalized)
            }
        }

        let yawTransform: (Angle) -> Angle = { angle in
            switch constraint.yawBehavior {
            case .linear:
                return angle
            case .clamping(let range):
                return Angle(degrees: angle.degrees.clamped(to: range))
            case .wrapping(let range):
                let rangeWidth = range.upperBound - range.lowerBound
                var normalized = (angle.degrees - range.lowerBound).truncatingRemainder(dividingBy: rangeWidth)
                if normalized < 0 {
                    normalized += rangeWidth
                }
                return Angle(degrees: range.lowerBound + normalized)
            }
        }

        let radiusTransform: (Double) -> Double = { value in
            // DistanceGestureModifier works differently - it multiplies by (1.0 + transformedDelta)
            // So we just return the delta as-is for linear behavior
            return value
        }

        content
            .modifier(PitchYawDragViewModifier(
                pitch: $constraint.pitch,
                yaw: $constraint.yaw,
                pitchTransform: pitchTransform,
                yawTransform: yawTransform
            ))
            .modifier(DistanceGestureModifier(
                distance: Binding(
                    get: { Double(constraint.radius) },
                    set: { constraint.radius = Float($0) }
                ),
                distanceTransform: radiusTransform
            ))
            .onChange(of: constraint, initial: true) {
                transform = constraint.transform
            }
    }
}

// MARK: -

public struct TurntableControllerConstraint: Equatable {
    public var target: SIMD3<Float>
    public var radius: Float
    public var pitch: Angle = .zero
    public var yaw: Angle = .zero
    public var towards: Bool = true
    public var pitchBehavior: DraggableValueBehavior
    public var yawBehavior: DraggableValueBehavior

    public init(target: SIMD3<Float> = .zero, radius: Float, pitchBehavior: DraggableValueBehavior = .clamping(-90...90), yawBehavior: DraggableValueBehavior = .linear) {
        self.target = target
        self.radius = radius
        self.pitchBehavior = pitchBehavior
        self.yawBehavior = yawBehavior
    }

    public var transform: simd_float4x4 {
        // Convert SwiftUI Angles to radians:
        let rotation =
            simd_quatf(angle: Float(yaw.radians), axis: [0, 1, 0])
            * simd_quatf(angle: Float(pitch.radians), axis: [1, 0, 0])
        let localPos = SIMD4<Float>(0, 0, radius, 1)
        let rotatedOffset = simd_float4x4(rotation) * localPos
        let position = target + rotatedOffset.xyz

        let directionToTarget = target - position
        let forward: SIMD3<Float>

        if simd_length_squared(directionToTarget) > Float.leastNonzeroMagnitude {
            forward = towards ? normalize(directionToTarget) : normalize(-directionToTarget)
        } else {
            let baseForward = rotation.act(SIMD3<Float>(0, 0, -1))
            forward = towards ? baseForward : -baseForward
        }

        let lookTarget = position + forward
        return LookAt(position: position, target: lookTarget, up: [0, 1, 0]).cameraMatrix
    }
}

