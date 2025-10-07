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

public extension View {

    func disableKeys(_ keys: Set<KeyEquivalent>) -> some View {
        modifier(DisableKeyModifier(keys: keys))
    }

    func disableWASDKeys() -> some View {
        disableKeys([.init("w"), .init("a"), .init("s"), .init("d")])
    }
}
