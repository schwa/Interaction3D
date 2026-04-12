#if os(macOS)
import AppKit
#endif
import Interaction3D
import SwiftUI

// MARK: - Animated CGSize Helper

/// Bridges SwiftUI animation to a CGSize callback, interpolating frame-by-frame.
private struct AnimatedSizeModifier: ViewModifier, Animatable {
    var width: CGFloat
    var height: CGFloat
    var onChange: (CGSize) -> Void

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(width, height) }
        set {
            width = newValue.first
            height = newValue.second
            onChange(CGSize(width: width, height: height))
        }
    }

    func body(content: Content) -> some View {
        content
    }
}

// MARK: - Core Drag Modifier

/// Low-level drag gesture filtered by modifier keys.
/// Supports momentum: on release, animates from last translation to predicted end,
/// calling `onChanged` each frame during the animation.
/// `modifiers`: nil = don't care, [] = no modifiers, [.command] = exactly command, etc.
struct NewCoreDragModifier: ViewModifier {
    let modifiers: EventModifiers?
    let minimumDistance: CGFloat
    let momentum: Bool
    let onChanged: (CGSize) -> Void
    let onEnded: () -> Void

    enum ClaimState { case unclaimed, claimed, rejected }

    @State private var claimState: ClaimState = .unclaimed
    @State private var lastTranslation: CGSize = .zero
    @State private var animatingToTranslation: CGSize = .zero
    @State private var isAnimating = false

    init(
        modifiers: EventModifiers? = nil,
        minimumDistance: CGFloat = 10,
        momentum: Bool = true,
        onChanged: @escaping (CGSize) -> Void,
        onEnded: @escaping () -> Void
    ) {
        self.modifiers = modifiers
        self.minimumDistance = minimumDistance
        self.momentum = momentum
        self.onChanged = onChanged
        self.onEnded = onEnded
    }

    #if os(macOS)
    private func modifiersMatchNow() -> Bool {
        guard let required = modifiers else {
            return true
        }
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
        content
            .modifier(AnimatedSizeModifier(
                width: animatingToTranslation.width,
                height: animatingToTranslation.height
            ) { size in
                if isAnimating {
                    onChanged(size)
                }
            })
            .simultaneousGesture(dragGesture)
    }

    private var dragGesture: some Gesture {
        if let modifiers, !modifiers.isEmpty {
            return AnyGesture(
                DragGesture(minimumDistance: minimumDistance)
                    .modifiers(modifiers)
                    .onChanged { value in
                        handleChanged(value.translation)
                    }
                    .onEnded { value in
                        handleEnded(value.translation, predicted: value.predictedEndTranslation)
                    }
            )
        } else {
            return AnyGesture(
                DragGesture(minimumDistance: minimumDistance)
                    .onChanged { value in
                        #if os(macOS)
                        if claimState == .unclaimed {
                            claimState = modifiersMatchNow() ? .claimed : .rejected
                        }
                        guard claimState == .claimed else {
                            return
                        }
                        #endif
                        handleChanged(value.translation)
                    }
                    .onEnded { value in
                        #if os(macOS)
                        let wasClaimed = claimState == .claimed
                        claimState = .unclaimed
                        guard wasClaimed else {
                            return
                        }
                        #endif
                        handleEnded(value.translation, predicted: value.predictedEndTranslation)
                    }
            )
        }
    }

    private func handleChanged(_ translation: CGSize) {
        isAnimating = false
        lastTranslation = translation
        animatingToTranslation = translation
        onChanged(translation)
    }

    private func handleEnded(_ translation: CGSize, predicted: CGSize) {
        if momentum {
            let dx = abs(predicted.width - translation.width)
            let dy = abs(predicted.height - translation.height)
            if dx > 10 || dy > 10 {
                isAnimating = true
                withAnimation(.easeOut(duration: 0.3)) {
                    animatingToTranslation = predicted
                } completion: {
                    isAnimating = false
                    onEnded()
                }
                return
            }
        }
        lastTranslation = .zero
        animatingToTranslation = .zero
        onEnded()
    }
}

// MARK: - Accumulating Drag Gesture Modifier

/// Accumulates drag translation via a transformer.
struct NewAccumulatingDragGestureModifier<T: Transformer>: ViewModifier where T.Input == CGSize, T.Output: AdditiveArithmetic & VectorArithmetic {
    let modifiers: EventModifiers?
    let transformer: T
    let momentum: Bool
    @Binding var value: T.Output

    @State private var valueAtDragStart: T.Output?
    @State private var isDragging = false

    func body(content: Content) -> some View {
        content
            .modifier(NewCoreDragModifier(modifiers: modifiers, minimumDistance: 10, momentum: momentum) { translation in
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
struct NewScrollGestureModifier<T: Transformer>: ViewModifier where T.Input == Double, T.Output: AdditiveArithmetic {
    let transformer: T
    @Binding var value: T.Output

    @State private var delta: Double = 0

    func body(content: Content) -> some View {
        content
            .onScrollWheel(delta: $delta)
            .onChange(of: delta) { _, newValue in
                if newValue != 0 {
                    value += transformer.transform(newValue)
                    delta = 0
                }
            }
    }
}
#endif

// MARK: - Magnify Gesture Modifier

struct NewMagnifyGestureModifier<T: Transformer>: ViewModifier where T.Input == Double, T.Output: AdditiveArithmetic {
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
                    value += transformer.transform(delta)
                }
                .onEnded { _ in
                    lastMagnification = 0
                }
        )
    }
}

// MARK: - View Extensions

extension View {
    func newDragGesture<T: Transformer>(
        _ modifiers: EventModifiers? = nil,
        momentum: Bool = true,
        transformer: T,
        writes value: Binding<T.Output>
    ) -> some View where T.Input == CGSize, T.Output: AdditiveArithmetic & VectorArithmetic {
        modifier(NewAccumulatingDragGestureModifier(modifiers: modifiers, transformer: transformer, momentum: momentum, value: value))
    }

    #if os(macOS)
    func newScrollGesture<T: Transformer>(transformer: T, writes value: Binding<T.Output>) -> some View where T.Input == Double, T.Output: AdditiveArithmetic {
        modifier(NewScrollGestureModifier(transformer: transformer, value: value))
    }
    #endif

    func newMagnifyGesture<T: Transformer>(transformer: T, writes value: Binding<T.Output>) -> some View where T.Input == Double, T.Output: AdditiveArithmetic {
        modifier(NewMagnifyGestureModifier(transformer: transformer, value: value))
    }
}
