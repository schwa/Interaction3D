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
    let navigator: FPVNavigator
    let updatesAutomatically: Bool
    let showsControls: Bool

    @FocusState
    private var isFocused: Bool

    // updatesAutomatically: false means the app calls navigator.update(deltaTime:) from its own frame loop.
    // showsControls adds Capture Mouse and Reset toolbar buttons to the host window.
    public init(navigator: FPVNavigator, updatesAutomatically: Bool = true, showsControls: Bool = false) {
        self.navigator = navigator
        self.updatesAutomatically = updatesAutomatically
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
                navigator.isKeyboardEnabled = isFocused
            }
            .disableWASDKeys(extraControls: navigator.settings.extraControls)
            .toolbar {
                if showsControls {
                    toolbarContent
                }
            }
            .task { await navigator.runInput() }
            .task(id: updatesAutomatically) {
                if updatesAutomatically {
                    await navigator.runUpdates()
                }
            }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem {
            Button(navigator.isMouseCaptured ? "Release Mouse" : "Capture Mouse") {
                navigator.toggleMouseCapture()
            }
            .disabled(!navigator.isMouseLookEnabled)
        }

        ToolbarItem {
            Button("Reset to Origin") {
                navigator.reset()
            }
        }
    }
}

// FPV movement for a camera matrix binding, with a navigator it owns.
public struct FPVCameraMatrixModifier: ViewModifier {
    @Binding
    var cameraMatrix: matrix_float4x4

    @Binding
    var isMouseLookEnabled: Bool

    let settings: FPVMovementSettings
    let hooks: FPVMovementHooks
    let showsControls: Bool

    @State
    private var navigator = FPVNavigator()

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
        navigator.hooks = hooks
        return content
            .modifier(FPVMovementModifier(navigator: navigator, showsControls: showsControls))
            .onChange(of: settings, initial: true) {
                navigator.settings = settings
            }
            .onChange(of: isMouseLookEnabled, initial: true) {
                navigator.isMouseLookEnabled = isMouseLookEnabled
            }
            .onChange(of: cameraMatrix, initial: true) {
                if cameraMatrix != navigator.transform {
                    navigator.setPose(cameraMatrix)
                }
            }
            .onChange(of: navigator.transform) {
                cameraMatrix = navigator.transform
            }
    }
}

public extension View {
    // Settings, hooks and input live on the navigator.
    func fpvMovement(_ navigator: FPVNavigator, updatesAutomatically: Bool = true, showsControls: Bool = false) -> some View {
        modifier(FPVMovementModifier(navigator: navigator, updatesAutomatically: updatesAutomatically, showsControls: showsControls))
    }

    func fpvMovement(
        cameraMatrix: Binding<matrix_float4x4>,
        isMouseLookEnabled: Binding<Bool> = .constant(true),
        settings: FPVMovementSettings = .init(),
        hooks: FPVMovementHooks = .init(),
        showsControls: Bool = false
    ) -> some View {
        modifier(FPVCameraMatrixModifier(cameraMatrix: cameraMatrix, isMouseLookEnabled: isMouseLookEnabled, settings: settings, hooks: hooks, showsControls: showsControls))
    }
}
