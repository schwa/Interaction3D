import SwiftUI

public extension View {
    // Marks keys as handled while this view has focus, so AppKit doesn't beep on movement keys.
    // The keys still reach GCKeyboard-based controllers.
    func claimKeys(_ keys: Set<KeyEquivalent>) -> some View {
        onKeyPress(keys: keys) { _ in
            .handled
        }
    }

    // Makes the view focusable, takes focus on appear, and claims `keys` while focused.
    // onFocusChange reports focus so the caller can gate GCKeyboard input (it is global, not per view).
    func movementInputFocus(claiming keys: Set<KeyEquivalent>, onFocusChange: @escaping (Bool) -> Void) -> some View {
        modifier(MovementInputFocusModifier(keys: keys, onFocusChange: onFocusChange))
    }
}

public extension Set<KeyEquivalent> {
    // Keys used by WASDController with the given extra controls.
    static func fpvMovementKeys(extraControls: FPVExtraControls = []) -> Self {
        var keys: Self = [
            "w", "a", "s", "d", "q", "e",
            // Shift (fast move) delivers uppercase characters.
            "W", "A", "S", "D", "Q", "E",
            .upArrow, .downArrow, .leftArrow, .rightArrow
        ]
        if extraControls.contains(.roll) {
            keys.formUnion(["z", "c", "Z", "C"])
        }
        if !extraControls.isDisjoint(with: [.alternativeVertical, .jump]) {
            keys.insert(.space)
        }
        if extraControls.contains(.speedAdjustment) {
            keys.formUnion(["=", "+", "-", "_"])
        }
        if extraControls.contains(.resetKey) {
            keys.insert(.home)
        }
        return keys
    }

    // Keys used by RTSController.
    static let rtsMovementKeys: Self = [
        "w", "a", "s", "d", "q", "e", "r", "f",
        "W", "A", "S", "D", "Q", "E", "R", "F",
        .upArrow, .downArrow, .leftArrow, .rightArrow, .home
    ]
}

private struct MovementInputFocusModifier: ViewModifier {
    let keys: Set<KeyEquivalent>
    let onFocusChange: (Bool) -> Void

    @FocusState
    private var isFocused: Bool

    func body(content: Content) -> some View {
        content
            .focusable()
            .focused($isFocused)
            .focusEffectDisabled()
            .task {
                // Claim focus on appear so keys work without a click.
                isFocused = true
            }
            .onChange(of: isFocused, initial: true) {
                onFocusChange(isFocused)
            }
            .claimKeys(keys)
    }
}
