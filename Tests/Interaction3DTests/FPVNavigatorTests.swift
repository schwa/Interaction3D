@testable import Interaction3D
import simd
import Testing

@MainActor
@Test func fpvNavigatorMovesFromAppInput() {
    let navigator = FPVNavigator()
    navigator.settings.speed = 2
    navigator.moveInput = [0, 1]
    #expect(navigator.hasMovementInput)
    navigator.update(deltaTime: 1)
    #expect(abs(navigator.transform.columns.3.z - -2) < 0.0001)
}

@MainActor
@Test func fpvNavigatorPauseHoldsPoseForAutopilot() {
    let navigator = FPVNavigator()
    navigator.moveInput = [0, 1]
    navigator.isPaused = true
    navigator.update(deltaTime: 1)
    #expect(navigator.transform == matrix_identity_float4x4)

    // The autopilot moves the camera; manual movement continues from there.
    var pose = matrix_identity_float4x4
    pose.columns.3 = [5, 0, 0, 1]
    navigator.setPose(pose)
    navigator.isPaused = false
    navigator.moveInput = .zero
    navigator.update(deltaTime: 1)
    #expect(navigator.transform.columns.3.x == 5)
}

@MainActor
@Test func fpvNavigatorLooksByAngle() {
    let navigator = FPVNavigator()
    navigator.look(yaw: .pi / 2, pitch: 0.25)
    #expect(abs(navigator.pitch - 0.25) < 0.0001)
    // Turned right: forward is now +X.
    let forward = -navigator.transform.columns.2
    #expect(forward.x > 0.9)
}

#if os(macOS)
import SwiftUI

// #84: the flight sim takes a navigator, or settings and hooks like fpvMovement.
@MainActor
@Test func flightSimAcceptsNavigatorSettingsAndHooks() {
    let navigator = FPVNavigator()
    var hooks = FPVMovementHooks()
    hooks.groundHeight = { _ in 0 }
    _ = Color.clear.fpvFlightSim(navigator, verticalFOV: 45)
    _ = Color.clear.fpvFlightSim(
        cameraMatrix: .constant(matrix_identity_float4x4),
        settings: FPVMovementSettings(walk: FPVWalkSettings()),
        hooks: hooks
    )
}
#endif

@MainActor
@Test func fpvNavigatorAppliesSettingsAndHooks() {
    let navigator = FPVNavigator()
    navigator.settings.walk = FPVWalkSettings(gravity: 0, eyeHeight: 2)
    navigator.hooks.groundHeight = { _ in 1 }
    for _ in 0..<300 {
        navigator.update(deltaTime: 0.01)
    }
    #expect(abs(navigator.transform.columns.3.y - 3) < 0.01)
    #expect(navigator.motionState.isOnGround)
}
