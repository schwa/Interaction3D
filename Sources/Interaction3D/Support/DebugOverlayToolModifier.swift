import SwiftUI

public struct DebugOverlayToolModifier: ViewModifier {
    public init() {
        // No configuration needed
    }

    public func body(content: Content) -> some View {
        content
            .border(.red, width: 4)
    }
}

#Preview {
    Color.blue
        .modifier(DebugOverlayToolModifier())
        .padding()
}
