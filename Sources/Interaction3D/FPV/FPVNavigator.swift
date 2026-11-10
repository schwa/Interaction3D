import AsyncAlgorithms
import Observation
import simd

// The app-facing handle for FPV movement. Pass it to `.fpvMovement(_:)`, which adds keyboard, mouse and
// game controller input. The app can also feed its own input, pause movement for autopilots, and drive
// updates from its own frame loop.
@Observable
@MainActor
public final class FPVNavigator {
    private var controller = FPVMovementController()

    @ObservationIgnored
    private var keyboard: WASDController?

    @ObservationIgnored
    private var gamepad: GameControllerMovementController?

    @ObservationIgnored
    public var hooks = FPVMovementHooks() {
        didSet { controller.hooks = hooks }
    }

    // While paused, input is still read but the camera doesn't move. Use with setPose to hand the camera to an autopilot.
    public var isPaused = false

    // Movement from the app, for example an on-screen joystick. Each axis -1...1; x is right, y is forward.
    public var moveInput: SIMD2<Float> = .zero {
        didSet { controller.externalAxes = moveInput }
    }

    @ObservationIgnored
    public let mouseCapture = MouseCapture()

    public var isMouseCaptured: Bool {
        mouseCapture.isCaptured
    }

    public var settings = FPVMovementSettings() {
        didSet { applySettings() }
    }

    // When false, the mouse doesn't look and a captured mouse is released.
    public var isMouseLookEnabled = true {
        didSet {
            controller.mouseTrackingEnabled = isMouseLookEnabled
            if !isMouseLookEnabled {
                releaseMouse()
            }
        }
    }

    @ObservationIgnored
    var isKeyboardEnabled = true {
        didSet { keyboard?.isKeyboardEnabled = isKeyboardEnabled }
    }

    // Set from hover position and the interaction filters by FPVMovementModifier.
    @ObservationIgnored
    var isLookAllowed = true {
        didSet { keyboard?.isLookAllowed = isLookAllowed }
    }

    @ObservationIgnored
    var isScrollAllowed = true {
        didSet { keyboard?.isScrollAllowed = isScrollAllowed }
    }

    public init(pose: simd_float4x4 = matrix_identity_float4x4) {
        controller.setPose(pose)
        applySettings()
    }

    public var transform: simd_float4x4 {
        controller.movementController.transform
    }

    public var linearVelocity: SIMD3<Float> {
        controller.movementController.linearVelocity
    }

    public var angularVelocity: SIMD3<Float> {
        controller.movementController.angularVelocity
    }

    public var motionState: FPVMotionState {
        controller.motionState
    }

    public var pitch: Float {
        controller.pitch
    }

    public var speed: Float {
        controller.speed
    }

    // True while any movement input is held. Useful for cancelling an autopilot when the user takes over.
    public var hasMovementInput: Bool {
        controller.hasMovementInput
    }

    // Moves the camera. Scale is dropped; roll is dropped unless roll controls are on.
    public func setPose(_ transform: simd_float4x4) {
        controller.setPose(transform)
    }

    // Turns by angles in radians, for example from drag-to-look. Positive yaw turns right, positive pitch looks up.
    public func look(yaw: Float, pitch: Float) {
        controller.look(yaw: yaw, pitch: pitch)
    }

    public func reset() {
        controller.reset()
    }

    // Advances movement. Call from your frame loop only if you passed `updatesAutomatically: false`.
    public func update(deltaTime: Float) {
        guard !isPaused else {
            return
        }
        controller.update(deltaTime: deltaTime)
    }

    // Cursor capture is macOS-only; elsewhere these do nothing.
    public func captureMouse() {
        mouseCapture.capture()
    }

    public func releaseMouse() {
        mouseCapture.release()
    }

    public func toggleMouseCapture() {
        mouseCapture.toggle()
    }

    // Reads keyboard, mouse and game controller input until cancelled.
    func runInput() async {
        let keyboard = WASDController(mouseCapture: mouseCapture)
        keyboard.isKeyboardEnabled = isKeyboardEnabled
        keyboard.isLookAllowed = isLookAllowed
        keyboard.isScrollAllowed = isScrollAllowed
        keyboard.extraControls = settings.extraControls
        let gamepad = GameControllerMovementController()
        self.keyboard = keyboard
        self.gamepad = gamepad
        defer {
            releaseMouse()
            self.keyboard = nil
            self.gamepad = nil
        }
        async let keyboardInput: Void = process(keyboard.events)
        async let gamepadInput: Void = process(gamepad.events)
        _ = await (keyboardInput, gamepadInput)
    }

    private func process(_ events: AsyncStream<NavigationEvent>) async {
        for await event in events {
            controller.process(event: event)
        }
    }

    // Calls update on a timer until cancelled.
    func runUpdates() async {
        let clock = ContinuousClock()
        var previousUpdate = clock.now
        for await _ in AsyncTimerSequence(interval: .milliseconds(8), clock: clock) {
            let updateTime = clock.now
            let components = previousUpdate.duration(to: updateTime).components
            previousUpdate = updateTime
            update(deltaTime: Float(components.seconds) + Float(components.attoseconds) / 1e18)
        }
    }

    private func applySettings() {
        controller.speed = settings.speed
        controller.fastSpeedMultiplier = settings.fastSpeedMultiplier
        controller.mouseSensitivity = settings.mouseSensitivity
        controller.controllerTurnSpeed = settings.controllerTurnSpeed
        controller.keyboardTurnSpeed = settings.keyboardTurnSpeed
        controller.isFreeFlightEnabled = settings.isFreeFlightEnabled
        controller.slowSpeedMultiplier = settings.slowSpeedMultiplier
        controller.speedAdjustmentFactor = settings.speedAdjustmentFactor
        controller.rollSpeed = settings.rollSpeed
        controller.isRollEnabled = settings.extraControls.contains(.roll)
        controller.walkSettings = settings.walk
        keyboard?.extraControls = settings.extraControls
    }
}
