import SwiftUI
#if os(macOS)
import AppKit
#endif

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

        public static let zero = DragState()
    }
    @Binding
    var state: DragState

    // Keep translation binding for backward compatibility
    @Binding
    var translation: CGSize

    @State
    private var animatedTranslation: CGSize = .zero

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
        self._translation = Binding(
            get: { state.wrappedValue.translation },
            set: { state.wrappedValue.translation = $0 }
        )
        self.animatedTranslation = state.wrappedValue.translation
        self.minimumDistance = minimumDistance
        self.predictedThreshold = predictedThreshold
        self.animationMaxDelay = animationMaxDelay
    }

    public init(translation: Binding<CGSize>, minimumDistance: Double = 10, predictedThreshold: Double = 10, animationMaxDelay: TimeInterval = 0.2) {
        self._state = .constant(.zero)
        self._translation = translation
        self.animatedTranslation = translation.wrappedValue
        self.minimumDistance = minimumDistance
        self.predictedThreshold = predictedThreshold
        self.animationMaxDelay = animationMaxDelay
    }

    public func body(content: Content) -> some View {
        content
            .gesture(dragGesture)
            .modifier(AnimatableValueCallbackModifier(initialValue: animatedTranslation.width) { newValue in
                translation.width = newValue
            })
            .modifier(AnimatableValueCallbackModifier(initialValue: animatedTranslation.height) { newValue in
                translation.height = newValue
            })
    }

    var dragGesture: some Gesture {
        DragGesture(minimumDistance: minimumDistance)
            .onChanged { gesture in
                if initialTranslation == nil {
                    initialTranslation = translation
                    dominantAxis = nil
                    state.startLocation = gesture.startLocation
                }

                state.currentLocation = gesture.location

                #if os(macOS)
                let axisConstrained = NSEvent.modifierFlags.contains(.shift)
                #else
                let axisConstrained = false
                #endif

                let newWidth = (initialTranslation?.width ?? 0) + gesture.translation.width
                let newHeight = (initialTranslation?.height ?? 0) + gesture.translation.height

                translation.width = newWidth
                translation.height = newHeight

                // Sync animated values during drag
                animatedTranslation.width = newWidth
                animatedTranslation.height = newHeight

                // If axis constrained, determine dominant axis and zero out the other
                if axisConstrained {
                    let horizontalMovement = abs(gesture.translation.width)
                    let verticalMovement = abs(gesture.translation.height)

                    if horizontalMovement > verticalMovement {
                        dominantAxis = .horizontal
                        translation.height = initialTranslation?.height ?? 0
                        animatedTranslation.height = initialTranslation?.height ?? 0
                    } else {
                        dominantAxis = .vertical
                        translation.width = initialTranslation?.width ?? 0
                        animatedTranslation.width = initialTranslation?.width ?? 0
                    }
                } else {
                    dominantAxis = nil
                }

                lastEventTime = Date().timeIntervalSinceReferenceDate
            }
            .onEnded { gesture in
                defer {
                    initialTranslation = nil
                    dominantAxis = nil
                    lastEventTime = nil
                    state.startLocation = .zero
                    state.currentLocation = .zero
                }

                // Check if enough time has passed since last event
                if let lastEventTime, Date.timeIntervalSinceReferenceDate - lastEventTime > animationMaxDelay {
                    return
                }

                #if os(macOS)
                let axisConstrained = NSEvent.modifierFlags.contains(.shift)
                #else
                let axisConstrained = false
                #endif

                // Calculate predicted end values
                let predictedWidth = (initialTranslation?.width ?? 0) + gesture.predictedEndTranslation.width
                let predictedHeight = (initialTranslation?.height ?? 0) + gesture.predictedEndTranslation.height

                let horizontalDelta = abs(predictedWidth - translation.width)
                let verticalDelta = abs(predictedHeight - translation.height)

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
                                animatedTranslation.height = predictedHeight
                            case .horizontal:
                                animatedTranslation.width = predictedWidth
                            case .none:
                                break
                            }
                        } else {
                            animatedTranslation.width = predictedWidth
                            animatedTranslation.height = predictedHeight
                        }
                    }
                }
            }
    }
}
