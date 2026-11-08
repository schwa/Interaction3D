public enum NavigationEvent: Sendable {
    public enum AxisSource: Sendable {
        case keyboard
        case controller
    }

    public enum LookSource: Sendable {
        case mouse
        case controller
    }

    case axes(forward: Float, sideways: Float, source: AxisSource = .keyboard)
    case look(deltaX: Float, deltaY: Float, source: LookSource = .mouse)
    case altitude(value: Float, source: AxisSource = .controller)
    case controllerState(move: SIMD2<Float>, look: SIMD2<Float>, altitude: Float)
    // look.x is right minus left, look.y is up minus down (positive looks up).
    case keyboardState(move: SIMD2<Float>, look: SIMD2<Float>, altitude: Float, isFast: Bool)
    // Opt-in controls from FPVExtraControls. roll is right minus left.
    // isLookHeld gates mouse look and keyboard movement; it is always true unless hold-to-look is on.
    case extraKeyboardState(roll: Float, isSlow: Bool, isLookHeld: Bool)
    // Multiplies speed by speedAdjustmentFactor^steps.
    case adjustSpeed(steps: Float)
    case reset
}

public struct FPVExtraControls: OptionSet, Hashable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    // Mouse wheel and +/- change the base speed.
    public static let speedAdjustment = Self(rawValue: 1 << 0)
    // Option (Alt) moves slowly.
    public static let slowModifier = Self(rawValue: 1 << 1)
    // Z/C roll left/right.
    public static let roll = Self(rawValue: 1 << 2)
    // Space/Control move up/down, in addition to E/Q.
    public static let alternativeVertical = Self(rawValue: 1 << 3)
    // Home resets the view.
    public static let resetKey = Self(rawValue: 1 << 4)
    // Look and move only while the right mouse button is held.
    public static let holdToLook = Self(rawValue: 1 << 5)

    public static let all: Self = [.speedAdjustment, .slowModifier, .roll, .alternativeVertical, .resetKey, .holdToLook]
}
