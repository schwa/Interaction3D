import Foundation

public struct TransformerAnimator<Base: ParameterizedTransformer, Timing: Transformer, Value: Interpolatable> where Timing.Input == TimeInterval, Timing.Output == TimeInterval {
    public var transformer: Base
    public var parameter: WritableKeyPath<Base, Value>
    public var fromValue: Value
    public var toValue: Value
    public var timingTransformer: Timing
    public var duration: TimeInterval

    private var startTime: TimeInterval?

    public init(transformer: Base, parameter: WritableKeyPath<Base, Value>, from: Value, to: Value, duration: TimeInterval, timingTransformer: Timing) {
        self.duration = duration
        self.transformer = transformer
        self.parameter = parameter
        self.fromValue = from
        self.toValue = to
        self.timingTransformer = timingTransformer
    }

    public mutating func update(at currentTime: TimeInterval) {
        if startTime == nil {
            startTime = currentTime
        }

        guard let start = startTime else {
            return
        }

        let elapsed = currentTime - start
        let t = timingTransformer.transform(elapsed)

        interpolateParameter(t: t)
    }

    public mutating func reset() {
        startTime = nil
    }

    private mutating func interpolateParameter(t: Double) {
        let value = Value.interpolate(from: fromValue, to: toValue, t: t)
        transformer[keyPath: parameter] = value
    }
}

// MARK: -

public struct AnyTransformerAnimator<Base: ParameterizedTransformer, Value: Interpolatable> {
    public var transformer: Base
    public var parameter: WritableKeyPath<Base, Value>
    public var fromValue: Value
    public var toValue: Value
    public var duration: TimeInterval

    private var startTime: TimeInterval?
    private var applyTiming: (TimeInterval) -> Double

    public init<Timing: Transformer>(transformer: Base, parameter: WritableKeyPath<Base, Value>, from: Value, to: Value, duration: TimeInterval, timingTransformer: Timing) where Timing.Input == TimeInterval, Timing.Output == TimeInterval {
        self.duration = duration
        self.transformer = transformer
        self.parameter = parameter
        self.fromValue = from
        self.toValue = to
        self.applyTiming = { timingTransformer.transform($0) }
    }

    public mutating func update(at currentTime: TimeInterval) {
        if startTime == nil {
            startTime = currentTime
        }

        guard let start = startTime else {
            return
        }

        let elapsed = currentTime - start
        let t = applyTiming(elapsed)

        interpolateParameter(t: t)
    }

    public mutating func reset() {
        startTime = nil
    }

    private mutating func interpolateParameter(t: Double) {
        let value = Value.interpolate(from: fromValue, to: toValue, t: t)
        transformer[keyPath: parameter] = value
    }
}
