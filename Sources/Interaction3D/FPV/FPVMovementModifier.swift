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

struct FPVMovementModifier: ViewModifier {
    let navigator: FPVNavigator
    let updatesAutomatically: Bool
    let showsControls: Bool

    @Environment(\.interactionDragFilter)
    private var dragFilter

    @Environment(\.interactionScrollFilter)
    private var scrollFilter

    // updatesAutomatically: false means the app calls navigator.update(deltaTime:) from its own frame loop.
    // showsControls adds Capture Mouse and Reset toolbar buttons to the host window.
    init(navigator: FPVNavigator, updatesAutomatically: Bool = true, showsControls: Bool = false) {
        self.navigator = navigator
        self.updatesAutomatically = updatesAutomatically
        self.showsControls = showsControls
    }

    func body(content: Content) -> some View {
        content
            .movementInputFocus(claiming: .fpvMovementKeys(extraControls: navigator.settings.extraControls)) { isFocused in
                navigator.isKeyboardEnabled = isFocused
            }
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    navigator.isLookAllowed = dragFilter?.accepts(location) ?? true
                    navigator.isScrollAllowed = scrollFilter?.accepts(location) ?? true
                case .ended:
                    navigator.isLookAllowed = false
                    navigator.isScrollAllowed = false
                }
            }
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
struct FPVCameraMatrixModifier: ViewModifier {
    enum Style {
        case movement(showsControls: Bool)
        #if os(macOS)
        case flightSim(verticalFOV: CGFloat)
        #endif
    }

    @Binding
    var cameraMatrix: matrix_float4x4

    // nil leaves mouse look to the navigator (the flight sim panel toggles it).
    let isMouseLookEnabled: Binding<Bool>?
    let settings: FPVMovementSettings
    let hooks: FPVMovementHooks
    let style: Style

    @State
    private var navigator = FPVNavigator()

    init(
        cameraMatrix: Binding<matrix_float4x4>,
        isMouseLookEnabled: Binding<Bool>? = nil,
        settings: FPVMovementSettings = .init(),
        hooks: FPVMovementHooks = .init(),
        style: Style = .movement(showsControls: false)
    ) {
        self._cameraMatrix = cameraMatrix
        self.isMouseLookEnabled = isMouseLookEnabled
        self.settings = settings
        self.hooks = hooks
        self.style = style
    }

    func body(content: Content) -> some View {
        navigator.hooks = hooks
        return styled(content)
            .onChange(of: settings, initial: true) {
                navigator.settings = settings
            }
            .onChange(of: isMouseLookEnabled?.wrappedValue, initial: true) {
                if let isMouseLookEnabled {
                    navigator.isMouseLookEnabled = isMouseLookEnabled.wrappedValue
                }
            }
            .onChange(of: navigator.isMouseLookEnabled) {
                isMouseLookEnabled?.wrappedValue = navigator.isMouseLookEnabled
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

    @ViewBuilder
    private func styled(_ content: Content) -> some View {
        switch style {
        case .movement(let showsControls):
            content.modifier(FPVMovementModifier(navigator: navigator, showsControls: showsControls))
        #if os(macOS)
        case .flightSim(let verticalFOV):
            content.modifier(FPVFlightSimModifier(navigator: navigator, verticalFOV: verticalFOV))
        #endif
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
        modifier(
            FPVCameraMatrixModifier(
                cameraMatrix: cameraMatrix,
                isMouseLookEnabled: isMouseLookEnabled,
                settings: settings,
                hooks: hooks,
                style: .movement(showsControls: showsControls)
            )
        )
    }
}
