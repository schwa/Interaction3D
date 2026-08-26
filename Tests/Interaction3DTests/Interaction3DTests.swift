import GeometryLite3D
@testable import Interaction3D
import simd
import SwiftUI
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

@MainActor
@Test func gameControllerMovementControllerDoesNotRetainItself() async {
    var controller: GameControllerMovementController? = GameControllerMovementController()
    weak let weakController = controller

    await Task.yield()
    controller = nil
    await Task.yield()

    #expect(weakController == nil)
}

@Test func angleOfViewRoundTripsAcrossAxes() {
    let angle = AngleOfView(verticalDegrees: 71, aspectRatio: 1.4)
    let vertical = AngleOfView.verticalDegrees(from: angle.horizontalDegrees, axis: .horizontal, aspectRatio: 1.4)

    #expect(abs(vertical - 71) < 0.0001)
}

@Test func cameraPoseRoundTripsMatrix() {
    let pose = CameraPose(position: [1, 2, 3], rotationDegrees: [12, -34, 5])
    let result = CameraPose(matrix: pose.matrix)

    #expect(length(result.position - pose.position) < 0.0001)
    #expect(length(result.rotationDegrees - pose.rotationDegrees) < 0.0001)
}

@Test func cameraMatrixSynchronizerRoundTripsPositionAndTarget() throws {
    let synchronizer = CameraMatrixSynchronizer(target: .zero)
    var matrix = matrix_identity_float4x4
    matrix.columns.3 = [2, 3, 5, 1]
    let state = try #require(synchronizer.interactionState(from: matrix))
    let result = synchronizer.cameraMatrix(from: state)

    #expect(abs(state.distance - length(SIMD3<Float>(2, 3, 5))) < 0.0001)
    #expect(length(result.columns.3.xyz - matrix.columns.3.xyz) < 0.0001)
    #expect(length(state.rotation.act([0, 0, -1]) - normalize(-matrix.columns.3.xyz)) < 0.0001)
}

@Test func cameraMatrixSynchronizerHandlesPoleAlignedCamera() throws {
    let synchronizer = CameraMatrixSynchronizer(target: .zero)
    var matrix = matrix_identity_float4x4
    matrix.columns.3 = [0, 5, 0, 1]
    let state = try #require(synchronizer.interactionState(from: matrix))
    let result = synchronizer.cameraMatrix(from: state)

    #expect(state.rotation.vector.x.isFinite)
    #expect(state.rotation.vector.y.isFinite)
    #expect(state.rotation.vector.z.isFinite)
    #expect(state.rotation.vector.w.isFinite)
    #expect(length(result.columns.3.xyz - matrix.columns.3.xyz) < 0.0001)
}

@Test func cameraMatrixSynchronizerHandlesCameraAtTarget() throws {
    let synchronizer = CameraMatrixSynchronizer(target: [1, 2, 3])
    let sourceRotation = simd_quatf(angle: 0.7, axis: [0, 1, 0])
    var matrix = sourceRotation.matrix
    matrix.columns.3 = [1, 2, 3, 1]
    let state = try #require(synchronizer.interactionState(from: matrix))

    #expect(state.distance == 0.01)
    #expect(abs(dot(state.rotation.vector, sourceRotation.vector)) > 0.9999)
}

@Test func cameraMatrixSynchronizerImportsExternalMatrixReplacement() throws {
    let synchronizer = CameraMatrixSynchronizer(target: .zero)
    var firstMatrix = matrix_identity_float4x4
    firstMatrix.columns.3 = [0, 0, 5, 1]
    var replacementMatrix = matrix_identity_float4x4
    replacementMatrix.columns.3 = [4, 0, 0, 1]

    let firstState = try #require(synchronizer.interactionState(from: firstMatrix))
    let replacementState = try #require(synchronizer.interactionState(from: replacementMatrix))

    #expect(firstState != replacementState)
    #expect(length(synchronizer.cameraMatrix(from: replacementState).columns.3.xyz - replacementMatrix.columns.3.xyz) < 0.0001)
}

@MainActor
@Test func fpvMovementIsIndependentOfRepeatedInputEvents() {
    var sparseController = FPVMovementController()
    sparseController.process(event: .axes(forward: 1, sideways: 0, source: .keyboard))
    sparseController.update(deltaTime: 1)

    var noisyController = FPVMovementController()
    for _ in 0..<100 {
        noisyController.process(event: .axes(forward: 1, sideways: 0, source: .keyboard))
    }
    noisyController.update(deltaTime: 1)

    #expect(length(sparseController.movementController.transform.columns.3.xyz - noisyController.movementController.transform.columns.3.xyz) < 0.0001)
}

@MainActor
@Test func fpvMovementCombinesAndNormalizesInputSources() {
    var controller = FPVMovementController()
    controller.process(event: .axes(forward: 1, sideways: 0, source: .keyboard))
    controller.process(event: .axes(forward: 0, sideways: 1, source: .controller))
    controller.update(deltaTime: 1)

    let position = controller.movementController.transform.columns.3.xyz
    #expect(abs(length(position) - controller.speed) < 0.0001)
    #expect(position.x > 0)
    #expect(position.z < 0)
}

@MainActor
@Test func fpvMovementStopsOnNeutralInput() {
    var controller = FPVMovementController()
    controller.process(event: .axes(forward: 1, sideways: 0, source: .keyboard))
    controller.update(deltaTime: 1)
    let movingPosition = controller.movementController.transform.columns.3.xyz

    controller.process(event: .axes(forward: 0, sideways: 0, source: .keyboard))
    controller.update(deltaTime: 1)

    #expect(controller.movementController.transform.columns.3.xyz == movingPosition)
    #expect(controller.movementController.linearVelocity == .zero)
}

@MainActor
@Test func fpvMovementClampsPitchDuringExplicitUpdate() {
    var controller = FPVMovementController()
    controller.process(event: .controllerState(move: .zero, look: [0, -1], altitude: 0))
    controller.update(deltaTime: 10)

    #expect(abs(controller.pitch - (.pi / 2 - 0.01)) < 0.0001)
}

@Test func worldViewDerivesFlightSimulationFieldOfViewFromPerspectiveProjection() {
    let projection = PerspectiveProjection(verticalAngleOfView: .degrees(75))
    let fieldOfView = WorldViewProjectionCapabilities.verticalFOV(for: projection, override: nil)

    #expect(fieldOfView == 75)
}

@Test func worldViewRequiresExplicitFieldOfViewForOtherProjections() {
    let projection = TestProjection()

    #expect(WorldViewProjectionCapabilities.verticalFOV(for: projection, override: nil) == nil)
    #expect(WorldViewProjectionCapabilities.verticalFOV(for: projection, override: 42) == 42)
}

private struct TestProjection: ProjectionProtocol {
    func projectionMatrix(aspectRatio: Float) -> float4x4 {
        matrix_identity_float4x4
    }
}

@Test func softwareProjectionMapsNormalizedCoordinatesToScreen() {
    let projection = SoftwareProjection(
        viewMatrix: .identity,
        projectionMatrix: .identity,
        clipToScreenMatrix: .clipToScreen(width: 200, height: 100)
    )

    #expect(projection.project([0, 0, 0]) == [100, 50])
    #expect(projection.project([1, 1, 0]) == [200, 0])
}

@Test func softwareProjectionRejectsInvalidAndBehindCameraPoints() {
    let perspective = PerspectiveProjection(verticalAngleOfView: .degrees(60))
    let projection = SoftwareProjection(
        viewMatrix: .identity,
        projectionMatrix: perspective.projectionMatrix(aspectRatio: 1),
        clipToScreenMatrix: .identity
    )

    #expect(projection.project([0, 0, -1]) != nil)
    #expect(projection.project([0, 0, 1]) == nil)
    #expect(projection.project([.nan, 0, -1]) == nil)
}

@Test func softwareProjectionRejectsPartiallyUnprojectablePolygons() {
    let perspective = PerspectiveProjection(verticalAngleOfView: .degrees(60))
    let projection = SoftwareProjection(
        viewMatrix: .identity,
        projectionMatrix: perspective.projectionMatrix(aspectRatio: 1),
        clipToScreenMatrix: .identity
    )

    let polygon: [SIMD3<Float>] = [[-1, -1, -1], [1, -1, -1], [0, 1, 1]]
    #expect(projection.project(polygon: polygon).isEmpty)
}

@MainActor
@Test func interactiveCameraPublicAPIIsSourceCompatible() {
    let rotation = Binding.constant(simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0)))
    let distance = Binding.constant(Float(5))
    let target = Binding.constant(SIMD3<Float>.zero)
    let matrix = Binding.constant(matrix_identity_float4x4)

    _ = Color.clear.interactiveCamera(rotation: rotation, distance: distance, target: target)
    _ = Color.clear.interactiveCamera(cameraMatrix: matrix)
}

@Test func cameraScrollAndMagnifyZoomUseIndependentEquivalentScales() {
    let zoom: InteractionAxisTransforms.AxisTransform = { $0 * 2 }
    let transforms = InteractionAxisTransforms(zoom: zoom)
    let scroll = CameraZoomTransformer(transforms: transforms, magnitude: 1)
    let magnify = CameraZoomTransformer(transforms: transforms, magnitude: 100)

    #expect(scroll.transform(5) == magnify.transform(0.05))
}

@Test func cameraRotationSessionTracksDeltasAndCompletion() {
    var session = CameraRotationSession()
    let rotation = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
    let firstDrag = CoreDragValue(
        translation: CGSize(width: 10, height: 4),
        startLocation: CGPoint(x: 20, y: 20),
        currentLocation: CGPoint(x: 30, y: 24)
    )
    let secondDrag = CoreDragValue(
        translation: CGSize(width: 15, height: 9),
        startLocation: CGPoint(x: 20, y: 20),
        currentLocation: CGPoint(x: 35, y: 29)
    )

    let firstInput = session.input(for: firstDrag, rotation: rotation, mode: .turntable(), viewSize: .zero)
    let secondInput = session.input(for: secondDrag, rotation: rotation, mode: .turntable(), viewSize: .zero)
    #expect(firstInput.rotation == CGSize(width: 10, height: 4))
    #expect(secondInput.rotation == CGSize(width: 5, height: 5))

    session.end()
    #expect(session.rotationAtDragStart == nil)
    let restartedInput = session.input(for: firstDrag, rotation: rotation, mode: .turntable(), viewSize: .zero)
    #expect(restartedInput.rotation == firstDrag.translation)
}

@Test func cameraRotationSessionSuppliesArcballPositions() {
    var session = CameraRotationSession()
    let rotation = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
    let drag = CoreDragValue(
        translation: CGSize(width: 50, height: 0),
        startLocation: CGPoint(x: 25, y: 50),
        currentLocation: CGPoint(x: 75, y: 50)
    )
    let input = session.input(
        for: drag,
        rotation: rotation,
        mode: .arcball(),
        viewSize: CGSize(width: 100, height: 100)
    )
    let result = ArcballTransformer(input: input).transform(InteractionState(rotation: rotation))

    #expect(input.startLocation == drag.startLocation)
    #expect(input.currentLocation == drag.currentLocation)
    #expect(abs(result.rotation.real) < 0.9999)
}

@Test func cameraPanUsesConfiguredTransform() {
    let pan: InteractionAxisTransforms.PanTransform = { SIMD3(Float($0.x * 2), Float($0.y * 3), 0) }
    let transforms = InteractionAxisTransforms(pan: pan)
    let transformer = CameraPanTransformer(transforms: transforms)

    #expect(transformer.transform(CGSize(width: 4, height: 5)) == SIMD3<Float>(8, 15, 0))
}

private extension SIMD4<Float> {
    var xyz: SIMD3<Float> {
        SIMD3<Float>(x, y, z)
    }
}
