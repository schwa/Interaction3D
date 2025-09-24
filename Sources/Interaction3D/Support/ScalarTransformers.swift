import Foundation

public struct DeadzoneTransformer: Transformer {
    public let deadzone: Float

    public init(deadzone: Float = 0.1) {
        self.deadzone = deadzone
    }

    public func transform(_ input: Float) -> Float {
        if abs(input) < deadzone {
            return 0
        }
        let sign = input > 0 ? Float(1) : Float(-1)
        let normalized = (abs(input) - deadzone) / (1 - deadzone)
        return sign * normalized
    }
}

public struct AccelerationCurveTransformer: Transformer {
    public enum Curve {
        case linear
        case quadratic
        case cubic
        case exponential(Float)
    }

    public let curve: Curve

    public init(curve: Curve = .quadratic) {
        self.curve = curve
    }

    public func transform(_ input: Float) -> Float {
        let sign = input > 0 ? Float(1) : Float(-1)
        let magnitude = abs(input)

        let result: Float
        switch curve {
        case .linear:
            result = magnitude
        case .quadratic:
            result = magnitude * magnitude
        case .cubic:
            result = magnitude * magnitude * magnitude
        case .exponential(let power):
            result = pow(magnitude, power)
        }
        return sign * result
    }
}

public struct ReverseTransformer: Transformer {
    public init() {
        // This line intentionally left blank
    }

    public func transform(_ input: Float) -> Float {
        -input
    }
}

public struct ScaleTransformer: Transformer {
    public let scale: Float

    public init(scale: Float) {
        self.scale = scale
    }

    public func transform(_ input: Float) -> Float {
        input * scale
    }
}

public struct ClampTransformer: Transformer {
    public let min: Float
    public let max: Float

    public init(min: Float = -1, max: Float = 1) {
        self.min = min
        self.max = max
    }

    public func transform(_ input: Float) -> Float {
        Swift.min(Swift.max(input, min), max)
    }
}
