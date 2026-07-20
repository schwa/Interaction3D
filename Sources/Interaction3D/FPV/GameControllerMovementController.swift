import AsyncAlgorithms
import Foundation
import GameController
import Observation
import simd

@Observable
@MainActor
public final class GameControllerMovementController {
    @ObservationIgnored
    private let eventContinuation: AsyncStream<NavigationEvent>.Continuation

    @ObservationIgnored
    public let events: AsyncStream<NavigationEvent>

    @ObservationIgnored
    private var timerTask: Task<Void, Never>?

    @ObservationIgnored
    private var connectionTask: Task<Void, Never>?

    @ObservationIgnored
    private var disconnectionTask: Task<Void, Never>?

    @ObservationIgnored
    private var activeController: GCController? {
        didSet {
            if activeController !== oldValue {
                updateControllerMetadata()
                configureController(activeController)
            }
        }
    }

    public private(set) var controllerDisplayName: String = "No Controller"
    public private(set) var isControllerConnected: Bool = false
    public private(set) var lastInputTimestamp: Date?

    private let movementTransformer: MovementTransformer
    private let lookTransformer: RotationTransformer
    private let altitudeTransformer: AnyTransformer<Float, Float>

    private static func makeDefaultAltitudeTransformer() -> AnyTransformer<Float, Float> {
        let pipeline = DeadzoneTransformer(deadzone: 0.05) | ClampTransformer(min: -1, max: 1)
        return AnyTransformer(pipeline)
    }

    public init(
        movementTransformer: MovementTransformer = MovementTransformer(deadzone: 0.05, scale: 1, curve: .quadratic, reverseY: false),
        lookTransformer: RotationTransformer = RotationTransformer(deadzone: 0.05, scale: 1, curve: .quadratic, reverseX: false, reverseY: false),
        altitudeTransformer: AnyTransformer<Float, Float>? = nil
    ) {
        self.movementTransformer = movementTransformer
        self.lookTransformer = lookTransformer
        self.altitudeTransformer = altitudeTransformer ?? Self.makeDefaultAltitudeTransformer()
        (events, eventContinuation) = AsyncStream.makeStream(of: NavigationEvent.self, bufferingPolicy: .bufferingNewest(1))
        updateControllerMetadata()
        bootstrapInitialController()
        observeControllerConnections()
        observeControllerDisconnections()
        startTimerLoop()
    }

    deinit {
        timerTask?.cancel()
        connectionTask?.cancel()
        disconnectionTask?.cancel()
        eventContinuation.finish()
    }

    private func bootstrapInitialController() {
        synchronizeActiveController()
    }

    private func observeControllerConnections() {
        connectionTask = Task { [weak self] in
            guard let self else {
                return
            }
            for await notification in NotificationCenter.default.notifications(named: .GCControllerDidConnect) {
                guard let controller = notification.object as? GCController else {
                    continue
                }
                if activeController == nil {
                    activeController = controller
                }
                synchronizeActiveController()
            }
        }
    }

    private func observeControllerDisconnections() {
        disconnectionTask = Task { [weak self] in
            guard let self else {
                return
            }
            for await notification in NotificationCenter.default.notifications(named: .GCControllerDidDisconnect) {
                guard let controller = notification.object as? GCController else {
                    continue
                }
                if controller == activeController {
                    synchronizeActiveController()
                    if activeController == nil {
                        emitNeutralFrame()
                    }
                }
            }
        }
    }

    private func configureController(_ controller: GCController?) {
        guard let controller else {
            return
        }

        if let gamepad = controller.extendedGamepad {
            configureExtendedGamepad(gamepad)
        } else if let microGamepad = controller.microGamepad {
            configureMicroGamepad(microGamepad)
        }
    }

    private func configureExtendedGamepad(_ gamepad: GCExtendedGamepad) {
        gamepad.valueChangedHandler = { [weak self] _, _ in
            MainActor.assumeIsolated {
                self?.lastInputTimestamp = Date()
            }
        }
    }

    private func configureMicroGamepad(_ gamepad: GCMicroGamepad) {
        gamepad.valueChangedHandler = { [weak self] _, _ in
            MainActor.assumeIsolated {
                self?.lastInputTimestamp = Date()
            }
        }
        gamepad.allowsRotation = true
    }

    private func startTimerLoop() {
        guard timerTask == nil else {
            return
        }

        timerTask = Task { [weak self] in
            let clock = ContinuousClock()
            let interval = Duration.milliseconds(8)

            for await _ in AsyncTimerSequence(interval: interval, clock: clock) {
                guard let self else {
                    return
                }

                synchronizeActiveController()

                guard isControllerConnected else {
                    emitNeutralFrame()
                    continue
                }

                let state = readInputVectors()

                guard state.connected else {
                    eventContinuation.yield(.controllerState(move: .zero, look: .zero, altitude: 0))
                    continue
                }

                let move = movementTransformer.transform(state.move)
                let look = lookTransformer.transform(state.look)
                let altitude = altitudeTransformer.transform(state.altitude)

                eventContinuation.yield(.controllerState(move: move, look: look, altitude: altitude))
            }
        }
    }

    private func emitNeutralFrame() {
        eventContinuation.yield(.controllerState(move: .zero, look: .zero, altitude: 0))
    }

    private func updateControllerMetadata() {
        guard let controller = activeController else {
            controllerDisplayName = "No Controller"
            isControllerConnected = false
            return
        }

        isControllerConnected = true
        let vendor = controller.vendorName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let category = controller.productCategory.trimmingCharacters(in: .whitespacesAndNewlines)

        if let vendor, !vendor.isEmpty {
            if category.isEmpty {
                controllerDisplayName = vendor
            } else {
                controllerDisplayName = "\(vendor) (\(category))"
            }
        } else if !category.isEmpty {
            controllerDisplayName = category
        } else {
            controllerDisplayName = "Game Controller"
        }
    }

    private func synchronizeActiveController() {
        let controllers = GCController.controllers()
        if let current = activeController, controllers.contains(where: { $0 === current }) {
            // Keep current controller, but ensure metadata reflects connection state
            updateControllerMetadata()
        } else {
            activeController = controllers.first { $0.extendedGamepad != nil } ?? controllers.first
            if activeController == nil {
                updateControllerMetadata()
            }
        }

        if controllers.isEmpty {
            isControllerConnected = false
        }
    }

    private func readInputVectors() -> (move: SIMD2<Float>, look: SIMD2<Float>, altitude: Float, connected: Bool) {
        guard let controller = activeController else {
            return (.zero, .zero, 0, false)
        }

        if let snapshot = controller.extendedGamepad?.capture() {
            lastInputTimestamp = Date()
            let move = SIMD2(Float(snapshot.leftThumbstick.xAxis.value), Float(snapshot.leftThumbstick.yAxis.value))
            let look = SIMD2(Float(snapshot.rightThumbstick.xAxis.value), Float(snapshot.rightThumbstick.yAxis.value))
            let altitude = Float(snapshot.rightShoulder.value) - Float(snapshot.leftShoulder.value)
            return (move, look, altitude, true)
        }

        if let snapshot = controller.microGamepad?.capture() {
            lastInputTimestamp = Date()
            let move = SIMD2(Float(snapshot.dpad.xAxis.value), Float(snapshot.dpad.yAxis.value))
            return (move, .zero, 0, true)
        }

        return (.zero, .zero, 0, true)
    }
}
