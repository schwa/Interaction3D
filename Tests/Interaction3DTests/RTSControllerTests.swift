#if os(macOS)

import CoreGraphics
import GameController
@testable import Interaction3D
import Testing

@MainActor
@Test func rtsControllerReadsKeysWhenEnabled() {
    let controller = RTSController()
    controller.isKeyPressed = { [.keyW, .rightArrow, .keyE, .keyF, .leftShift].contains($0) }
    let state = controller.keyboardState()
    #expect(state.pan == [1, 1])
    #expect(state.rotate == 1)
    #expect(state.zoom == -1)
    #expect(state.isFast)
}

@MainActor
@Test func rtsControllerIgnoresKeysWhenNotFocused() {
    let controller = RTSController()
    controller.isKeyPressed = { _ in true }
    controller.isKeyboardEnabled = false
    let state = controller.keyboardState()
    #expect(state.pan == .zero)
    #expect(state.rotate == 0)
    #expect(state.zoom == 0)
    #expect(!state.isFast)
    #expect(!controller.isResetTriggered())
}

@MainActor
@Test func rtsControllerEdgePans() {
    let controller = RTSController()
    #expect(controller.edgePan() == .zero)
    controller.pointerLocation = CGPoint(x: 0.5, y: 0.5)
    #expect(controller.edgePan() == .zero)
    controller.pointerLocation = .zero
    #expect(controller.edgePan() == [-1, 1])
    controller.pointerLocation = CGPoint(x: 1, y: 1)
    #expect(controller.edgePan() == [1, -1])
    controller.edgePanMargin = 0
    #expect(controller.edgePan() == .zero)
}

@MainActor
@Test func rtsControllerResetFiresOncePerPress() {
    let controller = RTSController()
    controller.isKeyPressed = { $0 == .home }
    #expect(controller.isResetTriggered())
    #expect(!controller.isResetTriggered())
}

#endif
