import Foundation
import simd

public protocol Transformer {
    associatedtype Input
    associatedtype Output

    func transform(_ input: Input) -> Output
}

public struct CompositeTransformer<T>: Transformer {
    private let transformFunction: (T) -> T

    public init<T1: Transformer>(_ transformer: T1) where T1.Input == T, T1.Output == T {
        self.transformFunction = transformer.transform
    }

    public init<T1: Transformer, T2: Transformer>(_ t1: T1, _ t2: T2) where T1.Input == T, T1.Output == T2.Input, T2.Output == T {
        self.transformFunction = { input in
            t2.transform(t1.transform(input))
        }
    }

    public init<T1: Transformer, T2: Transformer, T3: Transformer>(_ t1: T1, _ t2: T2, _ t3: T3) where T1.Input == T, T1.Output == T2.Input, T2.Output == T3.Input, T3.Output == T {
        self.transformFunction = { input in
            t3.transform(t2.transform(t1.transform(input)))
        }
    }

    public init(transform: @escaping (T) -> T) {
        self.transformFunction = transform
    }

    public func transform(_ input: T) -> T {
        transformFunction(input)
    }

    public func then<Next: Transformer>(_ next: Next) -> Self where Next.Input == T, Next.Output == T {
        Self { input in
            next.transform(transform(input))
        }
    }
}

public struct IdentityTransformer<T>: Transformer {
    public init() {
        // This line intentionally left blank
    }

    public func transform(_ input: T) -> T {
        input
    }
}

public struct AnyTransformer<Input, Output>: Transformer {
    private let transformFunction: (Input) -> Output

    public init<T: Transformer>(_ transformer: T) where T.Input == Input, T.Output == Output {
        self.transformFunction = transformer.transform
    }

    public init(_ transform: @escaping (Input) -> Output) {
        self.transformFunction = transform
    }

    public func transform(_ input: Input) -> Output {
        transformFunction(input)
    }
}

// MARK: - Vector Transformers

public struct MovementTransformer: Transformer {
    public let deadzone: Float
    public let scale: Float
    public let curve: AccelerationCurveTransformer.Curve
    public let reverseY: Bool

    public init(deadzone: Float = 0.15, scale: Float = 1, curve: AccelerationCurveTransformer.Curve = .quadratic, reverseY: Bool = true) {
        self.deadzone = deadzone
        self.scale = scale
        self.curve = curve
        self.reverseY = reverseY
    }

    public func transform(_ input: SIMD2<Float>) -> SIMD2<Float> {
        let magnitude = length(input)

        // Apply deadzone to the overall magnitude
        if magnitude < deadzone {
            return .zero
        }

        // Normalize and apply deadzone compensation
        let normalized = input / magnitude
        let compensatedMagnitude = (magnitude - deadzone) / (1 - deadzone)

        // Apply acceleration curve to the magnitude
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

        // Reconstruct the vector with the curved magnitude
        var result = normalized * curvedMagnitude * scale

        // Reverse Y if needed
        if reverseY {
            result.y = -result.y
        }

        // Clamp to reasonable values
        result.x = min(max(result.x, -scale), scale)
        result.y = min(max(result.y, -scale), scale)

        return result
    }
}

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

        // Apply deadzone to the overall magnitude
        if magnitude < deadzone {
            return .zero
        }

        // Normalize and apply deadzone compensation
        let normalized = input / magnitude
        let compensatedMagnitude = (magnitude - deadzone) / (1 - deadzone)

        // Apply acceleration curve to the magnitude
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

        // Reconstruct the vector with the curved magnitude
        var result = normalized * curvedMagnitude * scale

        // Apply reversal
        if reverseX {
            result.x = -result.x
        }
        if reverseY {
            result.y = -result.y
        }

        // Clamp to reasonable values
        result.x = min(max(result.x, -scale), scale)
        result.y = min(max(result.y, -scale), scale)

        return result
    }
}
