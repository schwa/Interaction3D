import SwiftUI

struct DisableKeyModifier: ViewModifier {
    var keys: Set<KeyEquivalent>

    func body(content: Content) -> some View {
        content
            .onKeyPress(keys: keys) { _ in
                .handled
            }
    }
}

extension View {

    func disableKeys(_ keys: Set<KeyEquivalent>) -> some View {
        modifier(DisableKeyModifier(keys: keys))
    }

    func disableWASDKeys(extraControls: FPVExtraControls = []) -> some View {
        var keys: Set<KeyEquivalent> = [
            .init("w"), .init("a"), .init("s"), .init("d"), .init("q"), .init("e"),
            // Shift (fast move) delivers uppercase characters.
            .init("W"), .init("A"), .init("S"), .init("D"), .init("Q"), .init("E"),
            .upArrow, .downArrow, .leftArrow, .rightArrow
        ]
        if extraControls.contains(.roll) {
            keys.formUnion(["z", "c", "Z", "C"])
        }
        if extraControls.contains(.alternativeVertical) {
            keys.insert(.space)
        }
        if extraControls.contains(.speedAdjustment) {
            keys.formUnion(["=", "+", "-", "_"])
        }
        if extraControls.contains(.resetKey) {
            keys.insert(.home)
        }
        return disableKeys(keys)
    }
}
