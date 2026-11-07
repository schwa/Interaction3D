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

#endif
