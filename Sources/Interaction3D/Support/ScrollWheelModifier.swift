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
        view.onScroll = { delta += $0 }
        return view
    }

    func updateNSView(_ nsView: ScrollWheelNSView, context: Context) {
        nsView.onScroll = { delta += $0 }
    }
}

// MARK: - NSView

final class ScrollWheelNSView: NSView {
    var onScroll: ((Double) -> Void)?
    override func hitTest(_ point: NSPoint) -> NSView? {
        NSApp.currentEvent?.type == .scrollWheel ? self : nil
    }

    override func scrollWheel(with event: NSEvent) {
        let delta = event.hasPreciseScrollingDeltas
            ? Double(event.scrollingDeltaY)
            : Double(event.deltaY) * 10
        onScroll?(delta)
    }

    override var acceptsFirstResponder: Bool { false }
}
#endif
