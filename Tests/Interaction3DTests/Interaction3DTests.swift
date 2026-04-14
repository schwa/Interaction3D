@testable import Interaction3D
import simd
import Testing

@Test func anyTransformerParameterStoresAndRetrievesValues() {
    var transformer = LerpPositionTransformer(start: [1, 2, 3], end: [4, 5, 6], t: 0.5)
    let param = AnyTransformerParameter<LerpPositionTransformer>(keyPath: \LerpPositionTransformer.start, name: "start")

    // swiftlint:disable:next force_cast
    let value = param.getValue(transformer) as! SIMD3<Float>
    #expect(value == SIMD3<Float>(1, 2, 3))

    param.setValue(&transformer, SIMD3<Float>(7, 8, 9))
    #expect(transformer.start == SIMD3<Float>(7, 8, 9))
}

@Test func lerpPositionConstraintParameters() {
    let params = LerpPositionTransformer.parameters
    #expect(params.count == 3)
    #expect(params[0].name == "start")
    #expect(params[1].name == "end")
    #expect(params[2].name == "t")
}

@Test func lerpPositionConstraintApply() {
    let constraint = LerpPositionTransformer(start: [0, 0, 0], end: [10, 20, 30], t: 0.5)
    let result = constraint.transform([0, 0, 0])
    #expect(result == SIMD3<Float>(5, 10, 15))
}

@Test func lerpPositionConstraintApplyAtExtremes() {
    var constraint = LerpPositionTransformer(start: [1, 2, 3], end: [4, 5, 6], t: 0)
    var result = constraint.transform([0, 0, 0])
    #expect(result == SIMD3<Float>(1, 2, 3))

    constraint.t = 1
    result = constraint.transform([0, 0, 0])
    #expect(result == SIMD3<Float>(4, 5, 6))
}
