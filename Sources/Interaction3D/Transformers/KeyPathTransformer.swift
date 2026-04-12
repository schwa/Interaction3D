public struct KeyPathTransformer <Input, Output>: Transformer {
    let keyPath: KeyPath<Input, Output>

    public init(keyPath: KeyPath<Input, Output>) {
        self.keyPath = keyPath
    }

    public func transform(_ value: Input) -> Output {
        value[keyPath: keyPath]
    }
}
