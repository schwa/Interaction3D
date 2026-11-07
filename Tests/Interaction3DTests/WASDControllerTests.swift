#if os(macOS)

import GameController
@testable import Interaction3D
import Testing

@MainActor
@Test func wasdControllerReadsKeysWhenEnabled() {
    let controller = WASDController()
    controller.isKeyPressed = { $0 == .keyW || $0 == .keyD }
    let axes = controller.keyboardAxes()
    #expect(axes.forward == 1)
    #expect(axes.sideways == 1)
}

@MainActor
@Test func wasdControllerIgnoresKeysWhenNotFocused() {
    let controller = WASDController()
    controller.isKeyPressed = { $0 == .keyW || $0 == .keyD }
    controller.isKeyboardEnabled = false
    let axes = controller.keyboardAxes()
    #expect(axes.forward == 0)
    #expect(axes.sideways == 0)
}

#endif
