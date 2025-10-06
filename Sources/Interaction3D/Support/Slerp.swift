import SwiftUI

@MainActor
struct SlerpModifier: ViewModifier, Animatable {
    var progress: Double
    var onChange: (Double) -> Void

    nonisolated var animatableData: Double {
        get { progress }
        set {
            progress = newValue
            MainActor.assumeIsolated {
                onChange(newValue)
            }
        }
    }

    func body(content: Content) -> some View {
        content
    }
}
