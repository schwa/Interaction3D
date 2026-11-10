import AsyncAlgorithms
import CoreGraphics
import Observation
import simd

// The app-facing handle for RTS camera movement. Pass it to `.rtsMovement(_:)`, which adds keyboard, edge pan,
// scroll and gesture input. The app can also feed its own input, set the pose, pause movement for animations,
// and drive updates from its own frame loop.
@Observable
@MainActor
public final class RTSNavigator {
    public var pose: RTSCameraPose

    // Where reset() and the Home key return to.
    public var homePose: RTSCameraPose

    public var settings = RTSMovementSettings() {
        didSet { controller?.edgePanMargin = settings.edgePanMargin }
    }

    // While paused, input is still read but the camera doesn't move. Use with `pose` to hand the camera to an animation.
    public var isPaused = false

    // Continuous input from the app, for example on-screen buttons. Same units as the keys:
    // panInput.x is right, panInput.y is forward, each -1...1. rotateInput is right minus left. zoomInput is in minus out.
    public var panInput: SIMD2<Float> = .zero
    public var rotateInput: Float = 0
    public var zoomInput: Float = 0

    @ObservationIgnored
    private var controller: RTSController?

    @ObservationIgnored
    private var keyInput = KeyInput()

    private var activeGestures: Set<Gesture> = []

    private struct KeyInput {
        var pan: SIMD2<Float> = .zero
        var edgePan: SIMD2<Float> = .zero
        var rotate: Float = 0
        var zoom: Float = 0
        var isFast = false
    }

    enum Gesture: Hashable {
        case pan, orbit, magnify, rotate
    }

    // Set by RTSMovementModifier.
    @ObservationIgnored
    var isKeyboardEnabled = true {
        didSet { controller?.isKeyboardEnabled = isKeyboardEnabled }
    }

    @ObservationIgnored
    var pointerLocation: CGPoint? {
        didSet { controller?.pointerLocation = pointerLocation }
    }

    @ObservationIgnored
    var isScrollAllowed = true {
        didSet { controller?.isScrollAllowed = isScrollAllowed }
    }

    public init(pose: RTSCameraPose = RTSCameraPose(), settings: RTSMovementSettings = .init()) {
        self.pose = pose
        self.homePose = pose
        self.settings = settings
    }

    // True while any key, edge pan, app input or gesture is moving the camera.
    public var hasMovementInput: Bool {
        totalPan != .zero || totalRotate != 0 || totalZoom != 0 || !activeGestures.isEmpty
    }

    public func reset() {
        pose = homePose
    }

    // Advances key and app input. Call from your frame loop only if you passed `updatesAutomatically: false`.
    public func update(deltaTime: Float) {
        guard !isPaused, deltaTime > 0 else {
            return
        }
        let pan = totalPan
        let rotate = totalRotate
        let zoom = totalZoom
        guard pan != .zero || rotate != 0 || zoom != 0 else {
            return
        }
        let speedMultiplier = keyInput.isFast ? settings.fastSpeedMultiplier : 1
        var newPose = pose
        newPose.yaw -= rotate * settings.rotateSpeed * speedMultiplier * deltaTime
        if pan != .zero {
            newPose = newPose.panned(by: pan * settings.panSpeed * speedMultiplier * deltaTime)
        }
        if zoom != 0 {
            newPose.distance = clampedDistance(newPose.distance * pow(settings.zoomSpeed, -zoom * deltaTime))
        }
        pose = newPose
    }

    private var totalPan: SIMD2<Float> {
        simd_clamp(keyInput.pan + keyInput.edgePan + panInput, SIMD2<Float>(repeating: -1), SIMD2<Float>(repeating: 1))
    }

    private var totalRotate: Float {
        max(-1, min(1, keyInput.rotate + rotateInput))
    }

    private var totalZoom: Float {
        max(-1, min(1, keyInput.zoom + zoomInput))
    }

    // MARK: - Gestures

    // Translations are in fractions of the view height, +Y down.
    func grab(_ translation: CGSize) {
        guard !isPaused else {
            return
        }
        pose = pose.grabbed(translation: translation)
    }

    func orbit(_ translation: CGSize) {
        guard !isPaused else {
            return
        }
        pose = pose.orbited(translation: translation, speed: settings.orbitSpeed, pitchRange: settings.pitchRange)
    }

    // ratio > 1 zooms in.
    func magnify(by ratio: Double) {
        guard !isPaused, ratio > 0 else {
            return
        }
        pose.distance = clampedDistance(pose.distance / Float(ratio))
    }

    func rotate(by radians: Float) {
        guard !isPaused else {
            return
        }
        pose.yaw += radians
    }

    func setGesture(_ gesture: Gesture, isActive: Bool) {
        if isActive {
            activeGestures.insert(gesture)
        } else {
            activeGestures.remove(gesture)
        }
    }

    // MARK: - Input loops

    // Reads keyboard, edge pan and scroll input until cancelled.
    func runInput() async {
        let controller = RTSController()
        controller.isKeyboardEnabled = isKeyboardEnabled
        controller.pointerLocation = pointerLocation
        controller.isScrollAllowed = isScrollAllowed
        controller.edgePanMargin = settings.edgePanMargin
        self.controller = controller
        defer {
            self.controller = nil
            keyInput = KeyInput()
        }
        for await event in controller.events {
            process(event)
        }
    }

    func process(_ event: RTSEvent) {
        switch event {
        case let .keyboardState(pan, rotate, zoom, isFast):
            keyInput.pan = pan
            keyInput.rotate = rotate
            keyInput.zoom = zoom
            keyInput.isFast = isFast
            keyInput.edgePan = .zero
        case .edgePan(let value):
            keyInput.edgePan = value
        case .zoom(let steps):
            guard !isPaused else {
                return
            }
            pose.distance = clampedDistance(pose.distance * pow(settings.zoomStepFactor, -steps))
        case .reset:
            reset()
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

    private func clampedDistance(_ distance: Float) -> Float {
        min(max(distance, settings.distanceRange.lowerBound), settings.distanceRange.upperBound)
    }
}
