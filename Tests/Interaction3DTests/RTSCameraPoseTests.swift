import CoreGraphics
@testable import Interaction3D
import Testing

@Test func rtsPosePansRelativeToYaw() {
    let pose = RTSCameraPose(target: .zero, yaw: 0, distance: 10)
    let panned = pose.panned(by: [0.5, 1])
    #expect(abs(panned.target.x - 5) < 1e-5)
    #expect(abs(panned.target.z - -10) < 1e-5)
}

@Test func rtsPoseGrabMovesTargetAgainstDrag() {
    let pose = RTSCameraPose(target: .zero, yaw: 0, distance: 10)
    // Dragging right and down moves the camera left and forward.
    let grabbed = pose.grabbed(translation: CGSize(width: 0.1, height: 0.1))
    #expect(abs(grabbed.target.x - -1) < 1e-5)
    #expect(abs(grabbed.target.z - -1) < 1e-5)
}

@Test func rtsPoseOrbitChangesYawAndPitch() {
    let pose = RTSCameraPose(yaw: 0, pitch: 0.5)
    let orbited = pose.orbited(translation: CGSize(width: 0.25, height: 0.1), speed: 1, pitchRange: 0.1...1.5)
    #expect(abs(orbited.yaw - -0.25) < 1e-5)
    #expect(abs(orbited.pitch - 0.6) < 1e-5)
    #expect(orbited.target == pose.target)
    #expect(orbited.distance == pose.distance)
}

@Test func rtsPoseOrbitClampsPitch() {
    let pose = RTSCameraPose(pitch: 0.5)
    #expect(pose.orbited(translation: CGSize(width: 0, height: 10), speed: 1, pitchRange: 0.1...1.5).pitch == 1.5)
    #expect(pose.orbited(translation: CGSize(width: 0, height: -10), speed: 1, pitchRange: 0.1...1.5).pitch == 0.1)
}
