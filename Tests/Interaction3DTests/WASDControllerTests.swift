#if os(macOS)

import GameController
@testable import Interaction3D
import Testing

@MainActor
@Test func wasdControllerReadsKeysWhenEnabled() {
    let controller = WASDController()
    controller.isKeyPressed = { [.keyW, .keyD, .keyE, .leftArrow, .upArrow, .leftShift].contains($0) }
    let state = controller.keyboardState()
    #expect(state.move == [1, 1])
    #expect(state.look == [-1, 1])
    #expect(state.altitude == 1)
    #expect(state.isFast)
}

@MainActor
@Test func wasdControllerIgnoresKeysWhenNotFocused() {
    let controller = WASDController()
    controller.isKeyPressed = { _ in true }
    controller.isKeyboardEnabled = false
    let state = controller.keyboardState()
    #expect(state.move == .zero)
    #expect(state.look == .zero)
    #expect(state.altitude == 0)
    #expect(!state.isFast)
}

@MainActor
@Test func wasdControllerIgnoresExtraKeysUnlessOptedIn() {
    let controller = WASDController()
    controller.isKeyPressed = { _ in true }
    controller.isRightMouseButtonPressed = { false }
    #expect(controller.keyboardState().altitude == 0)
    let extra = controller.extraKeyboardState()
    #expect(extra.roll == 0)
    #expect(!extra.isSlow)
    #expect(extra.isLookHeld)
    #expect(controller.speedKeySteps() == 0)
    #expect(!controller.isResetTriggered())
}

@MainActor
@Test func wasdControllerReadsExtraKeysWhenOptedIn() {
    let controller = WASDController()
    controller.extraControls = .all
    var pressed: Set<GCKeyCode> = [.keyC, .leftAlt, .spacebar, .equalSign, .home]
    controller.isKeyPressed = { pressed.contains($0) }
    controller.isRightMouseButtonPressed = { false }
    #expect(controller.keyboardState().altitude == 1)
    let extra = controller.extraKeyboardState()
    #expect(extra.roll == 1)
    #expect(extra.isSlow)
    #expect(!extra.isLookHeld)
    #expect(controller.speedKeySteps() == 1)
    #expect(controller.speedKeySteps() == 0)
    #expect(controller.isResetTriggered())
    #expect(!controller.isResetTriggered())
    pressed = [.leftControl]
    #expect(controller.keyboardState().altitude == -1)
}

#endif
