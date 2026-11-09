import AsyncAlgorithms
import CoreGraphics
import GameController
import Observation
import SwiftUI

public enum RTSEvent: Sendable {
    // pan.x is right minus left, pan.y is forward minus back. rotate is right minus left. zoom is in minus out.
    case keyboardState(pan: SIMD2<Float>, rotate: Float, zoom: Float, isFast: Bool)
    // Pan from the cursor near the view edge, each axis in -1...1.
    case edgePan(SIMD2<Float>)
    // Positive zooms in.
    case zoom(steps: Float)
    case reset
}

@Observable
@MainActor
public final class RTSController {
    @ObservationIgnored
    private let eventContinuation: AsyncStream<RTSEvent>.Continuation

    @ObservationIgnored
    public let events: AsyncStream<RTSEvent>

    @ObservationIgnored
    private var mouseConnectTask: Task<Void, Never>?

    @ObservationIgnored
    private var mouseBecameCurrentTask: Task<Void, Never>?

    @ObservationIgnored
    private var timerTask: Task<Void, Never>?

    @ObservationIgnored
    private var mouseMonitor: Any?

    // GCKeyboard is global, so the owning view must clear this when it loses focus.
    @ObservationIgnored
    public var isKeyboardEnabled = true

    // Cursor position in the view, normalized to 0...1 with +Y down. The owning view sets this
    // from onContinuousHover and clears it when the cursor leaves.
    @ObservationIgnored
    public var pointerLocation: CGPoint?

    // Fraction of the view size, from each edge, that triggers edge panning. Zero turns it off.
    @ObservationIgnored
    public var edgePanMargin: CGFloat = 0.02

    @ObservationIgnored
    var isKeyPressed: (GCKeyCode) -> Bool = { keyCode in
        GCKeyboard.coalesced?.keyboardInput?.button(forKeyCode: keyCode)?.isPressed ?? false
    }

    @ObservationIgnored
    private var wasResetPressed = false

    public init() {
        (events, eventContinuation) = AsyncStream.makeStream(of: RTSEvent.self, bufferingPolicy: .bufferingNewest(32))
        setupMouseHandling()
        startTimerLoop()
    }

    isolated deinit {
        mouseConnectTask?.cancel()
        mouseBecameCurrentTask?.cancel()
        timerTask?.cancel()
        eventContinuation.finish()
        #if canImport(AppKit)
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
        }
        #endif
    }

    // WASD or arrows pan, Q/E rotate, R/F zoom in/out, Shift is faster.
    func keyboardState() -> (pan: SIMD2<Float>, rotate: Float, zoom: Float, isFast: Bool) {
        guard isKeyboardEnabled else {
            return (.zero, 0, 0, false)
        }
        func axis(_ positive: [GCKeyCode], _ negative: [GCKeyCode]) -> Float {
            (positive.contains(where: isKeyPressed) ? 1 : 0) - (negative.contains(where: isKeyPressed) ? 1 : 0)
        }
        let pan = SIMD2<Float>(
            axis([.keyD, .rightArrow], [.keyA, .leftArrow]),
            axis([.keyW, .upArrow], [.keyS, .downArrow])
        )
        let rotate = axis([.keyE], [.keyQ])
        let zoom = axis([.keyR], [.keyF])
        let isFast = isKeyPressed(.leftShift) || isKeyPressed(.rightShift)
        return (pan, rotate, zoom, isFast)
    }

    func edgePan() -> SIMD2<Float> {
        guard edgePanMargin > 0, let location = pointerLocation else {
            return .zero
        }
        func axis(_ value: CGFloat) -> Float {
            if value <= edgePanMargin {
                return -1
            }
            if value >= 1 - edgePanMargin {
                return 1
            }
            return 0
        }
        // Pointer +Y is down, so the top edge pans forward.
        return SIMD2<Float>(axis(location.x), -axis(location.y))
    }

    func isResetTriggered() -> Bool {
        let pressed = isKeyboardEnabled && isKeyPressed(.home)
        defer { wasResetPressed = pressed }
        return pressed && !wasResetPressed
    }

    private func startTimerLoop() {
        timerTask = Task { [weak self] in
            for await _ in AsyncTimerSequence(interval: .milliseconds(16), clock: .continuous) {
                guard let self else {
                    return
                }
                let state = keyboardState()
                eventContinuation.yield(.keyboardState(pan: state.pan, rotate: state.rotate, zoom: state.zoom, isFast: state.isFast))
                let edge = edgePan()
                if edge != .zero {
                    eventContinuation.yield(.edgePan(edge))
                }
                if isResetTriggered() {
                    eventContinuation.yield(.reset)
                }
            }
        }
    }

    private func setupMouseHandling() {
        mouseConnectTask = Task { [weak self] in
            for await notification in NotificationCenter.default.notifications(named: .GCMouseDidConnect) {
                if let mouse = notification.object as? GCMouse {
                    self?.registerMouse(mouse)
                }
            }
        }
        mouseBecameCurrentTask = Task { [weak self] in
            for await notification in NotificationCenter.default.notifications(named: .GCMouseDidBecomeCurrent) {
                if let mouse = notification.object as? GCMouse {
                    self?.registerMouse(mouse)
                }
            }
        }

        if let mouse = GCMouse.current ?? GCMouse.mice().first {
            registerMouse(mouse)
        } else {
            #if canImport(AppKit)
            setupNSEventMonitor()
            #endif
        }
    }

    #if canImport(AppKit)
    private func setupNSEventMonitor() {
        mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel]) { [weak self] event in
            if let self, event.scrollingDeltaY != 0, pointerLocation != nil {
                eventContinuation.yield(.zoom(steps: event.scrollingDeltaY > 0 ? 1 : -1))
            }
            return event
        }
    }
    #endif

    private func registerMouse(_ mouse: GCMouse) {
        mouse.mouseInput?.scroll.yAxis.valueChangedHandler = { [weak self] _, value in
            // Only zoom while the cursor is over the view.
            guard let self, value != 0, pointerLocation != nil else {
                return
            }
            eventContinuation.yield(.zoom(steps: value > 0 ? 1 : -1))
        }
    }
}
