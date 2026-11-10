import Observation
import simd

@MainActor
@Observable
final class MovementController {
    var linearVelocity: SIMD3<Float> = .zero
    var angularVelocity: SIMD3<Float> = .zero
    var transform: simd_float4x4 = matrix_identity_float4x4

    init() {
        // This line intentionally left blank
    }
}
