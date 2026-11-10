@testable import Interaction3D
import SwiftUI
import Testing

@MainActor
@Test func mouseCaptureTogglesAndAppliesOnce() {
    var applied: [Bool] = []
    let capture = MouseCapture()
    capture.apply = { applied.append($0) }
    capture.capture()
    capture.capture()
    #expect(capture.isCaptured)
    capture.toggle()
    #expect(!capture.isCaptured)
    capture.release()
    #expect(applied == [true, false])
}

@MainActor
@Test func mouseCaptureIsSharedBetweenNavigatorAndKeyboard() {
    let navigator = FPVNavigator()
    navigator.mouseCapture.apply = { _ in /* don't touch the real cursor */ }
    let keyboard = WASDController(mouseCapture: navigator.mouseCapture)
    navigator.captureMouse()
    #expect(keyboard.isMouseCaptured)
    keyboard.releaseMouse()
    #expect(!navigator.isMouseCaptured)
}

@Test func movementKeySetsFollowExtraControls() {
    let base = Set<KeyEquivalent>.fpvMovementKeys()
    #expect(base.contains("w"))
    #expect(base.contains("W"))
    #expect(!base.contains(.space))
    #expect(Set<KeyEquivalent>.fpvMovementKeys(extraControls: [.jump]).contains(.space))
    #expect(Set<KeyEquivalent>.fpvMovementKeys(extraControls: [.roll]).contains("z"))
    #expect(Set<KeyEquivalent>.rtsMovementKeys.contains("r"))
    #expect(Set<KeyEquivalent>.rtsMovementKeys.contains(.home))
}
