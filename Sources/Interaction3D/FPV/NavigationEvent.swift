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
}
