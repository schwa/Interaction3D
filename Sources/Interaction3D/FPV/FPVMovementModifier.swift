import AsyncAlgorithms
import simd
import SwiftUI

public struct FPVMovementSettings: Equatable, Sendable {
    public var speed: Float
    public var fastSpeedMultiplier: Float
    public var mouseSensitivity: Float
    public var controllerTurnSpeed: Float
    public var keyboardTurnSpeed: Float
    public var isFreeFlightEnabled: Bool
    public var extraControls: FPVExtraControls
    public var slowSpeedMultiplier: Float
    public var speedAdjustmentFactor: Float
    public var rollSpeed: Float
    // Walk mode with ground, gravity and jumping. nil keeps the camera free.
    public var walk: FPVWalkSettings?

    public init(
        speed: Float = 10,
        fastSpeedMultiplier: Float = 4,
        mouseSensitivity: Float = 0.01,
        controllerTurnSpeed: Float = .pi,
        keyboardTurnSpeed: Float = .pi / 2,
        isFreeFlightEnabled: Bool = false,
        extraControls: FPVExtraControls = [],
        slowSpeedMultiplier: Float = 0.25,
        speedAdjustmentFactor: Float = 1.25,
        rollSpeed: Float = .pi / 2,
        walk: FPVWalkSettings? = nil
    ) {
        self.walk = walk
        self.extraControls = extraControls
        self.slowSpeedMultiplier = slowSpeedMultiplier
        self.speedAdjustmentFactor = speedAdjustmentFactor
        self.rollSpeed = rollSpeed
        self.isFreeFlightEnabled = isFreeFlightEnabled
        self.speed = speed
        self.fastSpeedMultiplier = fastSpeedMultiplier
        self.mouseSensitivity = mouseSensitivity
        self.controllerTurnSpeed = controllerTurnSpeed
        self.keyboardTurnSpeed = keyboardTurnSpeed
    }
}

public struct FPVMovementModifier: ViewModifier {
    @Binding
    var cameraMatrix: matrix_float4x4

    @State
    private var fpvController = FPVMovementController()

    @State
    private var wasdController = WASDController()

    @State
    private var gameController = GameControllerMovementController()

    @FocusState
    private var isFocused: Bool

    @Binding
    var isMouseLookEnabled: Bool

    let showsControls: Bool
    let settings: FPVMovementSettings
    let hooks: FPVMovementHooks

    // Holds the latest hooks so the update loop sees closures from the latest body.
    @State
    private var hooksBox = HooksBox()

    private final class HooksBox {
        var hooks = FPVMovementHooks()
    }

    // showsControls adds Capture Mouse and Reset toolbar buttons to the host window.
    public init(
        cameraMatrix: Binding<matrix_float4x4>,
        isMouseLookEnabled: Binding<Bool> = .constant(true),
        settings: FPVMovementSettings = .init(),
        hooks: FPVMovementHooks = .init(),
        showsControls: Bool = false
    ) {
        self._cameraMatrix = cameraMatrix
        self._isMouseLookEnabled = isMouseLookEnabled
        self.settings = settings
        self.hooks = hooks
        self.showsControls = showsControls
    }

    public func body(content: Content) -> some View {
        hooksBox.hooks = hooks
        return content
            .focusable()
            .focused($isFocused)
            .task {
                // Claim focus on appear so WASD works without a click.
                isFocused = true
            }
            .onChange(of: isFocused, initial: true) {
                wasdController.isKeyboardEnabled = isFocused
            }
            .disableWASDKeys(extraControls: settings.extraControls)
            .toolbar {
                if showsControls {
                    toolbarContent
                }
            }
            .onChange(of: settings, initial: true) {
                fpvController.speed = settings.speed
                fpvController.fastSpeedMultiplier = settings.fastSpeedMultiplier
                fpvController.mouseSensitivity = settings.mouseSensitivity
                fpvController.controllerTurnSpeed = settings.controllerTurnSpeed
                fpvController.keyboardTurnSpeed = settings.keyboardTurnSpeed
                fpvController.isFreeFlightEnabled = settings.isFreeFlightEnabled
                fpvController.slowSpeedMultiplier = settings.slowSpeedMultiplier
                fpvController.speedAdjustmentFactor = settings.speedAdjustmentFactor
                fpvController.rollSpeed = settings.rollSpeed
                fpvController.walkSettings = settings.walk
                fpvController.isRollEnabled = settings.extraControls.contains(.roll)
                wasdController.extraControls = settings.extraControls
            }
            .onChange(of: isMouseLookEnabled, initial: true) {
                fpvController.mouseTrackingEnabled = isMouseLookEnabled
                if !isMouseLookEnabled {
                    wasdController.releaseMouse()
                }
            }
            .task { await handleKeyboardEvents() }
            .task { await handleGameControllerEvents() }
            .task { await updateMovement() }
            .onChange(of: cameraMatrix, initial: true) {
                if cameraMatrix != fpvController.movementController.transform {
                    fpvController.setPose(cameraMatrix)
                }
            }
            .onChange(of: fpvController.movementController.transform) {
                cameraMatrix = fpvController.movementController.transform
            }
    }

    private func handleKeyboardEvents() async {
        for await event in wasdController.events {
            fpvController.process(event: event)
        }
    }

    private func handleGameControllerEvents() async {
        for await event in gameController.events {
            fpvController.process(event: event)
        }
    }

    private func updateMovement() async {
        let clock = ContinuousClock()
        var previousUpdate = clock.now
        for await _ in AsyncTimerSequence(interval: .milliseconds(8), clock: clock) {
            let updateTime = clock.now
            let deltaTime = previousUpdate.duration(to: updateTime).timeInterval
            previousUpdate = updateTime
            fpvController.hooks = hooksBox.hooks
            fpvController.update(deltaTime: deltaTime)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem {
            Button(wasdController.isMouseCaptured ? "Release Mouse" : "Capture Mouse") {
                wasdController.toggleMouseCapture()
            }
            .disabled(!fpvController.mouseTrackingEnabled)
        }

        ToolbarItem {
            Button("Reset to Origin") {
                fpvController.reset()
            }
        }
    }
}

public extension View {
    func fpvMovement(
        cameraMatrix: Binding<matrix_float4x4>,
        isMouseLookEnabled: Binding<Bool> = .constant(true),
        settings: FPVMovementSettings = .init(),
        hooks: FPVMovementHooks = .init(),
        showsControls: Bool = false
    ) -> some View {
        modifier(FPVMovementModifier(cameraMatrix: cameraMatrix, isMouseLookEnabled: isMouseLookEnabled, settings: settings, hooks: hooks, showsControls: showsControls))
    }
}

private extension Duration {
    var timeInterval: Float {
        let components = self.components
        return Float(components.seconds) + Float(components.attoseconds) / 1e18
    }
}
