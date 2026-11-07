#if os(macOS)

import AppKit
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
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if isMouseCaptured {
            CGDisplayShowCursor(CGMainDisplayID())
            CGAssociateMouseAndMouseCursorPosition(1)
        }
    }

    func keyboardAxes() -> (forward: Float, sideways: Float) {
        guard isKeyboardEnabled else {
            return (0, 0)
        }
        var forward: Float = 0
        var sideways: Float = 0
        if isKeyPressed(.keyW) { forward += 1 }
        if isKeyPressed(.keyS) { forward -= 1 }
        if isKeyPressed(.keyD) { sideways += 1 }
        if isKeyPressed(.keyA) { sideways -= 1 }
        return (forward, sideways)
    }

    private func startTimerLoop() {
        timerTask = Task { [weak self] in
            for await _ in AsyncTimerSequence(interval: .milliseconds(16), clock: .continuous) {
                guard let self else {
                    return
                }

                let axes = keyboardAxes()
                eventContinuation.yield(.axes(forward: axes.forward, sideways: axes.sideways, source: .keyboard))
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
                print("No mouse/trackpad found - setting up NSEvent monitor")
                setupNSEventMonitor()
            }
        }
    }

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

    public func toggleMouseCapture() {
        if isMouseCaptured {
            releaseMouse()
        } else {
            captureMouse()
        }
    }

    public func captureMouse() {
        guard !isMouseCaptured else {
            return
        }
        CGDisplayHideCursor(CGMainDisplayID())
        CGAssociateMouseAndMouseCursorPosition(0)
        isMouseCaptured = true
    }

    public func releaseMouse() {
        guard isMouseCaptured else {
            return
        }

        CGDisplayShowCursor(CGMainDisplayID())
        CGAssociateMouseAndMouseCursorPosition(1)

        isMouseCaptured = false
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

#endif
