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

@MainActor
@Test func fpvKeyboardMovesVerticallyAndFaster() {
    var controller = FPVMovementController()
    controller.process(event: .keyboardState(move: .zero, look: .zero, altitude: 1, isFast: false))
    controller.update(deltaTime: 1)
    #expect(controller.movementController.transform.columns.3.y == controller.speed)

    controller.reset()
    controller.process(event: .keyboardState(move: [0, 1], look: .zero, altitude: 0, isFast: true))
    controller.update(deltaTime: 1)
    let distance = simd_length(controller.movementController.transform.columns.3.xyz)
    #expect(abs(distance - controller.speed * controller.fastSpeedMultiplier) < 0.0001)
}

@MainActor
@Test func fpvFreeFlightMovesAlongViewDirection() {
    var controller = FPVMovementController()
    controller.process(event: .keyboardState(move: .zero, look: [0, 1], altitude: 0, isFast: false))
    controller.update(deltaTime: 0.5)
    controller.process(event: .keyboardState(move: [0, 1], look: .zero, altitude: 0, isFast: false))
    controller.update(deltaTime: 1)
    #expect(controller.movementController.transform.columns.3.y == 0)

    controller.isFreeFlightEnabled = true
    controller.update(deltaTime: 1)
    #expect(controller.movementController.transform.columns.3.y > 0)
}

@MainActor
@Test func fpvExtraControls() {
    var controller = FPVMovementController()
    controller.process(event: .adjustSpeed(steps: 1))
    #expect(abs(controller.speed - 12.5) < 0.0001)

    controller.speed = 10
    controller.process(event: .extraKeyboardState(roll: 0, isSlow: true, isLookHeld: true))
    controller.process(event: .keyboardState(move: [0, 1], look: .zero, altitude: 0, isFast: false))
    controller.update(deltaTime: 1)
    #expect(abs(simd_length(controller.movementController.transform.columns.3.xyz) - 2.5) < 0.0001)

    controller.reset()
    controller.process(event: .extraKeyboardState(roll: 0, isSlow: false, isLookHeld: false))
    controller.process(event: .keyboardState(move: [0, 1], look: .zero, altitude: 1, isFast: false))
    controller.process(event: .look(deltaX: 10, deltaY: 10))
    controller.update(deltaTime: 1)
    #expect(controller.movementController.transform == matrix_identity_float4x4)

    controller.reset()
    controller.process(event: .extraKeyboardState(roll: 1, isSlow: false, isLookHeld: true))
    controller.update(deltaTime: 1)
    #expect(controller.roll == 0)
    controller.isRollEnabled = true
    controller.process(event: .extraKeyboardState(roll: 1, isSlow: false, isLookHeld: true))
    controller.update(deltaTime: 0.5)
    // Rolling right tilts the camera's right vector down.
    #expect(controller.movementController.transform.columns.0.y < 0)

    var copy = FPVMovementController()
    copy.isRollEnabled = true
    copy.setPose(controller.movementController.transform)
    #expect(abs(copy.roll - controller.roll) < 0.0001)
}

@MainActor
@Test func fpvMovementStartsFromExistingPose() {
    let yaw = simd_float4x4(simd_quatf(angle: 0.7, axis: [0, 1, 0]))
    let pitch = simd_float4x4(simd_quatf(angle: -0.3, axis: [1, 0, 0]))
    var pose = yaw * pitch
    pose.columns.3 = [3, 4, 5, 1]

    let controller = FPVMovementController(transform: pose)
    let transform = controller.movementController.transform
    for column in 0..<4 {
        #expect(simd_length(transform[column] - pose[column]) < 0.0001)
    }
    #expect(abs(controller.pitch - -0.3) < 0.0001)
}

@MainActor
@Test func fpvKeyboardLooksUpAndTurnsLeft() {
    var controller = FPVMovementController()
    controller.process(event: .keyboardState(move: .zero, look: [-1, 1], altitude: 0, isFast: false))
    controller.update(deltaTime: 0.1)
    #expect(controller.pitch > 0)
    let forward = -controller.movementController.transform.columns.2.xyz
    #expect(forward.x < 0)
    #expect(forward.y > 0)
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
    var isReversedDepth: Bool { false }

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

// #68: gesture modifiers take transforms as input, so SwiftUI must be able to compare them.
@Test func interactionAxisTransformsCompareByValue() {
    #expect(InteractionAxisTransforms() == InteractionAxisTransforms.default)
    #expect(InteractionAxisTransforms(zoom: 2) != InteractionAxisTransforms.default)
}

@Test func cameraScrollAndMagnifyZoomUseIndependentEquivalentScales() {
    let transforms = InteractionAxisTransforms(zoom: 2)
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
    let transforms = InteractionAxisTransforms(pan: [2, 3])
    let transformer = CameraPanTransformer(transforms: transforms)

    #expect(transformer.transform(CGSize(width: 4, height: 5)) == SIMD3<Float>(8, 15, 0))
}

// MARK: - Up axis (#31)

@Test func turntableYawPitchRoundTripsWithDefaultUpAxis() {
    let rotation = TurntableTransformer.rotation(yaw: 0.7, pitch: -0.3)
    let angles = TurntableTransformer.yawPitch(of: rotation)
    #expect(abs(angles.yaw - 0.7) < 1e-5)
    #expect(abs(angles.pitch + 0.3) < 1e-5)
    let identity = TurntableTransformer.yawPitch(of: simd_quatf(angle: 0, axis: [0, 1, 0]))
    #expect(abs(identity.yaw) < 1e-6 && abs(identity.pitch) < 1e-6)
}

@Test func turntableHonoursZUpAxis() {
    let up = SIMD3<Float>(0, 0, 1)
    let level = TurntableTransformer.rotation(yaw: 1.2, pitch: 0, upAxis: up)
    #expect(abs(level.act(SIMD3<Float>(0, 0, -1)).z) < 1e-5) // looking horizontally
    #expect(simd_distance(level.act(SIMD3<Float>(0, 1, 0)), up) < 1e-5) // camera up is world up

    let tilted = TurntableTransformer.rotation(yaw: 1.2, pitch: 0.4, upAxis: up)
    #expect(abs(tilted.act(SIMD3<Float>(0, 0, -1)).z - sin(0.4)) < 1e-5)
    let angles = TurntableTransformer.yawPitch(of: tilted, upAxis: up)
    #expect(abs(angles.yaw - 1.2) < 1e-5 && abs(angles.pitch - 0.4) < 1e-5)
}

@Test func turntableYawDragRotatesAroundZUpAxis() {
    let up = SIMD3<Float>(0, 0, 1)
    let start = TurntableTransformer.rotation(yaw: 0, pitch: 0.3, upAxis: up)
    let transformer = TurntableTransformer(input: InteractionInput(rotation: CGSize(width: 50, height: 0)), upAxis: up)
    let result = transformer.transform(InteractionState(rotation: start)).rotation
    let before = start.act(SIMD3<Float>(0, 0, -1))
    let after = result.act(SIMD3<Float>(0, 0, -1))
    #expect(abs(before.z - after.z) < 1e-5) // elevation above the XY plane unchanged
    #expect(simd_distance(before, after) > 0.01)
}

@Test func turntableHandlesDownwardUpAxis() {
    let rotation = TurntableTransformer.rotation(yaw: 0, pitch: 0, upAxis: [0, -1, 0])
    #expect(simd_distance(rotation.act(SIMD3<Float>(0, 1, 0)), [0, -1, 0]) < 1e-5)
}

// MARK: - Zoom (#33)

@Test func additiveZoomAddsAndClamps() {
    let mapping = CameraZoomCoordinate<Float>(model: .additive, distanceRange: 1...10)
    #expect(mapping.coordinate(for: 5) == 5)
    #expect(mapping.distance(for: 7) == 7)
    #expect(mapping.distance(for: 0) == 1)
    #expect(mapping.distance(for: 20) == 10)
}

@Test func multiplicativeZoomScalesByTheSameFractionAtAnyDistance() {
    let model = CameraZoomModel.multiplicative(rate: 0.1)
    let mapping = CameraZoomCoordinate<Double>(model: model, distanceRange: 1.01...1e6)
    let step = model.step(forZoomOutput: 1)
    for distance in [2.0, 1_000, 500_000] {
        let zoomed = mapping.distance(for: mapping.coordinate(for: distance) + step)
        #expect(abs(zoomed / distance - exp(0.1)) < 1e-9)
    }
    #expect(mapping.distance(for: mapping.coordinate(for: 1.02) - 1) == 1.01)
    #expect(mapping.distance(for: mapping.coordinate(for: 9e5) + 5) == 1e6)
}

@Test func zoomCoordinateSubscriptMapsAndClamps() {
    var distance: Float = 10
    let mapping = CameraZoomCoordinate<Float>(model: .multiplicative(), distanceRange: 1...20)
    #expect(abs(distance[zoomCoordinate: mapping] - log(10)) < 0.0001)
    distance[zoomCoordinate: mapping] = log(100)
    #expect(distance == 20)
}

@Test func zoomStepTransformerAppliesModel() {
    var transforms = InteractionAxisTransforms()
    transforms.zoomScale = 2
    #expect(CameraZoomStepTransformer(transforms: transforms, magnitude: 1, zoom: .additive).transform(3) == 6)
    #expect(CameraZoomStepTransformer(transforms: transforms, magnitude: 1, zoom: .multiplicative(rate: 0.5)).transform(3) == 3)
}

// MARK: - Yaw and pitch, look-around (#32, #35)

@Test func yawPitchDragSessionTracksDeltas() {
    var session = YawPitchDragSession()
    #expect(session.delta(for: CGSize(width: 10, height: 4)) == CGSize(width: 10, height: 4))
    #expect(session.delta(for: CGSize(width: 15, height: 9)) == CGSize(width: 5, height: 5))
    session.end()
    #expect(session.delta(for: CGSize(width: 3, height: 3)) == CGSize(width: 3, height: 3))
}

@Test func yawPitchDragClampsPitch() {
    let result = YawPitchDragSession.apply(
        delta: CGSize(width: 10, height: 1_000),
        to: (SwiftUI.Angle.radians(0), SwiftUI.Angle.radians(0)),
        pitchRange: SwiftUI.Angle.degrees(-30)...SwiftUI.Angle.degrees(30),
        yawDelta: { $0 * 0.01 },
        pitchDelta: { $0 * 0.01 }
    )
    #expect(abs(result.yaw.radians - 0.1) < 1e-12)
    #expect(result.pitch == SwiftUI.Angle.degrees(30))
}

// MARK: - API (#32, #34, #35, #36)

@MainActor
@Test func cameraControlAPIsAcceptOptionsAndDoublePrecision() {
    let rotation = Binding.constant(simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0)))
    let yaw = Binding.constant(SwiftUI.Angle.radians(0))
    let pitch = Binding.constant(SwiftUI.Angle.radians(0))
    let floatDistance = Binding.constant(Float(5))
    let doubleDistance = Binding.constant(1e8)
    let doubleTarget = Binding.constant(SIMD3<Double>(1e9, 0, 0))

    _ = Color.clear.interactiveCamera(rotation: rotation, distance: floatDistance, target: .constant(.zero), zoom: .multiplicative(), panEnabled: false)
    _ = Color.clear.interactiveCamera(rotation: rotation, distance: doubleDistance, target: doubleTarget, mode: .turntable(TurntableTransformer(upAxis: [0, 0, 1])))
    _ = Color.clear.interactiveCamera(rotation: rotation, distance: floatDistance, target: .constant(.zero), zoom: .multiplicative(), distanceRange: 1...100, panEnabled: false)
    _ = Color.clear.interactiveCamera(yaw: yaw, pitch: pitch, distance: doubleDistance, zoom: .multiplicative(), distanceRange: 1.01...1e6)
    _ = Color.clear.interactiveLook(yaw: yaw, pitch: pitch, pitchRange: SwiftUI.Angle.degrees(-89)...SwiftUI.Angle.degrees(89))
}

// #89: controls are added as tools through their View extensions, not modifier structs.
@MainActor
@Test func toolsAcceptViewExtensionClosures() {
    let matrix = Binding.constant(matrix_identity_float4x4)
    _ = ToolPickerHost {
        Color.clear
            .tool("Orbit", id: "orbit") { $0.interactiveCamera(cameraMatrix: matrix, mode: InteractiveCameraMode.arcball()) }
            .tool("FPV", id: "fpv") { $0.fpvMovement(cameraMatrix: matrix) }
            .tool("RTS", id: "rts") { $0.rtsMovement(pose: .constant(RTSCameraPose())) }
    }
}

// #81: every orbit form takes the same zoom, distance range and pan options.
@MainActor
@Test func orbitCameraFormsShareOptions() {
    let state = Binding.constant(InteractionState())
    let matrix = Binding.constant(matrix_identity_float4x4)
    let yaw = Binding.constant(SwiftUI.Angle.radians(0))
    let pitch = Binding.constant(SwiftUI.Angle.radians(0))
    let distance = Binding.constant(Float(5))

    _ = Color.clear.interactiveCamera(state, mode: .arcball(), zoom: .multiplicative(), distanceRange: 1...100, panEnabled: false)
    _ = Color.clear.interactiveCamera(cameraMatrix: matrix, zoom: .multiplicative(), distanceRange: 1...100, panEnabled: false)
    _ = Color.clear.interactiveCamera(yaw: yaw, pitch: pitch, distance: distance, target: .constant(.zero), zoom: .multiplicative(), distanceRange: 1...100, panEnabled: false)
}

private extension SIMD4<Float> {
    var xyz: SIMD3<Float> {
        SIMD3<Float>(x, y, z)
    }
}

@MainActor
@Test func fpvMouseLookTurnsTowardMouseMovement() {
    var controller = FPVMovementController()
    controller.process(event: .look(deltaX: 10, deltaY: 10))
    let forward = -controller.movementController.transform.columns.2
    #expect(forward.x > 0)
    #expect(forward.y > 0)
}
