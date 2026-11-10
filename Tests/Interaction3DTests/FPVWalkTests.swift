@testable import Interaction3D
import simd
import Testing

@MainActor
private func walkingController(gravity: Float = 10, flightToggle: Bool = false, ground: Float = 0) -> FPVMovementController {
    var controller = FPVMovementController()
    controller.walkSettings = FPVWalkSettings(gravity: gravity, eyeHeight: 1.5, jumpSpeed: 5, isFlightToggleEnabled: flightToggle)
    controller.hooks.groundHeight = { _ in ground }
    return controller
}

@MainActor
private func height(_ controller: FPVMovementController) -> Float {
    controller.movementController.transform.columns.3.y
}

@MainActor
private func step(_ controller: inout FPVMovementController, seconds: Float) {
    for _ in 0..<Int(seconds * 100) {
        controller.update(deltaTime: 0.01)
    }
}

@MainActor
@Test func fpvWalkFallsAndLandsAtEyeHeight() {
    var controller = walkingController()
    controller.setPose(simd_float4x4(translation: [0, 10, 0]))
    step(&controller, seconds: 3)
    #expect(abs(height(controller) - 1.5) < 0.001)
    #expect(controller.motionState.isOnGround)
}

@MainActor
@Test func fpvWalkJumpsOnlyFromGround() {
    var controller = walkingController()
    step(&controller, seconds: 1)
    controller.process(event: .jumpState(isPressed: true))
    controller.process(event: .jumpState(isPressed: false))
    step(&controller, seconds: 0.2)
    #expect(height(controller) > 1.5)
    #expect(!controller.motionState.isOnGround)
    step(&controller, seconds: 2)
    #expect(abs(height(controller) - 1.5) < 0.001)
}

@MainActor
@Test func fpvWalkDoubleTapTogglesFlight() {
    var controller = walkingController(flightToggle: true)
    step(&controller, seconds: 1)
    controller.process(event: .jumpState(isPressed: true))
    controller.process(event: .jumpState(isPressed: false))
    step(&controller, seconds: 0.1)
    controller.process(event: .jumpState(isPressed: true))
    controller.process(event: .jumpState(isPressed: false))
    #expect(controller.motionState.isFlying)
    let flyingHeight = height(controller)
    step(&controller, seconds: 1)
    // No gravity while flying.
    #expect(abs(height(controller) - flyingHeight) < 0.001)
    // Descending to the ground ends flight.
    controller.process(event: .keyboardState(move: .zero, look: .zero, altitude: -1, isFast: false))
    step(&controller, seconds: 1)
    #expect(!controller.motionState.isFlying)
    #expect(abs(height(controller) - 1.5) < 0.001)
}

@MainActor
@Test func fpvWalkIgnoresAltitudeKeysOnGround() {
    var controller = walkingController()
    step(&controller, seconds: 1)
    controller.process(event: .keyboardState(move: .zero, look: .zero, altitude: 1, isFast: false))
    step(&controller, seconds: 1)
    #expect(abs(height(controller) - 1.5) < 0.001)
}

@MainActor
@Test func fpvWalkWithoutGravityFollowsGround() {
    var controller = walkingController(gravity: 0, ground: 2)
    step(&controller, seconds: 3)
    #expect(abs(height(controller) - 3.5) < 0.01)
}

@MainActor
@Test func fpvCanMoveBlocksAndSlides() {
    var controller = FPVMovementController()
    // A wall at z = -1: anything past it is blocked.
    controller.hooks.canMove = { _, to in to.z > -1 }
    controller.process(event: .keyboardState(move: [1, 1], look: .zero, altitude: 0, isFast: false))
    step(&controller, seconds: 1)
    let position = controller.movementController.transform.columns.3
    #expect(position.z > -1)
    // Slides along the wall to the right.
    #expect(position.x > 5)
}

@MainActor
@Test func fpvWalkBlocksHighSteps() {
    var controller = FPVMovementController()
    controller.walkSettings = FPVWalkSettings(maxStepUp: 0.5)
    // A 1 m ledge at z < -2.
    controller.hooks.groundHeight = { $0.z < -2 ? 1 : 0 }
    step(&controller, seconds: 1)
    controller.process(event: .keyboardState(move: [0, 1], look: .zero, altitude: 0, isFast: false))
    step(&controller, seconds: 1)
    #expect(controller.movementController.transform.columns.3.z >= -2)
}

@MainActor
@Test func fpvAdjustCameraSeesDistanceWalked() {
    var controller = walkingController()
    var lastDistance: Float = 0
    controller.hooks.adjustCamera = { matrix, state in
        lastDistance = state.distanceWalked
        return matrix
    }
    step(&controller, seconds: 1)
    controller.process(event: .keyboardState(move: [0, 1], look: .zero, altitude: 0, isFast: false))
    step(&controller, seconds: 1)
    #expect(abs(lastDistance - controller.speed) < 0.2)
}

@Test func slideCandidatesStartWithFullStepAndSkipDuplicates() {
    let candidates = slideCandidates(for: [1, 0, 2])
    #expect(candidates.first == [1, 0, 2])
    #expect(candidates.count == Set(candidates.map { "\($0)" }).count)
    #expect(candidates.contains([1, 0, 0]))
    #expect(candidates.contains([0, 0, 2]))
}
