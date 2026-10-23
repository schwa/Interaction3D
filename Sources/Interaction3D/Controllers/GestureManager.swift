#if os(macOS)
import AppKit
#endif
import SwiftUI

// MARK: - Animated CGSize Helper

/// Bridges SwiftUI animation to a CGSize callback, interpolating frame-by-frame.
private struct AnimatedSizeModifier: ViewModifier, @MainActor Animatable {
    var width: CGFloat
    var height: CGFloat
    var onChange: (CGSize) -> Void

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(width, height) }
        set {
            width = newValue.first
            height = newValue.second
        }
    }

    func body(content: Content) -> some View {
        content
            .onChange(of: CGSize(width: width, height: height)) { _, size in
                onChange(size)
            }
    }
}

// MARK: - Core Drag Modifier

struct CoreDragValue: Equatable {
    var translation: CGSize
    var startLocation: CGPoint
    var currentLocation: CGPoint
}

/// Low-level drag gesture filtered by modifier keys.
/// Supports momentum: on release, animates from last translation to predicted end,
/// calling `onChanged` each frame during the animation.
/// `modifiers`: nil = don't care, [] = no modifiers, [.command] = exactly command, etc.
public struct CoreDragModifier: ViewModifier {
    let modifiers: EventModifiers?
    let minimumDistance: CGFloat
    let momentum: Bool
    let onValueChanged: (CoreDragValue) -> Void
    let onEnded: () -> Void

    enum ClaimState { case unclaimed, claimed, rejected }

    @Environment(\.interactionDragFilter) private var dragFilter
    @State private var claimState: ClaimState = .unclaimed
    @State private var startLocation: CGPoint = .zero
    @State private var animatingToTranslation: CGSize = .zero
    @State private var isAnimating = false

    public init(
        modifiers: EventModifiers? = nil,
        minimumDistance: CGFloat = 10,
        momentum: Bool = true,
        onChanged: @escaping (CGSize) -> Void,
        onEnded: @escaping () -> Void
    ) {
        self.modifiers = modifiers
        self.minimumDistance = minimumDistance
        self.momentum = momentum
        self.onValueChanged = { onChanged($0.translation) }
        self.onEnded = onEnded
    }

    init(
        modifiers: EventModifiers? = nil,
        minimumDistance: CGFloat = 10,
        momentum: Bool = true,
        onValueChanged: @escaping (CoreDragValue) -> Void,
        onEnded: @escaping () -> Void
    ) {
        self.modifiers = modifiers
        self.minimumDistance = minimumDistance
        self.momentum = momentum
        self.onValueChanged = onValueChanged
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

    public func body(content: Content) -> some View {
        content
            .modifier(AnimatedSizeModifier(
                width: animatingToTranslation.width,
                height: animatingToTranslation.height
            ) { size in
                if isAnimating {
                    notifyChanged(translation: size)
                }
            })
            .simultaneousGesture(dragGesture)
    }

    private var dragGesture: some Gesture {
        if let modifiers, !modifiers.isEmpty {
            return AnyGesture(
                DragGesture(minimumDistance: minimumDistance)
                #if os(macOS)
                    .modifiers(modifiers)
                #endif
                    .onChanged { value in
                        claimIfNeeded(value, checkModifiers: false)
                        guard claimState == .claimed else {
                            return
                        }
                        handleChanged(value)
                    }
                    .onEnded { value in
                        handleEndedIfClaimed(value)
                    }
            )
        }
        return AnyGesture(
            DragGesture(minimumDistance: minimumDistance)
                .onChanged { value in
                    claimIfNeeded(value, checkModifiers: true)
                    guard claimState == .claimed else {
                        return
                    }
                    handleChanged(value)
                }
                .onEnded { value in
                    handleEndedIfClaimed(value)
                }
        )
    }

    private func claimIfNeeded(_ value: DragGesture.Value, checkModifiers: Bool) {
        guard claimState == .unclaimed else {
            return
        }
        var accepted = true
        #if os(macOS)
        if checkModifiers {
            accepted = modifiersMatchNow()
        }
        #endif
        if accepted, let dragFilter {
            accepted = dragFilter(value.startLocation)
        }
        claimState = accepted ? .claimed : .rejected
    }

    private func handleEndedIfClaimed(_ value: DragGesture.Value) {
        let wasClaimed = claimState == .claimed
        claimState = .unclaimed
        guard wasClaimed else {
            return
        }
        handleEnded(value.translation, predicted: value.predictedEndTranslation)
    }

    private func handleChanged(_ value: DragGesture.Value) {
        isAnimating = false
        startLocation = value.startLocation
        animatingToTranslation = value.translation
        notifyChanged(translation: value.translation, currentLocation: value.location)
    }

    private func notifyChanged(translation: CGSize, currentLocation: CGPoint? = nil) {
        onValueChanged(
            CoreDragValue(
                translation: translation,
                startLocation: startLocation,
                currentLocation: currentLocation ?? CGPoint(
                    x: startLocation.x + translation.width,
                    y: startLocation.y + translation.height
                )
            )
        )
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
                    finish()
                }
                return
            }
        }
        finish()
    }

    private func finish() {
        isAnimating = false
        startLocation = .zero
        animatingToTranslation = .zero
        onEnded()
    }
}

// MARK: - Drag Filter

public extension EnvironmentValues {
    /// Decides once per drag, at its first change, whether Interaction3D drag controls may handle it.
    /// Receives the drag start location in the view's local coordinate space. Return false to leave the drag to the caller.
    @Entry var interactionDragFilter: (@MainActor (CGPoint) -> Bool)?

    /// Decides per scroll wheel event whether Interaction3D scroll controls may handle it (macOS only).
    /// Receives the pointer location in the view's local coordinate space. Rejected events pass to the next responder.
    @Entry var interactionScrollFilter: (@MainActor (CGPoint) -> Bool)?

    /// Decides once per magnify gesture, at its first change, whether Interaction3D magnify controls may handle it.
    /// Receives the gesture start location in the view's local coordinate space.
    @Entry var interactionMagnifyFilter: (@MainActor (CGPoint) -> Bool)?
}

public extension View {
    /// Rejects Interaction3D camera drags whose start location fails `filter`, for example drags that begin on a gizmo.
    func interactionDragFilter(_ filter: @escaping @MainActor (CGPoint) -> Bool) -> some View {
        environment(\.interactionDragFilter, filter)
    }

    /// Rejects Interaction3D scroll wheel events whose pointer location fails `filter`.
    func interactionScrollFilter(_ filter: @escaping @MainActor (CGPoint) -> Bool) -> some View {
        environment(\.interactionScrollFilter, filter)
    }

    /// Rejects Interaction3D magnify gestures whose start location fails `filter`.
    func interactionMagnifyFilter(_ filter: @escaping @MainActor (CGPoint) -> Bool) -> some View {
        environment(\.interactionMagnifyFilter, filter)
    }
}

// MARK: - Accumulating Drag Gesture Modifier

/// Accumulates drag translation via a transformer.
struct AccumulatingDragGestureModifier<T: Transformer>: ViewModifier where T.Input == CGSize, T.Output: AdditiveArithmetic & VectorArithmetic {
    let modifiers: EventModifiers?
    let transformer: T
    let momentum: Bool
    @Binding var value: T.Output

    @State private var valueAtDragStart: T.Output?
    @State private var isDragging = false

    func body(content: Content) -> some View {
        content
            .modifier(CoreDragModifier(modifiers: modifiers, minimumDistance: 10, momentum: momentum) { translation in
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
                    value += transformer.transform(newValue)
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

    @Environment(\.interactionMagnifyFilter) private var magnifyFilter
    @State private var lastMagnification: Double = 0
    @State private var claimState: CoreDragModifier.ClaimState = .unclaimed

    func body(content: Content) -> some View {
        content.gesture(
            MagnifyGesture()
                .onChanged { gestureValue in
                    if claimState == .unclaimed {
                        let accepted = magnifyFilter?(gestureValue.startLocation) ?? true
                        claimState = accepted ? .claimed : .rejected
                    }
                    guard claimState == .claimed else {
                        return
                    }
                    let current = Double(gestureValue.magnification - 1)
                    let delta = current - lastMagnification
                    lastMagnification = current
                    value += transformer.transform(delta)
                }
                .onEnded { _ in
                    lastMagnification = 0
                    claimState = .unclaimed
                }
        )
    }
}

// MARK: - View Extensions

public extension View {
    func transformedDragGesture<T: Transformer>(
        _ modifiers: EventModifiers? = nil,
        momentum: Bool = true,
        transformer: T,
        writes value: Binding<T.Output>
    ) -> some View where T.Input == CGSize, T.Output: AdditiveArithmetic & VectorArithmetic {
        modifier(AccumulatingDragGestureModifier(modifiers: modifiers, transformer: transformer, momentum: momentum, value: value))
    }

    #if os(macOS)
    func transformedScrollGesture<T: Transformer>(transformer: T, writes value: Binding<T.Output>) -> some View where T.Input == Double, T.Output: AdditiveArithmetic {
        modifier(ScrollGestureModifier(transformer: transformer, value: value))
    }
    #endif

    func transformedMagnifyGesture<T: Transformer>(transformer: T, writes value: Binding<T.Output>) -> some View where T.Input == Double, T.Output: AdditiveArithmetic {
        modifier(MagnifyGestureModifier(transformer: transformer, value: value))
    }
}
