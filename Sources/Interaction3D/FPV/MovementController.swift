import Observation
import simd

@Observable
public final class MovementController {
    public var linearVelocity: SIMD3<Float> = .zero
    public var angularVelocity: SIMD3<Float> = .zero
    public var transform: simd_float4x4 = matrix_identity_float4x4

    public init() {
        // This line intentionally left blank
    }
}
