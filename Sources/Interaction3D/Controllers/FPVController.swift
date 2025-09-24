import Foundation
import Observation
import simd

public struct FPVController {
    public var movementController = MovementController()

    private var keyboardAxes: SIMD2<Float> = .zero
    private var controllerAxes: SIMD2<Float> = .zero
    private var controllerYawAxis: Float = 0
    private var controllerPitchAxis: Float = 0
    private var controllerAltitudeAxis: Float = 0

    private var yaw: Float = 0
    public private(set) var pitch: Float = 0
    private var position: SIMD3<Float> = .zero
    private var lastUpdateTime: TimeInterval?

    private let minPitch: Float = -.pi / 2 + 0.01
    private let maxPitch: Float = .pi / 2 - 0.01

    public var speed: Float = 10.0
    public var mouseSensitivity: Float = 0.01
    public var mouseTrackingEnabled: Bool = false
    public var controllerTurnSpeed: Float = .pi

    public init() {
        updateTransform()
    }

    public mutating func process(event: NavigationEvent) {
        let now = Date.timeIntervalSinceReferenceDate
        if let lastUpdateTime {
            let delta = Float(now - lastUpdateTime)
            applyContinuousInputs(deltaTime: max(delta, 0))
        }
        lastUpdateTime = now

        switch event {
        case .axes(let forward, let sideways, let source):
            let vector = SIMD2<Float>(sideways, forward)
            switch source {
            case .keyboard:
                keyboardAxes = vector
            case .controller:
                controllerAxes = vector
            }
        case .look(let deltaX, let deltaY, let source):
            switch source {
            case .mouse:
                guard mouseTrackingEnabled else { break }
                yaw += deltaX * mouseSensitivity
                pitch -= deltaY * mouseSensitivity
                clampPitch()
            case .controller:
                controllerYawAxis = -deltaX
                controllerPitchAxis = -deltaY
            }
        case .altitude(let value, _):
            controllerAltitudeAxis = value
        case .controllerState(let move, let look, let altitude):
            controllerAxes = move
            controllerYawAxis = -look.x
            controllerPitchAxis = -look.y
            controllerAltitudeAxis = altitude
        }

        updateTransform()
    }

    public mutating func reset() {
        keyboardAxes = .zero
        controllerAxes = .zero
        controllerYawAxis = 0
        controllerPitchAxis = 0
        controllerAltitudeAxis = 0
        yaw = 0
        pitch = 0
        position = .zero
        movementController.linearVelocity = .zero
        movementController.angularVelocity = .zero
        lastUpdateTime = nil
        updateTransform()
    }

    private mutating func applyContinuousInputs(deltaTime: Float) {
        guard deltaTime > 0 else {
            return
        }

        yaw += controllerYawAxis * controllerTurnSpeed * deltaTime
        pitch += controllerPitchAxis * controllerTurnSpeed * deltaTime
        clampPitch()

        var movementInput = keyboardAxes + controllerAxes
        let magnitude = length(movementInput)
        if magnitude > 1 {
            movementInput /= magnitude
        }

        let sinYaw = sin(yaw)
        let cosYaw = cos(yaw)
        let right = SIMD3<Float>(cosYaw, 0, -sinYaw)
        let forward = SIMD3<Float>(-sinYaw, 0, -cosYaw)
        let deltaPosition = (right * movementInput.x + forward * movementInput.y) * speed * deltaTime

        position += deltaPosition
        position.y += controllerAltitudeAxis * speed * deltaTime

        let planarVelocity = deltaPosition / deltaTime
        let altitudeVelocity = controllerAltitudeAxis * speed
        movementController.linearVelocity = SIMD3<Float>(planarVelocity.x, altitudeVelocity, planarVelocity.z)
        movementController.angularVelocity = .zero
    }

    private mutating func clampPitch() {
        if pitch < minPitch {
            pitch = minPitch
        }
        if pitch > maxPitch {
            pitch = maxPitch
        }
    }

    private mutating func updateTransform() {
        let yawRotation = simd_float4x4(simd_quatf(angle: yaw, axis: SIMD3<Float>(0, 1, 0)))
        let pitchRotation = simd_float4x4(simd_quatf(angle: pitch, axis: SIMD3<Float>(1, 0, 0)))
        var transform = yawRotation * pitchRotation
        transform.columns.3 = SIMD4<Float>(position.x, position.y, position.z, 1)
        movementController.transform = transform
    }
}
