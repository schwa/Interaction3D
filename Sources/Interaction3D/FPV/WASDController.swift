import AsyncAlgorithms
import CoreGraphics
import GameController
import Observation
import SwiftUI

@Observable
@MainActor
final class WASDController {
    @ObservationIgnored
    private let eventContinuation: AsyncStream<NavigationEvent>.Continuation

    @ObservationIgnored
    let events: AsyncStream<NavigationEvent>

    @ObservationIgnored
    private var mouseConnectTask: Task<Void, Never>?

    @ObservationIgnored
    private var mouseBecameCurrentTask: Task<Void, Never>?

    @ObservationIgnored
    private var timerTask: Task<Void, Never>?

    @ObservationIgnored
    private var mouseMonitor: Any?

    var isMouseCaptured = false

    // GCKeyboard is global, so the owning view must clear this when it loses focus.
    @ObservationIgnored
    var isKeyboardEnabled = true

    @ObservationIgnored
    var extraControls: FPVExtraControls = []

    @ObservationIgnored
    var isKeyPressed: (GCKeyCode) -> Bool = { keyCode in
        GCKeyboard.coalesced?.keyboardInput?.button(forKeyCode: keyCode)?.isPressed ?? false
    }

    // AppKit is needed for mouse button state, cursor capture, and the fallback mouse monitor;
    // SwiftUI has no API for global pointer deltas or hiding/locking the cursor.
    @ObservationIgnored
    var isRightMouseButtonPressed: () -> Bool = {
        #if canImport(AppKit)
        NSEvent.pressedMouseButtons & (1 << 1) != 0
        #else
        GCMouse.current?.mouseInput?.rightButton?.isPressed ?? false
        #endif
    }

    @ObservationIgnored
    private var previousSpeedKeys: Float = 0

    @ObservationIgnored
    private var wasResetPressed = false

    init() {
        (events, eventContinuation) = AsyncStream.makeStream(of: NavigationEvent.self, bufferingPolicy: .bufferingNewest(32))
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
        var altitude = axis(.keyE, .keyQ)
        if extraControls.contains(.alternativeVertical) {
            let up = !extraControls.contains(.jump) && isKeyPressed(.spacebar)
            let down = isKeyPressed(.leftControl) || isKeyPressed(.rightControl)
            altitude = max(-1, min(1, altitude + (up ? 1 : 0) - (down ? 1 : 0)))
        }
        let isFast = isKeyPressed(.leftShift) || isKeyPressed(.rightShift)
        return (move, look, altitude, isFast)
    }

    func extraKeyboardState() -> (roll: Float, isSlow: Bool, isLookHeld: Bool) {
        let isLookHeld = !extraControls.contains(.holdToLook) || isRightMouseButtonPressed()
        guard isKeyboardEnabled else {
            return (0, false, isLookHeld)
        }
        var roll: Float = 0
        if extraControls.contains(.roll) {
            roll = (isKeyPressed(.keyC) ? 1 : 0) - (isKeyPressed(.keyZ) ? 1 : 0)
        }
        let isSlow = extraControls.contains(.slowModifier) && (isKeyPressed(.leftAlt) || isKeyPressed(.rightAlt))
        return (roll, isSlow, isLookHeld)
    }

    // Returns +1/-1 once per +/- press.
    func speedKeySteps() -> Float {
        guard isKeyboardEnabled, extraControls.contains(.speedAdjustment) else {
            previousSpeedKeys = 0
            return 0
        }
        let plus = isKeyPressed(.equalSign) || isKeyPressed(.keypadPlus)
        let minus = isKeyPressed(.hyphen) || isKeyPressed(.keypadHyphen)
        let current: Float = (plus ? 1 : 0) - (minus ? 1 : 0)
        defer { previousSpeedKeys = current }
        return current != previousSpeedKeys ? current : 0
    }

    func isJumpPressed() -> Bool {
        isKeyboardEnabled && extraControls.contains(.jump) && isKeyPressed(.spacebar)
    }

    func isResetTriggered() -> Bool {
        let pressed = isKeyboardEnabled && extraControls.contains(.resetKey) && isKeyPressed(.home)
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
                eventContinuation.yield(.keyboardState(move: state.move, look: state.look, altitude: state.altitude, isFast: state.isFast))
                if !extraControls.isEmpty {
                    let extra = extraKeyboardState()
                    eventContinuation.yield(.extraKeyboardState(roll: extra.roll, isSlow: extra.isSlow, isLookHeld: extra.isLookHeld))
                    let steps = speedKeySteps()
                    if steps != 0 {
                        eventContinuation.yield(.adjustSpeed(steps: steps))
                    }
                    if isResetTriggered() {
                        eventContinuation.yield(.reset)
                    }
                    if extraControls.contains(.jump) {
                        eventContinuation.yield(.jumpState(isPressed: isJumpPressed()))
                    }
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

        if let mouse = GCMouse.current {
            registerMouse(mouse)
        } else {
            let mice = GCMouse.mice()
            if let mouse = mice.first {
                registerMouse(mouse)
            } else {
                #if canImport(AppKit)
                setupNSEventMonitor()
                #endif
            }
        }
    }

    #if canImport(AppKit)
    private func setupNSEventMonitor() {
        mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .scrollWheel]) { [weak self] event in
            guard let self else {
                return event
            }

            switch event.type {
            case .mouseMoved:
                let deltaX = event.deltaX
                let deltaY = event.deltaY
                if deltaX != 0 || deltaY != 0 {
                    // NSEvent +Y is down; flip to match GCMouse.
                    eventContinuation.yield(.look(deltaX: Float(deltaX), deltaY: Float(-deltaY)))
                }
            case .scrollWheel:
                if event.scrollingDeltaY != 0, isKeyboardEnabled, extraControls.contains(.speedAdjustment) {
                    eventContinuation.yield(.adjustSpeed(steps: event.scrollingDeltaY > 0 ? 1 : -1))
                }
            default:
                break
            }

            return event
        }
    }
    #endif

    func toggleMouseCapture() {
        if isMouseCaptured {
            releaseMouse()
        } else {
            captureMouse()
        }
    }

    // Cursor capture is macOS-only; elsewhere these do nothing.
    func captureMouse() {
        #if canImport(AppKit)
        guard !isMouseCaptured else {
            return
        }
        CGDisplayHideCursor(CGMainDisplayID())
        CGAssociateMouseAndMouseCursorPosition(0)
        isMouseCaptured = true
        #endif
    }

    func releaseMouse() {
        #if canImport(AppKit)
        guard isMouseCaptured else {
            return
        }

        CGDisplayShowCursor(CGMainDisplayID())
        CGAssociateMouseAndMouseCursorPosition(1)

        isMouseCaptured = false
        #endif
    }

    private func registerMouse(_ mouse: GCMouse) {
        if let mouseInput = mouse.mouseInput {
            mouseInput.mouseMovedHandler = { [weak self] _, deltaX, deltaY in
                self?.eventContinuation.yield(.look(deltaX: deltaX, deltaY: deltaY))
            }
            mouseInput.scroll.yAxis.valueChangedHandler = { [weak self] _, value in
                guard let self, value != 0, isKeyboardEnabled, extraControls.contains(.speedAdjustment) else {
                    return
                }
                eventContinuation.yield(.adjustSpeed(steps: value > 0 ? 1 : -1))
            }
            _ = mouseInput.capture()
        }
    }
}
