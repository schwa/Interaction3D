import SwiftUI

// MARK: - Animated CGSize Helper

/// Bridges SwiftUI animation to a CGSize callback, interpolating frame-by-frame.
@Animatable
struct AnimatedSizeModifier: ViewModifier {
    var width: CGFloat
    var height: CGFloat
    @AnimatableIgnored
    var onChange: (CGSize) -> Void

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

// One step of a drag, from either DragGesture or a touch-counting pan.
struct DragSample {
    var translation: CGSize
    var startLocation: CGPoint
    var location: CGPoint
    var predictedEndTranslation: CGSize

    init(translation: CGSize, startLocation: CGPoint, location: CGPoint, predictedEndTranslation: CGSize) {
        self.translation = translation
        self.startLocation = startLocation
        self.location = location
        self.predictedEndTranslation = predictedEndTranslation
    }

    init(_ value: DragGesture.Value) {
        self.init(translation: value.translation, startLocation: value.startLocation, location: value.location, predictedEndTranslation: value.predictedEndTranslation)
    }
}

/// Low-level drag gesture filtered by modifier keys.
/// Supports momentum: on release, animates from last translation to predicted end,
/// calling `onChanged` each frame during the animation.
/// `modifiers`: nil = don't care, [] = no modifiers, [.command] = exactly command, etc.
/// `touchCount` (iOS only): when set, only drags with exactly that many fingers are handled, and `modifiers` is ignored.
public struct CoreDragModifier: ViewModifier {
    let modifiers: EventModifiers?
    let minimumDistance: CGFloat
    let momentum: Bool
    let touchCount: Int?
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
        touchCount: Int? = nil,
        onChanged: @escaping (CGSize) -> Void,
        onEnded: @escaping () -> Void
    ) {
        self.modifiers = modifiers
        self.minimumDistance = minimumDistance
        self.momentum = momentum
        self.touchCount = touchCount
        self.onValueChanged = { onChanged($0.translation) }
        self.onEnded = onEnded
    }

    init(
        modifiers: EventModifiers? = nil,
        minimumDistance: CGFloat = 10,
        momentum: Bool = true,
        touchCount: Int? = nil,
        onValueChanged: @escaping (CoreDragValue) -> Void,
        onEnded: @escaping () -> Void
    ) {
        self.modifiers = modifiers
        self.minimumDistance = minimumDistance
        self.momentum = momentum
        self.touchCount = touchCount
        self.onValueChanged = onValueChanged
        self.onEnded = onEnded
    }

    // NSEvent samples modifier state synchronously at drag start; SwiftUI's onModifierKeysChanged only reports changes.
    #if canImport(AppKit)
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
            .modifier(DragInputModifier(
                touchCount: touchCount,
                dragGesture: dragGesture,
                onChanged: handleTouchChanged,
                onEnded: handleEndedIfClaimed
            ))
    }

    private var dragGesture: some Gesture {
        if let modifiers, !modifiers.isEmpty {
            return AnyGesture(
                DragGesture(minimumDistance: minimumDistance)
                #if os(macOS)
                    .modifiers(modifiers)
                #endif
                    .onChanged { value in
                        claimIfNeeded(DragSample(value), checkModifiers: false)
                        guard claimState == .claimed else {
                            return
                        }
                        handleChanged(DragSample(value))
                    }
                    .onEnded { value in
                        handleEndedIfClaimed(DragSample(value))
                    }
            )
        }
        return AnyGesture(
            DragGesture(minimumDistance: minimumDistance)
                .onChanged { value in
                    claimIfNeeded(DragSample(value), checkModifiers: true)
                    guard claimState == .claimed else {
                        return
                    }
                    handleChanged(DragSample(value))
                }
                .onEnded { value in
                    handleEndedIfClaimed(DragSample(value))
                }
        )
    }

    private func handleTouchChanged(_ sample: DragSample) {
        claimIfNeeded(sample, checkModifiers: false)
        guard claimState == .claimed else {
            return
        }
        handleChanged(sample)
    }

    private func claimIfNeeded(_ value: DragSample, checkModifiers: Bool) {
        guard claimState == .unclaimed else {
            return
        }
        var accepted = true
        #if canImport(AppKit)
        if checkModifiers {
            accepted = modifiersMatchNow()
        }
        #endif
        if accepted, let dragFilter {
            accepted = dragFilter.accepts(value.startLocation)
        }
        claimState = accepted ? .claimed : .rejected
    }

    private func handleEndedIfClaimed(_ value: DragSample) {
        let wasClaimed = claimState == .claimed
        claimState = .unclaimed
        guard wasClaimed else {
            return
        }
        handleEnded(value.translation, predicted: value.predictedEndTranslation)
    }

    private func handleChanged(_ value: DragSample) {
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

// MARK: - Drag Input

// Feeds CoreDragModifier from DragGesture, or on iOS from a pan that counts fingers.
private struct DragInputModifier<DragInput: Gesture>: ViewModifier {
    let touchCount: Int?
    let dragGesture: DragInput
    let onChanged: (DragSample) -> Void
    let onEnded: (DragSample) -> Void

    func body(content: Content) -> some View {
        #if os(iOS)
        if let touchCount {
            content.gesture(TouchCountPanGesture(touchCount: touchCount, onChanged: onChanged, onEnded: onEnded))
        } else {
            content.simultaneousGesture(dragGesture)
        }
        #else
        content.simultaneousGesture(dragGesture)
        #endif
    }
}

#if os(iOS)
// Reports a drag only while exactly `touchCount` fingers are down. Adding or lifting a finger ends it.
struct TouchCountPanGesture: UIGestureRecognizerRepresentable {
    let touchCount: Int
    let onChanged: (DragSample) -> Void
    let onEnded: (DragSample) -> Void

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var isActive = false
        var isDone = false
        var origin: CGPoint = .zero
        var startLocation: CGPoint = .zero
        var lastSample: DragSample?

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let recognizer = UIPanGestureRecognizer()
        recognizer.minimumNumberOfTouches = 1
        recognizer.maximumNumberOfTouches = max(touchCount, 2)
        recognizer.delegate = context.coordinator
        return recognizer
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        let coordinator = context.coordinator
        let view = recognizer.view
        switch recognizer.state {
        case .began, .changed:
            let translation = recognizer.translation(in: view)
            let location = recognizer.location(in: view)
            let matches = recognizer.numberOfTouches == touchCount
            if coordinator.isActive {
                if matches {
                    let sample = Self.sample(coordinator: coordinator, translation: translation, location: location, velocity: recognizer.velocity(in: view))
                    coordinator.lastSample = sample
                    onChanged(sample)
                } else {
                    end(coordinator)
                }
            } else if matches, !coordinator.isDone {
                coordinator.isActive = true
                coordinator.origin = translation
                coordinator.startLocation = location
                let sample = Self.sample(coordinator: coordinator, translation: translation, location: location, velocity: .zero)
                coordinator.lastSample = sample
                onChanged(sample)
            } else if !matches, recognizer.numberOfTouches < touchCount {
                // Still waiting for more fingers.
            } else {
                coordinator.isDone = true
            }
        default:
            if coordinator.isActive {
                end(coordinator)
            }
            coordinator.isDone = false
        }
    }

    private func end(_ coordinator: Coordinator) {
        coordinator.isActive = false
        coordinator.isDone = true
        // The last sample's velocity predates the finger change, which moves the centroid.
        if let sample = coordinator.lastSample {
            onEnded(sample)
        }
        coordinator.lastSample = nil
    }

    private static func sample(coordinator: Coordinator, translation: CGPoint, location: CGPoint, velocity: CGPoint) -> DragSample {
        let size = CGSize(width: translation.x - coordinator.origin.x, height: translation.y - coordinator.origin.y)
        // Matches UIScrollView's normal deceleration rate.
        let decay: CGFloat = 0.998 / (1 - 0.998) / 1_000
        return DragSample(
            translation: size,
            startLocation: coordinator.startLocation,
            location: location,
            predictedEndTranslation: CGSize(width: size.width + velocity.x * decay, height: size.height + velocity.y * decay)
        )
    }
}
#endif

// MARK: - Drag Filter

/// Decides whether Interaction3D input at a location may be handled.
/// Conform a struct whose stored properties hold the data the decision needs (for example gizmo bounds).
/// Don't store closures in conforming types: SwiftUI compares environment values by their stored properties.
public protocol InteractionLocationFilter {
    @MainActor
    func accepts(_ location: CGPoint) -> Bool
}

public extension EnvironmentValues {
    /// Decides once per drag, at its first change, whether Interaction3D drag controls may handle it.
    /// Receives the drag start location in the view's local coordinate space. Return false to leave the drag to the caller.
    @Entry var interactionDragFilter: (any InteractionLocationFilter)?

    /// Decides per scroll wheel event whether Interaction3D scroll controls may handle it (macOS only).
    /// Receives the pointer location in the view's local coordinate space. Rejected events pass to the next responder.
    @Entry var interactionScrollFilter: (any InteractionLocationFilter)?

    /// Decides once per magnify gesture, at its first change, whether Interaction3D magnify controls may handle it.
    /// Receives the gesture start location in the view's local coordinate space.
    @Entry var interactionMagnifyFilter: (any InteractionLocationFilter)?

    /// Decides once per two-finger rotate gesture, at its first change, whether Interaction3D rotate controls may handle it.
    /// When unset, rotate gestures use `interactionMagnifyFilter`.
    @Entry var interactionRotateFilter: (any InteractionLocationFilter)?
}

func resolvedRotateFilter(rotate: (any InteractionLocationFilter)?, magnify: (any InteractionLocationFilter)?) -> (any InteractionLocationFilter)? {
    rotate ?? magnify
}

public extension View {
    /// Rejects Interaction3D camera drags whose start location fails `filter`, for example drags that begin on a gizmo.
    func interactionDragFilter(_ filter: some InteractionLocationFilter) -> some View {
        environment(\.interactionDragFilter, filter)
    }

    /// Rejects Interaction3D scroll wheel events whose pointer location fails `filter`.
    func interactionScrollFilter(_ filter: some InteractionLocationFilter) -> some View {
        environment(\.interactionScrollFilter, filter)
    }

    /// Rejects Interaction3D magnify gestures whose start location fails `filter`.
    func interactionMagnifyFilter(_ filter: some InteractionLocationFilter) -> some View {
        environment(\.interactionMagnifyFilter, filter)
    }

    /// Rejects Interaction3D rotate gestures whose start location fails `filter`.
    func interactionRotateFilter(_ filter: some InteractionLocationFilter) -> some View {
        environment(\.interactionRotateFilter, filter)
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

    func body(content: Content) -> some View {
        content.modifier(ScrollWheelActionModifier { delta in
            value += transformer.transform(delta)
        })
    }
}
#endif

// MARK: - Magnify Gesture Modifier

struct MagnifyGestureModifier<T: Transformer>: ViewModifier where T.Input == Double, T.Output: AdditiveArithmetic {
    let transformer: T
    let momentum: Bool
    @Binding var value: T.Output

    @State private var lastMagnification: Double = 1

    func body(content: Content) -> some View {
        content.modifier(CoreMagnifyModifier(momentum: momentum) { magnification in
            let delta = magnification - lastMagnification
            lastMagnification = magnification
            value += transformer.transform(delta)
        } onEnded: {
            lastMagnification = 1
        })
    }
}

// Seconds of release velocity that momentum carries forward.
private let gestureMomentumTime = 0.2

/// Low-level magnify gesture with momentum. Reports the total magnification since the gesture began, starting at 1.
/// Honors `interactionMagnifyFilter`.
public struct CoreMagnifyModifier: ViewModifier {
    let momentum: Bool
    let onChanged: (Double) -> Void
    let onEnded: () -> Void

    @Environment(\.interactionMagnifyFilter) private var magnifyFilter
    @State private var claimState: CoreDragModifier.ClaimState = .unclaimed
    @State private var animatedMagnification: Double = 1
    @State private var isAnimating = false

    public init(momentum: Bool = true, onChanged: @escaping (Double) -> Void, onEnded: @escaping () -> Void = { /* nothing */ }) {
        self.momentum = momentum
        self.onChanged = onChanged
        self.onEnded = onEnded
    }

    public func body(content: Content) -> some View {
        content
            .modifier(AnimatedSizeModifier(width: animatedMagnification, height: 0) { size in
                if isAnimating {
                    onChanged(size.width)
                }
            })
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { gestureValue in
                        if claimState == .unclaimed {
                            let accepted = magnifyFilter?.accepts(gestureValue.startLocation) ?? true
                            claimState = accepted ? .claimed : .rejected
                        }
                        guard claimState == .claimed else {
                            return
                        }
                        isAnimating = false
                        animatedMagnification = gestureValue.magnification
                        onChanged(gestureValue.magnification)
                    }
                    .onEnded { gestureValue in
                        let wasClaimed = claimState == .claimed
                        claimState = .unclaimed
                        guard wasClaimed else {
                            return
                        }
                        let current = gestureValue.magnification
                        // Keep the prediction positive so the zoom can't flip.
                        let predicted = max(current + gestureValue.velocity * gestureMomentumTime, current / 2)
                        guard momentum, abs(predicted - current) > 0.02 else {
                            finish()
                            return
                        }
                        isAnimating = true
                        withAnimation(.easeOut(duration: 0.3)) {
                            animatedMagnification = predicted
                        } completion: {
                            finish()
                        }
                    }
            )
    }

    private func finish() {
        isAnimating = false
        animatedMagnification = 1
        onEnded()
    }
}

/// Low-level two-finger rotate gesture with momentum. Reports the total rotation since the gesture began.
/// Honors `interactionRotateFilter`, or `interactionMagnifyFilter` when that is unset.
public struct CoreRotateModifier: ViewModifier {
    let momentum: Bool
    let onChanged: (Angle) -> Void
    let onEnded: () -> Void

    @Environment(\.interactionMagnifyFilter) private var magnifyFilter
    @Environment(\.interactionRotateFilter) private var rotateFilter
    @State private var claimState: CoreDragModifier.ClaimState = .unclaimed
    @State private var animatedRadians: Double = 0
    @State private var isAnimating = false

    public init(momentum: Bool = true, onChanged: @escaping (Angle) -> Void, onEnded: @escaping () -> Void = { /* nothing */ }) {
        self.momentum = momentum
        self.onChanged = onChanged
        self.onEnded = onEnded
    }

    public func body(content: Content) -> some View {
        content
            .modifier(AnimatedSizeModifier(width: animatedRadians, height: 0) { size in
                if isAnimating {
                    onChanged(.radians(size.width))
                }
            })
            .simultaneousGesture(
                RotateGesture()
                    .onChanged { gestureValue in
                        if claimState == .unclaimed {
                            let filter = resolvedRotateFilter(rotate: rotateFilter, magnify: magnifyFilter)
                            let accepted = filter?.accepts(gestureValue.startLocation) ?? true
                            claimState = accepted ? .claimed : .rejected
                        }
                        guard claimState == .claimed else {
                            return
                        }
                        isAnimating = false
                        animatedRadians = gestureValue.rotation.radians
                        onChanged(gestureValue.rotation)
                    }
                    .onEnded { gestureValue in
                        let wasClaimed = claimState == .claimed
                        claimState = .unclaimed
                        guard wasClaimed else {
                            return
                        }
                        let current = gestureValue.rotation.radians
                        let predicted = current + gestureValue.velocity.radians * gestureMomentumTime
                        guard momentum, abs(predicted - current) > 0.02 else {
                            finish()
                            return
                        }
                        isAnimating = true
                        withAnimation(.easeOut(duration: 0.3)) {
                            animatedRadians = predicted
                        } completion: {
                            finish()
                        }
                    }
            )
    }

    private func finish() {
        isAnimating = false
        animatedRadians = 0
        onEnded()
    }
}

struct RotateGestureModifier<T: Transformer>: ViewModifier where T.Input == Angle, T.Output: AdditiveArithmetic {
    let transformer: T
    let momentum: Bool
    @Binding var value: T.Output

    @State private var lastRotation: Angle = .zero

    func body(content: Content) -> some View {
        content.modifier(CoreRotateModifier(momentum: momentum) { rotation in
            let delta = rotation - lastRotation
            lastRotation = rotation
            value += transformer.transform(delta)
        } onEnded: {
            lastRotation = .zero
        })
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

    func transformedMagnifyGesture<T: Transformer>(momentum: Bool = true, transformer: T, writes value: Binding<T.Output>) -> some View where T.Input == Double, T.Output: AdditiveArithmetic {
        modifier(MagnifyGestureModifier(transformer: transformer, momentum: momentum, value: value))
    }

    func transformedRotateGesture<T: Transformer>(momentum: Bool = true, transformer: T, writes value: Binding<T.Output>) -> some View where T.Input == Angle, T.Output: AdditiveArithmetic {
        modifier(RotateGestureModifier(transformer: transformer, momentum: momentum, value: value))
    }
}
