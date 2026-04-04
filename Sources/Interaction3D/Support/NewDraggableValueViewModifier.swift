import SwiftUI

extension View {
    func newDraggableValue(_ value: Binding<Double>, axis: DraggableValueAxis, gestureKind: NewDraggableValueViewModifier.GestureKind = .drag) -> some View {
        self.modifier(NewDraggableValueViewModifier(value: value, axis: axis, gestureKind: gestureKind))
    }
}

struct NewDraggableValueViewModifier: ViewModifier {
    enum GestureKind {
        case drag
        case magnify
    }

    @Binding
    var value: Double

    @State
    private var animatedValue: Double

    var axis: DraggableValueAxis
    var minimumDragDistance: Double
    var predictedThreshold: Double
    var animationMaxDelay: TimeInterval
    var gestureKind: GestureKind

    @State
    private var initialValue: Double?

    @State
    private var lastEventTime: TimeInterval?

    init(value: Binding<Double>, axis: DraggableValueAxis, minimimDragDistance: Double = 10, predictedThreshold: Double = 10, animationMaxDelay: TimeInterval = 0.2, gestureKind: GestureKind = .drag) {
        self._value = value
        self.animatedValue = value.wrappedValue
        self.axis = axis
        self.minimumDragDistance = minimimDragDistance
        self.predictedThreshold = predictedThreshold
        self.animationMaxDelay = animationMaxDelay
        self.gestureKind = gestureKind
    }

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(gestureKind == .drag ? dragGesture : nil)
            .simultaneousGesture(gestureKind == .magnify ? magnifyGesture : nil)
            .modifier(AnimatableValueCallbackModifier(initialValue: animatedValue) { newValue in
                value = newValue
            })
    }

    var dragGesture: some Gesture {
        DragGesture(minimumDistance: minimumDragDistance)
            .onChanged { gesture in
                if initialValue == nil {
                    initialValue = value
                }
                value = newValue(for: gesture.translation)
                lastEventTime = Date().timeIntervalSinceReferenceDate
            }
            .onEnded { gesture in
                defer {
                    initialValue = nil
                    lastEventTime = nil
                }
                let newValue = newValue(for: gesture.predictedEndTranslation)
                if let lastEventTime, Date.timeIntervalSinceReferenceDate - lastEventTime > animationMaxDelay {
                    return
                }
                guard abs(newValue - value) >= predictedThreshold else {
                    return
                }
                withAnimation(Animation.linear(duration: 0.3)) {
                    animatedValue = newValue
                }
            }
    }

    var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { gesture in
                if initialValue == nil {
                    initialValue = value
                }
                value = newValue(for: gesture.magnification)
                lastEventTime = Date().timeIntervalSinceReferenceDate
            }
            .onEnded { gesture in
                defer {
                    initialValue = nil
                    lastEventTime = nil
                }

                let newValue = newValue(for: gesture.magnification)
                if let lastEventTime, Date.timeIntervalSinceReferenceDate - lastEventTime > animationMaxDelay {
                    return
                }
                guard abs(newValue - value) >= predictedThreshold else {
                    return
                }
                withAnimation(Animation.linear(duration: 0.3)) {
                    animatedValue = newValue
                }
            }
    }

    func newValue(for input: CGFloat) -> Double {
        // Identity mapping - no scale or behavior transformations
        (initialValue ?? value) + input
    }

    func newValue(for translation: CGSize) -> Double {
        let input: Double
        switch axis {
        case .horizontal:
            input = translation.width
        case .vertical:
            input = translation.height
        }
        return newValue(for: input)
    }
}
