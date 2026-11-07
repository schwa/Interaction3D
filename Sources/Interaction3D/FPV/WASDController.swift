#if os(macOS)
import AppKit
#endif
import AsyncAlgorithms
import CoreGraphics
import GameController
import Observation
import SwiftUI

@Observable
@MainActor
public final class WASDController {
    @ObservationIgnored
    private let eventContinuation: AsyncStream<NavigationEvent>.Continuation

    @ObservationIgnored
    public let events: AsyncStream<NavigationEvent>

    @ObservationIgnored
    private var mouseConnectTask: Task<Void, Never>?

    @ObservationIgnored
    private var mouseBecameCurrentTask: Task<Void, Never>?

    @ObservationIgnored
    private var timerTask: Task<Void, Never>?

    @ObservationIgnored
    private var mouseMonitor: Any?

    public var isMouseCaptured = false

    // GCKeyboard is global, so the owning view must clear this when it loses focus.
    @ObservationIgnored
    public var isKeyboardEnabled = true

    @ObservationIgnored
    var isKeyPressed: (GCKeyCode) -> Bool = { keyCode in
        GCKeyboard.coalesced?.keyboardInput?.button(forKeyCode: keyCode)?.isPressed ?? false
    }

    public init() {
        (events, eventContinuation) = AsyncStream.makeStream(of: NavigationEvent.self, bufferingPolicy: .bufferingNewest(1))
        setupMouseHandling()
        startTimerLoop()
    }

    isolated deinit {
        mouseConnectTask?.cancel()
        mouseBecameCurrentTask?.cancel()
        timerTask?.cancel()
        eventContinuation.finish()
        #if os(macOS)
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if isMouseCaptured {
            CGDisplayShowCursor(CGMainDisplayID())
            CGAssociateMouseAndMouseCursorPosition(1)
        }
        #endif
    }

    // WASD moves, Q/E go down/up, arrows look, Shift moves faster.
    func keyboardState() -> (move: SIMD2<Float>, look: SIMD2<Float>, altitude: Float, isFast: Bool) {
        guard isKeyboardEnabled else {
            return (.zero, .zero, 0, false)
        }
        func axis(_ positive: GCKeyCode, _ negative: GCKeyCode) -> Float {
            (isKeyPressed(positive) ? 1 : 0) - (isKeyPressed(negative) ? 1 : 0)
        }
        let move = SIMD2<Float>(axis(.keyD, .keyA), axis(.keyW, .keyS))
        let look = SIMD2<Float>(axis(.rightArrow, .leftArrow), axis(.upArrow, .downArrow))
        let altitude = axis(.keyE, .keyQ)
        let isFast = isKeyPressed(.leftShift) || isKeyPressed(.rightShift)
        return (move, look, altitude, isFast)
    }

    private func startTimerLoop() {
        timerTask = Task { [weak self] in
            for await _ in AsyncTimerSequence(interval: .milliseconds(16), clock: .continuous) {
                guard let self else {
                    return
                }

                let state = keyboardState()
                eventContinuation.yield(.keyboardState(move: state.move, look: state.look, altitude: state.altitude, isFast: state.isFast))
            }
        }
    }

    private func setupMouseHandling() {
        mouseConnectTask = Task { [weak self] in
            for await notification in NotificationCenter.default.notifications(named: .GCMouseDidConnect) {
                print("Mouse connected via notification")
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

        if let mouse = GCMouse.current {
            registerMouse(mouse)
        } else {
            let mice = GCMouse.mice()
            if let mouse = mice.first {
                registerMouse(mouse)
            } else {
                #if os(macOS)
                print("No mouse/trackpad found - setting up NSEvent monitor")
                setupNSEventMonitor()
                #endif
            }
        }
    }

    #if os(macOS)
    private func setupNSEventMonitor() {
        mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            guard let self else {
                return event
            }

            switch event.type {
            case .mouseMoved:
                let deltaX = event.deltaX
                let deltaY = event.deltaY
                if deltaX != 0 || deltaY != 0 {
                    eventContinuation.yield(.look(deltaX: Float(deltaX), deltaY: Float(deltaY)))
                }
            default:
                break
            }

            return event
        }
    }
    #endif

    public func toggleMouseCapture() {
        if isMouseCaptured {
            releaseMouse()
        } else {
            captureMouse()
        }
    }

    // Cursor capture is macOS-only; elsewhere these do nothing.
    public func captureMouse() {
        #if os(macOS)
        guard !isMouseCaptured else {
            return
        }
        CGDisplayHideCursor(CGMainDisplayID())
        CGAssociateMouseAndMouseCursorPosition(0)
        isMouseCaptured = true
        #endif
    }

    public func releaseMouse() {
        #if os(macOS)
        guard isMouseCaptured else {
            return
        }

        CGDisplayShowCursor(CGMainDisplayID())
        CGAssociateMouseAndMouseCursorPosition(1)

        isMouseCaptured = false
        #endif
    }

    private func registerMouse(_ mouse: GCMouse) {
        print("Registering mouse handlers")

        if let mouseInput = mouse.mouseInput {
            print("Mouse input available")

            mouseInput.mouseMovedHandler = { [weak self] _, deltaX, deltaY in
                self?.eventContinuation.yield(.look(deltaX: deltaX, deltaY: deltaY))
            }
            _ = mouseInput.capture()
            print("Mouse input is ready")
        } else {
            print("No mouse input available on this mouse device")
        }
    }
}
