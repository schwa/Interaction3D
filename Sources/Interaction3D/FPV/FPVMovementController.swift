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
    private var keyboardRollAxis: Float = 0
    private var isSlow = false
    private var isLookHeld = true

    private var yaw: Float = 0
    public private(set) var pitch: Float = 0
    public private(set) var roll: Float = 0
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
    public var slowSpeedMultiplier: Float = 0.25
    public var speedAdjustmentFactor: Float = 1.25
    public var speedRange: ClosedRange<Float> = 0.01...100_000
    public var rollSpeed: Float = .pi / 2
    // When false, roll is forced to zero and dropped from incoming poses.
    public var isRollEnabled = false {
        didSet {
            if !isRollEnabled {
                roll = 0
                keyboardRollAxis = 0
                updateTransform()
            }
        }
    }

    public init() {
        updateTransform()
    }

    public init(transform: simd_float4x4) {
        setPose(transform)
    }

    // Scale is dropped. Roll is dropped unless isRollEnabled.
    public mutating func setPose(_ transform: simd_float4x4) {
        let forward = -SIMD3<Float>(transform.columns.2.x, transform.columns.2.y, transform.columns.2.z)
        let direction = length(forward) > 0 ? normalize(forward) : SIMD3<Float>(0, 0, -1)
        yaw = atan2(-direction.x, -direction.z)
        pitch = asin(max(-1, min(1, direction.y)))
        clampPitch()
        roll = 0
        if isRollEnabled {
            let uprightBasis = simd_float3x3(simd_quatf(angle: yaw, axis: [0, 1, 0]) * simd_quatf(angle: pitch, axis: [1, 0, 0]))
            let right = SIMD3<Float>(transform.columns.0.x, transform.columns.0.y, transform.columns.0.z)
            roll = atan2(dot(right, uprightBasis.columns.1), dot(right, uprightBasis.columns.0))
        }
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
                guard mouseTrackingEnabled, isLookHeld else { break }
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
        case .extraKeyboardState(let roll, let isSlow, let isLookHeld):
            keyboardRollAxis = isRollEnabled ? roll : 0
            self.isSlow = isSlow
            self.isLookHeld = isLookHeld
        case .adjustSpeed(let steps):
            speed = min(max(speed * pow(speedAdjustmentFactor, steps), speedRange.lowerBound), speedRange.upperBound)
        case .reset:
            reset()
            return
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
        keyboardRollAxis = 0
        isSlow = false
        yaw = 0
        pitch = 0
        roll = 0
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
        // Positive roll axis rolls right, which is a negative rotation about +Z.
        roll -= keyboardRollAxis * rollSpeed * deltaTime

        let keyboardMove = isLookHeld ? keyboardAxes : .zero
        let keyboardAltitude = isLookHeld ? keyboardAltitudeAxis : 0
        var movementInput = keyboardMove + controllerAxes
        let magnitude = length(movementInput)
        if magnitude > 1 {
            movementInput /= magnitude
        }

        let right: SIMD3<Float>
        let forward: SIMD3<Float>
        if isFreeFlightEnabled {
            let basis = simd_float3x3(orientation)
            right = basis.columns.0
            forward = -basis.columns.2
        } else {
            right = SIMD3<Float>(cos(yaw), 0, -sin(yaw))
            forward = SIMD3<Float>(-sin(yaw), 0, -cos(yaw))
        }
        var currentSpeed = speed
        if isFast {
            currentSpeed *= fastSpeedMultiplier
        }
        if isSlow {
            currentSpeed *= slowSpeedMultiplier
        }
        let deltaPosition = (right * movementInput.x + forward * movementInput.y) * currentSpeed * deltaTime
        let altitudeInput = max(-1, min(1, controllerAltitudeAxis + keyboardAltitude))

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

    private var orientation: simd_quatf {
        simd_quatf(angle: yaw, axis: [0, 1, 0]) * simd_quatf(angle: pitch, axis: [1, 0, 0]) * simd_quatf(angle: roll, axis: [0, 0, 1])
    }

    private mutating func updateTransform() {
        var transform = simd_float4x4(orientation)
        transform.columns.3 = SIMD4<Float>(position.x, position.y, position.z, 1)
        movementController.transform = transform
    }
}
