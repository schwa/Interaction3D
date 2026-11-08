import Observation
import simd

@MainActor
public struct FPVMovementController {
    public var movementController = MovementController()

    private var keyboardAxes: SIMD2<Float> = .zero
    private var controllerAxes: SIMD2<Float> = .zero
    private var controllerYawAxis: Float = 0
    private var controllerPitchAxis: Float = 0
    private var controllerAltitudeAxis: Float = 0
    private var keyboardYawAxis: Float = 0
    private var keyboardPitchAxis: Float = 0
    private var keyboardAltitudeAxis: Float = 0
    private var isFast = false

    private var yaw: Float = 0
    public private(set) var pitch: Float = 0
    private var position: SIMD3<Float> = .zero

    private let minPitch: Float = -.pi / 2 + 0.01
    private let maxPitch: Float = .pi / 2 - 0.01

    public var speed: Float = 10.0
    public var mouseSensitivity: Float = 0.01
    public var mouseTrackingEnabled: Bool = true
    public var controllerTurnSpeed: Float = .pi
    public var keyboardTurnSpeed: Float = .pi / 2
    public var fastSpeedMultiplier: Float = 4
    // Free flight moves along the full view direction, including pitch.
    public var isFreeFlightEnabled = false

    public init() {
        updateTransform()
    }

    public init(transform: simd_float4x4) {
        setPose(transform)
    }

    // Roll and scale are dropped; FPV keeps the camera upright.
    public mutating func setPose(_ transform: simd_float4x4) {
        let forward = -SIMD3<Float>(transform.columns.2.x, transform.columns.2.y, transform.columns.2.z)
        let direction = length(forward) > 0 ? normalize(forward) : SIMD3<Float>(0, 0, -1)
        yaw = atan2(-direction.x, -direction.z)
        pitch = asin(max(-1, min(1, direction.y)))
        clampPitch()
        position = SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
        updateTransform()
    }

    public mutating func process(event: NavigationEvent) {
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
                // Deltas use GCMouse convention: +X right, +Y up.
                yaw -= deltaX * mouseSensitivity
                pitch += deltaY * mouseSensitivity
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
        case .keyboardState(let move, let look, let altitude, let isFast):
            keyboardAxes = move
            keyboardYawAxis = -look.x
            keyboardPitchAxis = look.y
            keyboardAltitudeAxis = altitude
            self.isFast = isFast
        }

        updateTransform()
    }

    public mutating func update(deltaTime: Float) {
        applyContinuousInputs(deltaTime: max(deltaTime, 0))
        updateTransform()
    }

    public mutating func reset() {
        keyboardAxes = .zero
        controllerAxes = .zero
        controllerYawAxis = 0
        controllerPitchAxis = 0
        controllerAltitudeAxis = 0
        keyboardYawAxis = 0
        keyboardPitchAxis = 0
        keyboardAltitudeAxis = 0
        isFast = false
        yaw = 0
        pitch = 0
        position = .zero
        movementController.linearVelocity = .zero
        movementController.angularVelocity = .zero
        updateTransform()
    }

    private mutating func applyContinuousInputs(deltaTime: Float) {
        guard deltaTime > 0 else {
            return
        }

        yaw += (controllerYawAxis * controllerTurnSpeed + keyboardYawAxis * keyboardTurnSpeed) * deltaTime
        pitch += (controllerPitchAxis * controllerTurnSpeed + keyboardPitchAxis * keyboardTurnSpeed) * deltaTime
        clampPitch()

        var movementInput = keyboardAxes + controllerAxes
        let magnitude = length(movementInput)
        if magnitude > 1 {
            movementInput /= magnitude
        }

        let sinYaw = sin(yaw)
        let cosYaw = cos(yaw)
        let right = SIMD3<Float>(cosYaw, 0, -sinYaw)
        let forward = isFreeFlightEnabled
            ? SIMD3<Float>(-sinYaw * cos(pitch), sin(pitch), -cosYaw * cos(pitch))
            : SIMD3<Float>(-sinYaw, 0, -cosYaw)
        let currentSpeed = isFast ? speed * fastSpeedMultiplier : speed
        let deltaPosition = (right * movementInput.x + forward * movementInput.y) * currentSpeed * deltaTime
        let altitudeInput = max(-1, min(1, controllerAltitudeAxis + keyboardAltitudeAxis))

        position += deltaPosition
        position.y += altitudeInput * currentSpeed * deltaTime

        var velocity = deltaPosition / deltaTime
        velocity.y += altitudeInput * currentSpeed
        movementController.linearVelocity = velocity
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
