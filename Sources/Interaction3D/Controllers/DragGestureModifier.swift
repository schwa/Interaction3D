import SwiftUI
#if os(macOS)
import AppKit
#endif

/// A view modifier that wraps `DragGesture` with enhanced behavior:
/// - Momentum animation on release using predicted end translation
/// - Shift-key axis constraining (locks drag to dominant horizontal or vertical axis)
/// - Animated state tracking that smoothly interpolates translation and location values
///
/// On macOS, command-drags are ignored to avoid conflicts with pan gestures.
public struct DragGestureModifier: ViewModifier {

    public struct DragState: Equatable, Sendable {
        public var translation: CGSize
        public var startLocation: CGPoint
        public var currentLocation: CGPoint

        public init(translation: CGSize = .zero, startLocation: CGPoint = .zero, currentLocation: CGPoint = .zero) {
            self.translation = translation
            self.startLocation = startLocation
            self.currentLocation = currentLocation
        }

        public static let zero = Self()
    }

    @Binding
    var state: DragState

    @State
    private var animatedState: DragState = .zero

    @State
    private var initialTranslation: CGSize?

    @State
    private var dominantAxis: DraggableValueAxis?

    @State
    private var lastEventTime: TimeInterval?

    var minimumDistance: Double = 10
    var predictedThreshold: Double = 10
    var animationMaxDelay: TimeInterval = 0.2

    public init(state: Binding<DragState>, minimumDistance: Double = 10, predictedThreshold: Double = 10, animationMaxDelay: TimeInterval = 0.2) {
        self._state = state
        self.minimumDistance = minimumDistance
        self.predictedThreshold = predictedThreshold
        self.animationMaxDelay = animationMaxDelay
    }

    public func body(content: Content) -> some View {
        content
            .gesture(dragGesture)
            // Animate translation
            .modifier(AnimatableValueCallbackModifier(initialValue: animatedState.translation.width) { newValue in
                state.translation.width = newValue
            })
            .modifier(AnimatableValueCallbackModifier(initialValue: animatedState.translation.height) { newValue in
                state.translation.height = newValue
            })
            // Animate currentLocation
            .modifier(AnimatableValueCallbackModifier(initialValue: animatedState.currentLocation.x) { newValue in
                state.currentLocation.x = newValue
            })
            .modifier(AnimatableValueCallbackModifier(initialValue: animatedState.currentLocation.y) { newValue in
                state.currentLocation.y = newValue
            })
    }

    var dragGesture: some Gesture {
        DragGesture(minimumDistance: minimumDistance)
            .onChanged { gesture in
                #if os(macOS)
                guard !NSEvent.modifierFlags.contains(.command) else {
                    return
                }
                #endif

                if initialTranslation == nil {
                    initialTranslation = state.translation
                    dominantAxis = nil
                    state.startLocation = gesture.startLocation
                    animatedState.startLocation = gesture.startLocation
                }

                state.currentLocation = gesture.location
                animatedState.currentLocation = gesture.location

                #if os(macOS)
                let axisConstrained = NSEvent.modifierFlags.contains(.shift)
                #else
                let axisConstrained = false
                #endif

                let newWidth = (initialTranslation?.width ?? 0) + gesture.translation.width
                let newHeight = (initialTranslation?.height ?? 0) + gesture.translation.height

                state.translation.width = newWidth
                state.translation.height = newHeight
                animatedState.translation.width = newWidth
                animatedState.translation.height = newHeight

                // If axis constrained, determine dominant axis and zero out the other
                if axisConstrained {
                    let horizontalMovement = abs(gesture.translation.width)
                    let verticalMovement = abs(gesture.translation.height)

                    if horizontalMovement > verticalMovement {
                        dominantAxis = .horizontal
                        state.translation.height = initialTranslation?.height ?? 0
                        animatedState.translation.height = initialTranslation?.height ?? 0
                    } else {
                        dominantAxis = .vertical
                        state.translation.width = initialTranslation?.width ?? 0
                        animatedState.translation.width = initialTranslation?.width ?? 0
                    }
                } else {
                    dominantAxis = nil
                }

                lastEventTime = Date().timeIntervalSinceReferenceDate
            }
            .onEnded { gesture in
                #if os(macOS)
                guard !NSEvent.modifierFlags.contains(.command) else {
                    return
                }
                #endif

                defer {
                    initialTranslation = nil
                    dominantAxis = nil
                    lastEventTime = nil
                }

                // Check if enough time has passed since last event
                if let lastEventTime, Date.timeIntervalSinceReferenceDate - lastEventTime > animationMaxDelay {
                    // Reset without animation
                    state.startLocation = .zero
                    state.currentLocation = .zero
                    animatedState.startLocation = .zero
                    animatedState.currentLocation = .zero
                    return
                }

                #if os(macOS)
                let axisConstrained = NSEvent.modifierFlags.contains(.shift)
                #else
                let axisConstrained = false
                #endif

                // Calculate predicted end values for translation
                let predictedWidth = (initialTranslation?.width ?? 0) + gesture.predictedEndTranslation.width
                let predictedHeight = (initialTranslation?.height ?? 0) + gesture.predictedEndTranslation.height

                // Calculate predicted end location
                let predictedLocation = gesture.predictedEndLocation

                let horizontalDelta = abs(predictedWidth - state.translation.width)
                let verticalDelta = abs(predictedHeight - state.translation.height)

                // Only animate if the predicted movement is significant
                let shouldAnimate: Bool
                if axisConstrained {
                    switch dominantAxis {
                    case .vertical:
                        shouldAnimate = verticalDelta >= predictedThreshold
                    case .horizontal:
                        shouldAnimate = horizontalDelta >= predictedThreshold
                    case .none:
                        shouldAnimate = false
                    }
                } else {
                    shouldAnimate = horizontalDelta >= predictedThreshold || verticalDelta >= predictedThreshold
                }

                if shouldAnimate {
                    withAnimation(.linear(duration: 0.3)) {
                        if axisConstrained {
                            switch dominantAxis {
                            case .vertical:
                                animatedState.translation.height = predictedHeight
                            case .horizontal:
                                animatedState.translation.width = predictedWidth
                            case .none:
                                break
                            }
                        } else {
                            animatedState.translation.width = predictedWidth
                            animatedState.translation.height = predictedHeight
                        }
                        // Animate currentLocation to predicted end
                        animatedState.currentLocation = predictedLocation
                    }
                } else {
                    // Reset locations without animation
                    state.startLocation = .zero
                    state.currentLocation = .zero
                    animatedState.startLocation = .zero
                    animatedState.currentLocation = .zero
                }
            }
    }
}
