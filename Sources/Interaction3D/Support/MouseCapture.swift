import CoreGraphics
import Observation

// Hides the cursor and locks the pointer so mouse movement only produces deltas (for mouse look).
// macOS only; elsewhere capture() does nothing. Released when this object goes away.
@Observable
@MainActor
public final class MouseCapture {
    public private(set) var isCaptured = false

    // Applies the capture state to the system. Tests replace it so they don't hide the real cursor.
    @ObservationIgnored
    var apply: @MainActor (Bool) -> Void = MouseCapture.applyToSystem

    public init() {
        // Starts released.
    }

    isolated deinit {
        if isCaptured {
            apply(false)
        }
    }

    public func capture() {
        #if canImport(AppKit)
        guard !isCaptured else {
            return
        }
        apply(true)
        isCaptured = true
        #endif
    }

    public func release() {
        guard isCaptured else {
            return
        }
        apply(false)
        isCaptured = false
    }

    public func toggle() {
        if isCaptured {
            release()
        } else {
            capture()
        }
    }

    nonisolated private static func applyToSystem(_ captured: Bool) {
        #if canImport(AppKit)
        if captured {
            CGDisplayHideCursor(CGMainDisplayID())
            CGAssociateMouseAndMouseCursorPosition(0)
        } else {
            CGDisplayShowCursor(CGMainDisplayID())
            CGAssociateMouseAndMouseCursorPosition(1)
        }
        #endif
    }
}
