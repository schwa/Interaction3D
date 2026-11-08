import AsyncAlgorithms
import simd
import SwiftUI

public struct FPVMovementSettings: Equatable, Sendable {
    public var speed: Float
    public var fastSpeedMultiplier: Float
    public var mouseSensitivity: Float
    public var controllerTurnSpeed: Float
    public var keyboardTurnSpeed: Float
    public var isMouseLookEnabled: Bool
    public var isFreeFlightEnabled: Bool

    public init(
        speed: Float = 10,
        fastSpeedMultiplier: Float = 4,
        mouseSensitivity: Float = 0.01,
        controllerTurnSpeed: Float = .pi,
        keyboardTurnSpeed: Float = .pi / 2,
        isMouseLookEnabled: Bool = true,
        isFreeFlightEnabled: Bool = false
    ) {
        self.isFreeFlightEnabled = isFreeFlightEnabled
        self.isMouseLookEnabled = isMouseLookEnabled
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

    let showsControls: Bool
    let settings: FPVMovementSettings

    // showsControls adds Capture Mouse and Reset toolbar buttons to the host window.
    public init(cameraMatrix: Binding<matrix_float4x4>, settings: FPVMovementSettings = .init(), showsControls: Bool = false) {
        self._cameraMatrix = cameraMatrix
        self.settings = settings
        self.showsControls = showsControls
    }

    public func body(content: Content) -> some View {
        content
            .focusable()
            .focused($isFocused)
            .task {
                // Claim focus on appear so WASD works without a click.
                isFocused = true
            }
            .onChange(of: isFocused, initial: true) {
                wasdController.isKeyboardEnabled = isFocused
            }
            .disableWASDKeys()
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
                fpvController.mouseTrackingEnabled = settings.isMouseLookEnabled
                fpvController.isFreeFlightEnabled = settings.isFreeFlightEnabled
                if !settings.isMouseLookEnabled {
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
    func fpvMovement(cameraMatrix: Binding<matrix_float4x4>, settings: FPVMovementSettings = .init(), showsControls: Bool = false) -> some View {
        modifier(FPVMovementModifier(cameraMatrix: cameraMatrix, settings: settings, showsControls: showsControls))
    }
}

private extension Duration {
    var timeInterval: Float {
        let components = self.components
        return Float(components.seconds) + Float(components.attoseconds) / 1e18
    }
}
