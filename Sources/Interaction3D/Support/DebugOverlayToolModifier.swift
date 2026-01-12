import Foundation
import SwiftUI

private struct DebugOverlayEnabledEnvironmentKey: EnvironmentKey {
    static var defaultValue: Bool { false }
}

public extension EnvironmentValues {
    var debugOverlayEnabled: Bool {
        get { self[DebugOverlayEnabledEnvironmentKey.self] }
        set { self[DebugOverlayEnabledEnvironmentKey.self] = newValue }
    }
}

public struct DebugOverlayToolModifier: ViewModifier {
    public init() {}

    public func body(content: Content) -> some View {
        content
            .environment(\.debugOverlayEnabled, true)
    }
}
