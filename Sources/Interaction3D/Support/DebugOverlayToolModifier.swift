import SwiftUI

public struct DebugOverlayToolModifier: ViewModifier {
    public init() {}

    public func body(content: Content) -> some View {
        content
            .border(.red, width: 4)
    }
}
