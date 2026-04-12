//
//  ChainedTransformer.swift
//  Interaction3D
//
//  Created by Jonathan Wight on 4/11/26.
//


public struct ChainedTransformer<A: Transformer, B: Transformer>: Transformer where A.Output == B.Input {
    public let first: A
    public let second: B

    public func transform(_ input: A.Input) -> B.Output {
        second.transform(first.transform(input))
    }
}

public func | <A: Transformer, B: Transformer>(lhs: A, rhs: B) -> ChainedTransformer<A, B> where A.Output == B.Input {
    ChainedTransformer(first: lhs, second: rhs)
}
