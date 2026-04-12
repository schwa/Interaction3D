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
    let onEnded: () -> Void

    /// Tracks whether this modifier "claimed" the current drag.
    /// Set on the first onChanged, cleared on onEnded.
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
                    .onEnded { _ in onEnded() }
            )
        } else {
            content.simultaneousGesture(
                DragGesture(minimumDistance: minimumDistance)
                    .onChanged { value in
                        #if os(macOS)
                        // Decide on first event, stick with it for the whole drag
                        if claimed == nil {
                            claimed = modifiersMatchNow()
                        }
                        guard claimed == true else { return }
                        #endif
                        onChanged(value.translation)
                    }
                    .onEnded { _ in
                        #if os(macOS)
                        let wasClaimed = claimed == true
                        claimed = nil
                        guard wasClaimed else { return }
                        #endif
                        onEnded()
                    }
            )
        }
    }
}

// MARK: - Drag Gesture Modifier (Generic over Transformer)

/// Binds a drag gesture to a binding via a transformer.
/// The transformer converts `CGSize` (drag translation) to the binding's type.
struct DragGestureModifier2<T: Transformer>: ViewModifier where T.Input == CGSize {
    let modifiers: EventModifiers?
    let transformer: T
    @Binding var value: T.Output

    @State private var valueAtDragStart: T.Output?
    @State private var isDragging = false

    func body(content: Content) -> some View {
        content.modifier(CoreDragModifier(modifiers: modifiers, minimumDistance: 10) { translation in
            if !isDragging {
                valueAtDragStart = value
                isDragging = true
            }
            value = transformer.transform(translation)
        } onEnded: {
            isDragging = false
            valueAtDragStart = nil
        })
    }
}

// MARK: - Accumulating Drag Gesture Modifier

/// Like DragGestureModifier2 but accumulates: adds transformer output to the value at drag start.
struct AccumulatingDragGestureModifier<T: Transformer>: ViewModifier where T.Input == CGSize, T.Output: AdditiveArithmetic {
    let modifiers: EventModifiers?
    let transformer: T
    @Binding var value: T.Output

    @State private var valueAtDragStart: T.Output?
    @State private var isDragging = false

    func body(content: Content) -> some View {
        content.modifier(CoreDragModifier(modifiers: modifiers, minimumDistance: 10) { translation in
            if !isDragging {
                valueAtDragStart = value
                isDragging = true
            }
            if let start = valueAtDragStart {
                value = start + transformer.transform(translation)
            }
        } onEnded: {
            isDragging = false
            valueAtDragStart = nil
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
    func dragGesture<T: Transformer>(_ modifiers: EventModifiers? = nil, transformer: T, writes value: Binding<T.Output>) -> some View where T.Input == CGSize, T.Output: AdditiveArithmetic {
        modifier(AccumulatingDragGestureModifier(modifiers: modifiers, transformer: transformer, value: value))
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

// MARK: - Binding Helpers

extension Binding where Value: AdditiveArithmetic {
    func synced(to other: Binding<Value>) -> Binding<Value> {
        Binding(
            get: { self.wrappedValue },
            set: { newValue in
                self.wrappedValue = newValue
                other.wrappedValue = newValue
            }
        )
    }
}

extension CGSize: @retroactive AdditiveArithmetic {
    public static func + (lhs: CGSize, rhs: CGSize) -> CGSize {
        CGSize(width: lhs.width + rhs.width, height: lhs.height + rhs.height)
    }

    public static func - (lhs: CGSize, rhs: CGSize) -> CGSize {
        CGSize(width: lhs.width - rhs.width, height: lhs.height - rhs.height)
    }
}

