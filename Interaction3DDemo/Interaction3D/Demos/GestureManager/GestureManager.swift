#if os(macOS)
import AppKit
#endif
import Interaction3D
import SwiftUI

// MARK: - Core Drag Modifier

/// Low-level drag gesture filtered by modifier keys.
/// `modifiers`: nil = don't care, [] = no modifiers, [.command] = exactly command, etc.
private struct CoreDragModifier: ViewModifier {
    let modifiers: EventModifiers?
    let minimumDistance: CGFloat
    let onChanged: (CGSize) -> Void
    let onEnded: (CGSize) -> Void  // receives predictedEndTranslation

    /// Tracks whether this modifier "claimed" the current drag.
    @State private var claimed: Bool?

    #if os(macOS)
    private func modifiersMatchNow() -> Bool {
        guard let required = modifiers else { return true }
        let current = NSEvent.modifierFlags
        if required.isEmpty {
            return !current.contains(.command) && !current.contains(.option) && !current.contains(.shift) && !current.contains(.control)
        }
        var matches = true
        if required.contains(.command) != current.contains(.command) { matches = false }
        if required.contains(.option) != current.contains(.option) { matches = false }
        if required.contains(.shift) != current.contains(.shift) { matches = false }
        if required.contains(.control) != current.contains(.control) { matches = false }
        return matches
    }
    #endif

    func body(content: Content) -> some View {
        if let modifiers, !modifiers.isEmpty {
            content.simultaneousGesture(
                DragGesture(minimumDistance: minimumDistance)
                    .modifiers(modifiers)
                    .onChanged { value in onChanged(value.translation) }
                    .onEnded { value in onEnded(value.predictedEndTranslation) }
            )
        } else {
            content.simultaneousGesture(
                DragGesture(minimumDistance: minimumDistance)
                    .onChanged { value in
                        #if os(macOS)
                        if claimed == nil {
                            claimed = modifiersMatchNow()
                        }
                        guard claimed == true else { return }
                        #endif
                        onChanged(value.translation)
                    }
                    .onEnded { value in
                        #if os(macOS)
                        let wasClaimed = claimed == true
                        claimed = nil
                        guard wasClaimed else { return }
                        #endif
                        onEnded(value.predictedEndTranslation)
                    }
            )
        }
    }
}

// MARK: - Accumulating Drag Gesture Modifier

/// Accumulates drag translation via a transformer. Supports momentum animation on release.
struct AccumulatingDragGestureModifier<T: Transformer>: ViewModifier where T.Input == CGSize, T.Output: AdditiveArithmetic & VectorArithmetic {
    let modifiers: EventModifiers?
    let transformer: T
    let momentum: Bool
    @Binding var value: T.Output

    @State private var valueAtDragStart: T.Output?
    @State private var isDragging = false
    @State private var animatedTranslation: CGSize = .zero

    func body(content: Content) -> some View {
        content
            .modifier(CoreDragModifier(modifiers: modifiers, minimumDistance: 10) { translation in
                if !isDragging {
                    valueAtDragStart = value
                    isDragging = true
                }
                animatedTranslation = translation
                if let start = valueAtDragStart {
                    value = start + transformer.transform(translation)
                }
            } onEnded: { predictedEnd in
                if momentum, let start = valueAtDragStart {
                    // Check if predicted movement is significant
                    let currentTranslation = animatedTranslation
                    let dx = abs(predictedEnd.width - currentTranslation.width)
                    let dy = abs(predictedEnd.height - currentTranslation.height)
                    if dx > 10 || dy > 10 {
                        // Animate to predicted end
                        let targetValue = start + transformer.transform(predictedEnd)
                        withAnimation(.easeOut(duration: 0.3)) {
                            value = targetValue
                        }
                    }
                }
                isDragging = false
                valueAtDragStart = nil
                animatedTranslation = .zero
            })
    }
}

// MARK: - Scroll Gesture Modifier

#if os(macOS)
struct ScrollGestureModifier<T: Transformer>: ViewModifier where T.Input == Double, T.Output: AdditiveArithmetic {
    let transformer: T
    @Binding var value: T.Output

    @State private var delta: Double = 0

    func body(content: Content) -> some View {
        content
            .onScrollWheel(delta: $delta)
            .onChange(of: delta) { _, newValue in
                if newValue != 0 {
                    value = value + transformer.transform(newValue)
                    delta = 0
                }
            }
    }
}
#endif

// MARK: - Magnify Gesture Modifier

struct MagnifyGestureModifier<T: Transformer>: ViewModifier where T.Input == Double, T.Output: AdditiveArithmetic {
    let transformer: T
    @Binding var value: T.Output

    @State private var lastMagnification: Double = 0

    func body(content: Content) -> some View {
        content.gesture(
            MagnifyGesture()
                .onChanged { gestureValue in
                    let current = Double(gestureValue.magnification - 1)
                    let delta = current - lastMagnification
                    lastMagnification = current
                    value = value + transformer.transform(delta)
                }
                .onEnded { _ in
                    lastMagnification = 0
                }
        )
    }
}

// MARK: - View Extensions

extension View {
    func dragGesture<T: Transformer>(_ modifiers: EventModifiers? = nil, momentum: Bool = true, transformer: T, writes value: Binding<T.Output>) -> some View where T.Input == CGSize, T.Output: AdditiveArithmetic & VectorArithmetic {
        modifier(AccumulatingDragGestureModifier(modifiers: modifiers, transformer: transformer, momentum: momentum, value: value))
    }

    #if os(macOS)
    func scrollGesture<T: Transformer>(transformer: T, writes value: Binding<T.Output>) -> some View where T.Input == Double, T.Output: AdditiveArithmetic {
        modifier(ScrollGestureModifier(transformer: transformer, value: value))
    }
    #endif

    func magnifyGesture<T: Transformer>(transformer: T, writes value: Binding<T.Output>) -> some View where T.Input == Double, T.Output: AdditiveArithmetic {
        modifier(MagnifyGestureModifier(transformer: transformer, value: value))
    }
}
