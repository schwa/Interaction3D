import CoreGraphics
@testable import Interaction3D
import simd
import Testing

@MainActor
@Test func rtsNavigatorPansFromAppInput() {
    let navigator = RTSNavigator(pose: RTSCameraPose(distance: 10), settings: RTSMovementSettings(panSpeed: 1))
    navigator.panInput = [0, 1]
    #expect(navigator.hasMovementInput)
    navigator.update(deltaTime: 0.5)
    // Forward at yaw 0 is -Z; speed scales with distance.
    #expect(abs(navigator.pose.target.z - -5) < 0.0001)
}

@MainActor
@Test func rtsNavigatorPauseBlocksInputButNotPoseWrites() {
    let navigator = RTSNavigator()
    navigator.isPaused = true
    navigator.panInput = [1, 0]
    navigator.update(deltaTime: 1)
    navigator.grab(CGSize(width: 0.5, height: 0))
    navigator.magnify(by: 2)
    #expect(navigator.pose == RTSCameraPose())

    // An animation drives the pose; input continues from there after unpausing.
    navigator.pose.target = [3, 0, 0]
    navigator.isPaused = false
    navigator.panInput = .zero
    navigator.update(deltaTime: 1)
    #expect(navigator.pose.target == [3, 0, 0])
}

@MainActor
@Test func rtsNavigatorResetReturnsHome() {
    let home = RTSCameraPose(target: [1, 0, 2], yaw: 0.5)
    let navigator = RTSNavigator(pose: home)
    navigator.pose.target = [9, 0, 9]
    navigator.process(.reset)
    #expect(navigator.pose == home)
}

@MainActor
@Test func rtsNavigatorScrollZoomClampsDistance() {
    let navigator = RTSNavigator(pose: RTSCameraPose(distance: 3), settings: RTSMovementSettings(zoomStepFactor: 2, distanceRange: 2...100))
    navigator.process(.zoom(steps: 1))
    #expect(navigator.pose.distance == 2)
}

@MainActor
@Test func rtsNavigatorTracksActiveGestures() {
    let navigator = RTSNavigator()
    #expect(!navigator.hasMovementInput)
    navigator.setGesture(.orbit, isActive: true)
    #expect(navigator.hasMovementInput)
    navigator.setGesture(.orbit, isActive: false)
    #expect(!navigator.hasMovementInput)
}
