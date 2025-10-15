import Foundation

public struct TransformerAnimator<Transformer: ParameterizedTransformerProtocol, TimingTransformer: TransformerProtocol, Value: Interpolatable> where TimingTransformer.Value == TimeInterval {
    public var transformer: Transformer
    public var parameter: WritableKeyPath<Transformer, Value>
    public var fromValue: Value
    public var toValue: Value
    public var timingTransformer: TimingTransformer
    public var duration: TimeInterval

    private var startTime: TimeInterval?

    public init(transformer: Transformer, parameter: WritableKeyPath<Transformer, Value>, from: Value, to: Value, duration: TimeInterval, timingTransformer: TimingTransformer) {
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

        guard let start = startTime else { return }

        let elapsed = currentTime - start
        let t = timingTransformer.apply(to: elapsed)

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

public struct AnyTransformerAnimator<Transformer: ParameterizedTransformerProtocol, Value: Interpolatable> {
    public var transformer: Transformer
    public var parameter: WritableKeyPath<Transformer, Value>
    public var fromValue: Value
    public var toValue: Value
    public var duration: TimeInterval

    private var startTime: TimeInterval?
    private var applyTiming: (TimeInterval) -> Double

    public init<TimingTransformer: TransformerProtocol>(transformer: Transformer, parameter: WritableKeyPath<Transformer, Value>, from: Value, to: Value, duration: TimeInterval, timingTransformer: TimingTransformer) where TimingTransformer.Value == TimeInterval {
        self.duration = duration
        self.transformer = transformer
        self.parameter = parameter
        self.fromValue = from
        self.toValue = to
        self.applyTiming = { timingTransformer.apply(to: $0) }
    }

    public mutating func update(at currentTime: TimeInterval) {
        if startTime == nil {
            startTime = currentTime
        }

        guard let start = startTime else { return }

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
