import CoreGraphics
@testable import Interaction3D
import Testing

@MainActor
@Test func rtsScrollZoomHonorsScrollGate() {
    let controller = RTSController()
    controller.pointerLocation = CGPoint(x: 0.5, y: 0.5)
    #expect(controller.zoomSteps(forScroll: 2) == 1)
    controller.isScrollAllowed = false
    #expect(controller.zoomSteps(forScroll: 2) == nil)
}

@MainActor
@Test func rtsScrollZoomNeedsPointerOverView() {
    let controller = RTSController()
    controller.pointerLocation = nil
    #expect(controller.zoomSteps(forScroll: 2) == nil)
}

@MainActor
@Test func wasdScrollSpeedHonorsScrollGate() {
    let controller = WASDController()
    controller.extraControls = [.speedAdjustment]
    #expect(controller.speedSteps(forScroll: -1) == -1)
    controller.isScrollAllowed = false
    #expect(controller.speedSteps(forScroll: -1) == nil)
}

@MainActor
@Test func wasdMouseLookHonorsLookGateUnlessCaptured() {
    let capture = MouseCapture()
    capture.apply = { _ in /* don't touch the real cursor */ }
    let controller = WASDController(mouseCapture: capture)
    #expect(controller.shouldForwardMouseLook())
    controller.isLookAllowed = false
    #expect(!controller.shouldForwardMouseLook())
    capture.capture()
    #expect(controller.shouldForwardMouseLook())
}

@MainActor
@Test func wasdHoldToLookLatchesGateAtPress() {
    let controller = WASDController()
    controller.extraControls = [.holdToLook]
    var isPressed = false
    controller.isRightMouseButtonPressed = { isPressed }

    // Press while over a filtered area: look stays off for this press.
    controller.isLookAllowed = false
    isPressed = true
    #expect(!controller.extraKeyboardState().isLookHeld)
    controller.isLookAllowed = true
    #expect(!controller.extraKeyboardState().isLookHeld)

    // Release and press again over the scene.
    isPressed = false
    _ = controller.extraKeyboardState()
    isPressed = true
    #expect(controller.extraKeyboardState().isLookHeld)
}

private struct RejectAll: InteractionLocationFilter {
    func accepts(_ location: CGPoint) -> Bool {
        false
    }
}

@MainActor
@Test func rotateFilterFallsBackToMagnifyFilter() {
    #expect(resolvedRotateFilter(rotate: nil, magnify: nil) == nil)
    #expect(resolvedRotateFilter(rotate: nil, magnify: RejectAll())?.accepts(.zero) == false)
}
