#if os(macOS)
import AppKit
import SwiftUI

// MARK: - Scroll Wheel Modifier

/// Captures macOS scroll wheel events via a local event monitor when the mouse is over the view.
struct ScrollWheelModifier: ViewModifier {
    @Binding var delta: Double
    @Environment(\.interactionScrollFilter) private var scrollFilter

    func body(content: Content) -> some View {
        content.overlay {
            ScrollWheelView(filter: scrollFilter) { delta += $0 }
        }
    }
}

/// Delivers each scroll wheel delta straight to `onScroll`, with no intermediate state.
struct ScrollWheelActionModifier: ViewModifier {
    let onScroll: (Double) -> Void
    @Environment(\.interactionScrollFilter) private var scrollFilter

    func body(content: Content) -> some View {
        content.overlay {
            ScrollWheelView(filter: scrollFilter, onScroll: onScroll)
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
    let filter: (any InteractionLocationFilter)?
    let onScroll: (Double) -> Void

    func makeNSView(context: Context) -> ScrollWheelNSView {
        let view = ScrollWheelNSView()
        updateNSView(view, context: context)
        return view
    }

    func updateNSView(_ nsView: ScrollWheelNSView, context: Context) {
        nsView.onScroll = onScroll
        nsView.filter = filter
    }
}

// MARK: - NSView

final class ScrollWheelNSView: NSView {
    var onScroll: ((Double) -> Void)?
    var filter: (any InteractionLocationFilter)?

    override var isFlipped: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        NSApp.currentEvent?.type == .scrollWheel ? self : nil
    }

    override func scrollWheel(with event: NSEvent) {
        if let filter, !filter.accepts(convert(event.locationInWindow, from: nil)) {
            super.scrollWheel(with: event)
            return
        }
        let delta = event.hasPreciseScrollingDeltas
            ? Double(event.scrollingDeltaY)
            : Double(event.deltaY) * 10
        onScroll?(delta)
    }

    override var acceptsFirstResponder: Bool { false }
}
#endif
