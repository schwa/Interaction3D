import simd

public struct RotationTransformer: Transformer {
    public let deadzone: Float
    public let scale: Float
    public let curve: AccelerationCurveTransformer.Curve
    public let reverseX: Bool
    public let reverseY: Bool

    public init(deadzone: Float = 0.15, scale: Float = 1, curve: AccelerationCurveTransformer.Curve = .quadratic, reverseX: Bool = true, reverseY: Bool = true) {
        self.deadzone = deadzone
        self.scale = scale
        self.curve = curve
        self.reverseX = reverseX
        self.reverseY = reverseY
    }

    public func transform(_ input: SIMD2<Float>) -> SIMD2<Float> {
        let magnitude = length(input)

        if magnitude < deadzone {
            return .zero
        }

        let normalized = input / magnitude
        let compensatedMagnitude = (magnitude - deadzone) / (1 - deadzone)

        let curvedMagnitude: Float
        switch curve {
        case .linear:
            curvedMagnitude = compensatedMagnitude
        case .quadratic:
            curvedMagnitude = compensatedMagnitude * compensatedMagnitude
        case .cubic:
            curvedMagnitude = compensatedMagnitude * compensatedMagnitude * compensatedMagnitude
        case .exponential(let power):
            curvedMagnitude = pow(compensatedMagnitude, power)
        }

        var result = normalized * curvedMagnitude * scale

        if reverseX {
            result.x = -result.x
        }
        if reverseY {
            result.y = -result.y
        }

        result.x = min(max(result.x, -scale), scale)
        result.y = min(max(result.y, -scale), scale)

        return result
    }
}
