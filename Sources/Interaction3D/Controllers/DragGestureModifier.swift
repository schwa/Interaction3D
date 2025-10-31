import SwiftUI
#if os(macOS)
import AppKit
#endif

public struct DragGestureModifier: ViewModifier {
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

    public init(translation: Binding<CGSize>, minimumDistance: Double = 10, predictedThreshold: Double = 10, animationMaxDelay: TimeInterval = 0.2) {
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
                }

                #if os(macOS)
                let shiftPressed = NSEvent.modifierFlags.contains(.shift)

                // Always update both axes first
                let newWidth = (initialTranslation?.width ?? 0) + gesture.translation.width
                let newHeight = (initialTranslation?.height ?? 0) + gesture.translation.height

                translation.width = newWidth
                translation.height = newHeight

                // Sync animated values during drag
                animatedTranslation.width = newWidth
                animatedTranslation.height = newHeight

                // If shift is pressed, determine dominant axis and zero out the other
                if shiftPressed {
                    let horizontalMovement = abs(gesture.translation.width)
                    let verticalMovement = abs(gesture.translation.height)

                    // Determine dominant axis based on current movement
                    if horizontalMovement > verticalMovement {
                        dominantAxis = .horizontal
                        // Zero out vertical (keep it at initial value)
                        translation.height = initialTranslation?.height ?? 0
                        animatedTranslation.height = initialTranslation?.height ?? 0
                    } else {
                        dominantAxis = .vertical
                        // Zero out horizontal (keep it at initial value)
                        translation.width = initialTranslation?.width ?? 0
                        animatedTranslation.width = initialTranslation?.width ?? 0
                    }
                } else {
                    dominantAxis = nil
                }
                #else
                let newWidth = (initialTranslation?.width ?? 0) + gesture.translation.width
                let newHeight = (initialTranslation?.height ?? 0) + gesture.translation.height

                translation.width = newWidth
                translation.height = newHeight

                // Sync animated values during drag
                animatedTranslation.width = newWidth
                animatedTranslation.height = newHeight

                dominantAxis = nil
                #endif

                lastEventTime = Date().timeIntervalSinceReferenceDate
            }
            .onEnded { gesture in
                defer {
                    initialTranslation = nil
                    dominantAxis = nil
                    lastEventTime = nil
                }

                // Check if enough time has passed since last event
                if let lastEventTime, Date.timeIntervalSinceReferenceDate - lastEventTime > animationMaxDelay {
                    return
                }

                #if os(macOS)
                let shiftPressed = NSEvent.modifierFlags.contains(.shift)

                // Calculate predicted end values
                let predictedWidth = (initialTranslation?.width ?? 0) + gesture.predictedEndTranslation.width
                let predictedHeight = (initialTranslation?.height ?? 0) + gesture.predictedEndTranslation.height

                let horizontalDelta = abs(predictedWidth - translation.width)
                let verticalDelta = abs(predictedHeight - translation.height)

                // Only animate if the predicted movement is significant
                var shouldAnimate = false

                if shiftPressed {
                    if dominantAxis == .vertical && verticalDelta >= predictedThreshold {
                        shouldAnimate = true
                    } else if dominantAxis == .horizontal && horizontalDelta >= predictedThreshold {
                        shouldAnimate = true
                    }
                } else {
                    if horizontalDelta >= predictedThreshold || verticalDelta >= predictedThreshold {
                        shouldAnimate = true
                    }
                }

                if shouldAnimate {
                    if let lastEventTime {
                        print("Drag animation triggered - horizontalDelta: \(horizontalDelta), verticalDelta: \(verticalDelta), timeSinceLastEvent: \(Date.timeIntervalSinceReferenceDate - lastEventTime)")
                    }
                    withAnimation(.linear(duration: 0.3)) {
                        if shiftPressed {
                            if dominantAxis == .vertical {
                                animatedTranslation.height = predictedHeight
                            } else if dominantAxis == .horizontal {
                                animatedTranslation.width = predictedWidth
                            }
                        } else {
                            animatedTranslation.width = predictedWidth
                            animatedTranslation.height = predictedHeight
                        }
                    }
                }
                #else
                let predictedWidth = (initialTranslation?.width ?? 0) + gesture.predictedEndTranslation.width
                let predictedHeight = (initialTranslation?.height ?? 0) + gesture.predictedEndTranslation.height

                let horizontalDelta = abs(predictedWidth - translation.width)
                let verticalDelta = abs(predictedHeight - translation.height)

                if horizontalDelta >= predictedThreshold || verticalDelta >= predictedThreshold {
                    if let lastEventTime {
                        print("Drag animation triggered - horizontalDelta: \(horizontalDelta), verticalDelta: \(verticalDelta), timeSinceLastEvent: \(Date.timeIntervalSinceReferenceDate - lastEventTime)")
                    }
                    withAnimation(.linear(duration: 0.3)) {
                        animatedTranslation.width = predictedWidth
                        animatedTranslation.height = predictedHeight
                    }
                }
                #endif
            }
    }
}
