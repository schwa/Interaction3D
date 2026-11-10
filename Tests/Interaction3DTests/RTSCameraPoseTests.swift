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
