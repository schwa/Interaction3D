@available(*, deprecated, message: "Use ChainedTransformer or | operator instead")
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
