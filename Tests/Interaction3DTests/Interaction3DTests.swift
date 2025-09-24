@testable import Interaction3D
import simd
import Testing

@Test func resetClearsFPVControllerState() {
    var controller = FPVController()
    controller.movementController.linearVelocity = SIMD3<Float>(1, 2, 3)
    controller.movementController.angularVelocity = SIMD3<Float>(4, 5, 6)

    controller.process(event: .controllerState(move: SIMD2<Float>(1, 0), look: .zero, altitude: 0))
    controller.reset()

    #expect(controller.movementController.linearVelocity == .zero)
    #expect(controller.movementController.angularVelocity == .zero)
}
