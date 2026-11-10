import Observation
import simd

@MainActor
struct FPVMovementController {
    var movementController = MovementController()

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
    // Movement from outside the controller, for example an on-screen joystick. x is right, y is forward.
    var externalAxes: SIMD2<Float> = .zero
    private var isJumpPressed = false
    private var lastJumpPressTime: Float?
    private var elapsedTime: Float = 0

    var walkSettings: FPVWalkSettings? {
        didSet {
            if walkSettings == nil {
                motionState = FPVMotionState()
            }
        }
    }

    var hooks = FPVMovementHooks()
    private(set) var motionState = FPVMotionState()

    private var yaw: Float = 0
    private(set) var pitch: Float = 0
    private(set) var roll: Float = 0
    private var position: SIMD3<Float> = .zero

    private let minPitch: Float = -.pi / 2 + 0.01
    private let maxPitch: Float = .pi / 2 - 0.01

    var speed: Float = 10.0
    var mouseSensitivity: Float = 0.01
    var mouseTrackingEnabled: Bool = true
    var controllerTurnSpeed: Float = .pi
    var keyboardTurnSpeed: Float = .pi / 2
    var fastSpeedMultiplier: Float = 4
    // Free flight moves along the full view direction, including pitch.
    var isFreeFlightEnabled = false
    var slowSpeedMultiplier: Float = 0.25
    var speedAdjustmentFactor: Float = 1.25
    var speedRange: ClosedRange<Float> = 0.01...100_000
    var rollSpeed: Float = .pi / 2
    // When false, roll is forced to zero and dropped from incoming poses.
    var isRollEnabled = false {
        didSet {
            if !isRollEnabled {
                roll = 0
                keyboardRollAxis = 0
                updateTransform()
            }
        }
    }

    init() {
        updateTransform()
    }

    init(transform: simd_float4x4) {
        setPose(transform)
    }

    // Scale is dropped. Roll is dropped unless isRollEnabled.
    mutating func setPose(_ transform: simd_float4x4) {
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

    mutating func process(event: NavigationEvent) {
        switch event {
        case .axes(let forward, let sideways, let source):
            processAxes(SIMD2<Float>(sideways, forward), source: source)
        case .look(let deltaX, let deltaY, let source):
            processLook(deltaX: deltaX, deltaY: deltaY, source: source)
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
        case .jumpState(let isPressed):
            processJump(isPressed: isPressed)
            return
        case .adjustSpeed(let steps):
            speed = min(max(speed * pow(speedAdjustmentFactor, steps), speedRange.lowerBound), speedRange.upperBound)
        case .reset:
            reset()
            return
        }

        updateTransform()
    }

    var hasMovementInput: Bool {
        length(keyboardAxes + controllerAxes + externalAxes) > 0.1 || keyboardAltitudeAxis != 0 || controllerAltitudeAxis != 0 || isJumpPressed
    }

    // Turns by angles in radians. Positive yaw turns right, positive pitch looks up.
    mutating func look(yaw yawDelta: Float, pitch pitchDelta: Float) {
        yaw -= yawDelta
        pitch += pitchDelta
        clampPitch()
        updateTransform()
    }

    private mutating func processAxes(_ vector: SIMD2<Float>, source: NavigationEvent.AxisSource) {
        if source == .keyboard {
            keyboardAxes = vector
        } else {
            controllerAxes = vector
        }
    }

    private mutating func processJump(isPressed: Bool) {
        if isPressed, !isJumpPressed {
            jumpPressed()
        }
        isJumpPressed = isPressed
    }

    private mutating func processLook(deltaX: Float, deltaY: Float, source: NavigationEvent.LookSource) {
        switch source {
        case .mouse:
            guard mouseTrackingEnabled, isLookHeld else {
                return
            }
            // Deltas use GCMouse convention: +X right, +Y up.
            yaw -= deltaX * mouseSensitivity
            pitch += deltaY * mouseSensitivity
            clampPitch()
        case .controller:
            controllerYawAxis = -deltaX
            controllerPitchAxis = -deltaY
        }
    }

    mutating func update(deltaTime: Float) {
        elapsedTime += max(deltaTime, 0)
        applyContinuousInputs(deltaTime: max(deltaTime, 0))
        updateTransform()
    }

    // First press jumps from the ground; a quick second press toggles flying.
    private mutating func jumpPressed() {
        guard let walk = walkSettings, walk.gravity > 0 else {
            return
        }
        if walk.isFlightToggleEnabled, let last = lastJumpPressTime, elapsedTime - last <= walk.doubleTapInterval {
            motionState.isFlying.toggle()
            motionState.verticalVelocity = 0
            lastJumpPressTime = nil
            return
        }
        lastJumpPressTime = elapsedTime
        if motionState.isOnGround, !motionState.isFlying {
            motionState.verticalVelocity = walk.jumpSpeed
            motionState.isOnGround = false
        }
    }

    mutating func reset() {
        keyboardAxes = .zero
        controllerAxes = .zero
        externalAxes = .zero
        controllerYawAxis = 0
        controllerPitchAxis = 0
        controllerAltitudeAxis = 0
        keyboardYawAxis = 0
        keyboardPitchAxis = 0
        keyboardAltitudeAxis = 0
        isFast = false
        keyboardRollAxis = 0
        isSlow = false
        isJumpPressed = false
        lastJumpPressTime = nil
        motionState = FPVMotionState()
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
        var movementInput = keyboardMove + controllerAxes + externalAxes
        let magnitude = length(movementInput)
        if magnitude > 1 {
            movementInput /= magnitude
        }

        let right: SIMD3<Float>
        let forward: SIMD3<Float>
        if isFreeFlightEnabled, walkSettings == nil {
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
        let jumpAltitude: Float = isJumpPressed && isLookHeld ? 1 : 0
        let altitudeInput = max(-1, min(1, controllerAltitudeAxis + keyboardAltitude + jumpAltitude))
        let startPosition = position

        if let walk = walkSettings {
            applyWalk(walk, horizontal: deltaPosition, altitude: altitudeInput * currentSpeed * deltaTime, deltaTime: deltaTime)
        } else {
            move(by: deltaPosition + SIMD3<Float>(0, altitudeInput * currentSpeed * deltaTime, 0))
        }

        movementController.linearVelocity = (position - startPosition) / deltaTime
        movementController.angularVelocity = .zero
    }

    // Moves through hooks.canMove, sliding when the full step is blocked. Returns false if nothing moved.
    @discardableResult
    private mutating func move(by delta: SIMD3<Float>, extraCheck: ((SIMD3<Float>, SIMD3<Float>) -> Bool)? = nil) -> Bool {
        guard delta != .zero else {
            return true
        }
        guard hooks.canMove != nil || extraCheck != nil else {
            position += delta
            return true
        }
        for candidate in slideCandidates(for: delta) {
            let target = position + candidate
            if extraCheck?(position, target) ?? true, hooks.canMove?(position, target) ?? true {
                position = target
                return true
            }
        }
        return false
    }

    private mutating func applyWalk(_ walk: FPVWalkSettings, horizontal: SIMD3<Float>, altitude: Float, deltaTime: Float) {
        let groundHeight = hooks.groundHeight
        let eyeHeight = walk.eyeHeight
        var stepCheck: ((SIMD3<Float>, SIMD3<Float>) -> Bool)?
        if let maxStepUp = walk.maxStepUp, let groundHeight, motionState.isOnGround {
            stepCheck = { from, to in
                guard let next = groundHeight(to) else {
                    return true
                }
                let current = groundHeight(from) ?? (from.y - eyeHeight)
                return next - current <= maxStepUp
            }
        }
        let before = position
        move(by: horizontal, extraCheck: stepCheck)
        if motionState.isOnGround {
            let moved = position - before
            motionState.distanceWalked += length(SIMD2<Float>(moved.x, moved.z))
        }
        applyVertical(walk, restingHeight: groundHeight?(position).map { $0 + eyeHeight }, altitude: altitude, deltaTime: deltaTime)
    }

    // Flying, falling, landing and following the ground. restingHeight is the eye height on the ground here.
    private mutating func applyVertical(_ walk: FPVWalkSettings, restingHeight: Float?, altitude: Float, deltaTime: Float) {
        if motionState.isFlying {
            motionState.verticalVelocity = 0
            move(by: SIMD3<Float>(0, altitude, 0))
            if let restingHeight, position.y <= restingHeight {
                position.y = restingHeight
                motionState.isFlying = false
                motionState.isOnGround = true
            } else {
                motionState.isOnGround = false
            }
        } else if walk.gravity > 0 {
            motionState.verticalVelocity -= walk.gravity * deltaTime
            let nextHeight = position.y + motionState.verticalVelocity * deltaTime
            if let restingHeight, nextHeight <= restingHeight {
                motionState.verticalVelocity = 0
                motionState.isOnGround = true
                if position.y < restingHeight {
                    // Higher ground: ease up instead of popping.
                    position.y += (restingHeight - position.y) * min(1, deltaTime * walk.groundFollowRate)
                } else {
                    position.y = restingHeight
                }
            } else if move(by: SIMD3<Float>(0, nextHeight - position.y, 0)) {
                motionState.isOnGround = false
            } else {
                // Hit a ceiling or a floor the app blocks.
                motionState.verticalVelocity = 0
            }
        } else if let restingHeight {
            position.y += (restingHeight - position.y) * min(1, deltaTime * walk.groundFollowRate)
            motionState.isOnGround = true
        } else {
            motionState.isOnGround = false
        }
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
        if let adjustCamera = hooks.adjustCamera {
            transform = adjustCamera(transform, motionState)
        }
        movementController.transform = transform
    }
}
