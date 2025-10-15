#if os(macOS)

import AppKit
import AsyncAlgorithms
import CoreGraphics
import GameController
import Observation
import SwiftUI

@Observable
public final class WASDController: @unchecked Sendable {
    @ObservationIgnored
    private var eventContinuation: AsyncStream<NavigationEvent>.Continuation?

    @ObservationIgnored
    private var _events: AsyncStream<NavigationEvent>?

    @ObservationIgnored
    private var keyboardObservationTask: Task<Void, Never>?

    @ObservationIgnored
    private var mouseObservationTask: Task<Void, Never>?

    @ObservationIgnored
    private var timerTask: Task<Void, Never>?

    @ObservationIgnored
    private var mouseMonitor: Any?

    public var isMouseCaptured = false

    public var events: AsyncStream<NavigationEvent> {
        if let events = _events {
            return events
        }

        let stream = AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            self.eventContinuation = continuation
            self.startTimerLoop()
        }
        _events = stream
        return stream
    }

    public init() {
        setupKeyboardHandling()
        setupMouseHandling()
    }

    deinit {
        keyboardObservationTask?.cancel()
        mouseObservationTask?.cancel()
        timerTask?.cancel()
        eventContinuation?.finish()
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if isMouseCaptured {
            CGDisplayShowCursor(CGMainDisplayID())
            CGAssociateMouseAndMouseCursorPosition(1)
        }
    }

    func snapshot() -> GCKeyboardInput? {
        GCKeyboard.coalesced?.keyboardInput?.capture()
    }

    private func startTimerLoop() {
        timerTask = Task { @Sendable [weak self] in
            for await _ in AsyncTimerSequence(interval: .milliseconds(16), clock: .continuous) {
                guard let self else {
                    return
                }

                var forwardAxis: Float = 0
                var sidewaysAxis: Float = 0

                if let snapshot = snapshot() {
                    let w = snapshot.button(forKeyCode: .keyW)?.isPressed ?? false
                    let s = snapshot.button(forKeyCode: .keyS)?.isPressed ?? false
                    let a = snapshot.button(forKeyCode: .keyA)?.isPressed ?? false
                    let d = snapshot.button(forKeyCode: .keyD)?.isPressed ?? false

                    if w { forwardAxis += 1 }
                    if s { forwardAxis -= 1 }

                    if d { sidewaysAxis += 1 }
                    if a { sidewaysAxis -= 1 }
                }

                eventContinuation?.yield(.axes(forward: forwardAxis, sideways: sidewaysAxis, source: .keyboard))
            }
        }
    }

    private func setupKeyboardHandling() {
        keyboardObservationTask = Task { @Sendable [weak self] in
            for await notification in NotificationCenter.default.notifications(named: .GCKeyboardDidConnect) {
                if let keyboard = notification.object as? GCKeyboard {
                    // This line intentionally left blank
                }
            }
        }

        if let keyboard = GCKeyboard.coalesced {
            // This line intentionally left blank
        }
    }

    private func setupMouseHandling() {
        mouseObservationTask = Task {
            Task { [weak self] in
                for await notification in NotificationCenter.default.notifications(named: .GCMouseDidConnect) {
                    print("Mouse connected via notification")
                    if let mouse = notification.object as? GCMouse {
                        self?.registerMouse(mouse)
                    }
                }
            }
            Task { [weak self] in
                for await notification in NotificationCenter.default.notifications(named: .GCMouseDidBecomeCurrent) {
                    if let mouse = notification.object as? GCMouse {
                        self?.registerMouse(mouse)
                    }
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
                    eventContinuation?.yield(.look(deltaX: Float(deltaX), deltaY: Float(deltaY)))
                }
            default:
                break
            }

            return event
        }
    }

    public func toggleMouseCapture() {
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            if isMouseCaptured {
                releaseMouse()
            } else {
                captureMouse()
            }
        }
    }

    @MainActor
    public func captureMouse() {
        guard !isMouseCaptured else {
            return
        }
        let hideResult = CGDisplayHideCursor(CGMainDisplayID())
        let associateResult = CGAssociateMouseAndMouseCursorPosition(0)
        isMouseCaptured = true
    }

    @MainActor
    public func releaseMouse() {
        guard isMouseCaptured else {
            return
        }

        let showResult = CGDisplayShowCursor(CGMainDisplayID())

        let associateResult = CGAssociateMouseAndMouseCursorPosition(1)

        isMouseCaptured = false
    }

    private func registerMouse(_ mouse: GCMouse) {
        print("Registering mouse handlers")

        if let mouseInput = mouse.mouseInput {
            print("Mouse input available")

            mouseInput.mouseMovedHandler = { [weak self] input, deltaX, deltaY in
                self?.eventContinuation?.yield(.look(deltaX: deltaX, deltaY: deltaY))
            }
            _ = mouseInput.capture()
            print("Mouse input is ready")
        } else {
            print("No mouse input available on this mouse device")
        }
    }
}

#endif
