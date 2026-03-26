#if os(macOS)
import AppKit
import SwiftUI

// MARK: - Scroll Wheel Modifier

/// Captures macOS scroll wheel events via a local event monitor when the mouse is over the view.
public struct ScrollWheelModifier: ViewModifier {
    @Binding var delta: Double

    public func body(content: Content) -> some View {
        content.background {
            ScrollWheelView(delta: $delta)
        }
    }
}

// MARK: - View Extension

public extension View {
    func onScrollWheel(delta: Binding<Double>) -> some View {
        modifier(ScrollWheelModifier(delta: delta))
    }
}

// MARK: - NSViewRepresentable

private struct ScrollWheelView: NSViewRepresentable {
    @Binding var delta: Double

    func makeNSView(context: Context) -> ScrollWheelNSView {
        let view = ScrollWheelNSView()
        view.onScroll = { self.delta += $0 }
        return view
    }

    func updateNSView(_ nsView: ScrollWheelNSView, context: Context) {
        nsView.onScroll = { self.delta += $0 }
    }
}

// MARK: - NSView

final class ScrollWheelNSView: NSView {
    var onScroll: ((Double) -> Void)?
    private var monitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            startMonitoring()
        } else {
            stopMonitoring()
        }
    }

    private func startMonitoring() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            self?.handleScrollEvent(event)
            return event  // always return the event so other views still get it
        }
    }

    private func stopMonitoring() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }

    private func handleScrollEvent(_ event: NSEvent) {
        // Only handle if the mouse is over this view's frame in window coordinates
        guard let window else { return }
        let mouseInWindow = window.mouseLocationOutsideOfEventStream
        let mouseInView = convert(mouseInWindow, from: nil)
        guard bounds.contains(mouseInView) else { return }

        guard event.momentumPhase == [] || event.momentumPhase == .changed else { return }
        let dy = event.hasPreciseScrollingDeltas
            ? Double(event.scrollingDeltaY)
            : Double(event.deltaY) * 10
        onScroll?(dy)
    }

    // Invisible to hit testing - all mouse/drag events pass through
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override var acceptsFirstResponder: Bool { false }

    deinit {
        stopMonitoring()
    }
}
#endif
