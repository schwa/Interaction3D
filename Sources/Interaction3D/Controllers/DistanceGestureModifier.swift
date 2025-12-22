import SwiftUI
#if os(macOS)
import AppKit
#endif

@MainActor
public struct DistanceGestureModifier: ViewModifier {
    @Binding
    var distance: Double

    @State
    private var animatedDistance: Double = 0

    @State
    private var initialDistance: Double?

    @State
    private var lastEventTime: TimeInterval?

    var predictedThreshold: Double = 10
    var animationMaxDelay: TimeInterval = 0.2

    var distanceTransform: (Double) -> Double

    public init(distance: Binding<Double>, distanceTransform: @escaping (Double) -> Double = { $0 }) {
        self._distance = distance
        self.animatedDistance = distance.wrappedValue
        self.distanceTransform = distanceTransform
    }

    public func body(content: Content) -> some View {
        content
            .gesture(magnifyGesture)
            #if os(macOS)
            .background(
                ScrollWheelView { scrollDelta in
                    let transformedDelta = distanceTransform(scrollDelta * 0.01)
                    distance = distance * (1.0 + transformedDelta)
                }
            )
            #endif
            .modifier(AnimatableValueCallbackModifier(initialValue: animatedDistance) { newValue in
                distance = newValue
            })
    }

    var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { gesture in
                if initialDistance == nil {
                    initialDistance = distance
                }
                // MagnifyGesture gives a scale factor (1.0 = no change, 1.1 = 10% zoom in, 0.9 = 10% zoom out)
                // Convert to delta, apply transform, then convert back to scale
                let magnificationDelta = gesture.magnification - 1.0
                let transformedDelta = distanceTransform(magnificationDelta)
                distance = (initialDistance ?? distance) * (1.0 + transformedDelta)
                lastEventTime = Date().timeIntervalSinceReferenceDate
            }
            .onEnded { gesture in
                defer {
                    initialDistance = nil
                    lastEventTime = nil
                }

                // Check if enough time has passed since last event
                if let lastEventTime, Date.timeIntervalSinceReferenceDate - lastEventTime > animationMaxDelay {
                    return
                }

                let magnificationDelta = gesture.magnification - 1.0
                let transformedDelta = distanceTransform(magnificationDelta)
                let predictedDistance = (initialDistance ?? distance) * (1.0 + transformedDelta)
                let distanceDelta = abs(predictedDistance - distance)
                guard distanceDelta >= predictedThreshold else {
                    return
                }

                if let lastEventTime {
                    print("Distance animation triggered - distanceDelta: \(distanceDelta), timeSinceLastEvent: \(Date.timeIntervalSinceReferenceDate - lastEventTime)")
                }
                withAnimation(.linear(duration: 0.3)) {
                    animatedDistance = predictedDistance
                }
            }
    }
}

#if os(macOS)
private struct ScrollWheelView: NSViewRepresentable {
    var onScroll: (Double) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = ScrollWheelNSView()
        view.onScroll = onScroll
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let scrollView = nsView as? ScrollWheelNSView {
            scrollView.onScroll = onScroll
        }
    }
}

private class ScrollWheelNSView: NSView {
    var onScroll: ((Double) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func scrollWheel(with event: NSEvent) {
        // Negative deltaY means scroll up (zoom in), positive means scroll down (zoom out)
        // We negate it so that scroll up = zoom in = decrease distance
        print("Scroll wheel: deltaY=\(event.scrollingDeltaY), deltaX=\(event.deltaX), hasPreciseScrollingDeltas=\(event.hasPreciseScrollingDeltas), phase=\(event.phase.rawValue)")
        onScroll?(-Double(event.scrollingDeltaY))
    }
}
#endif
