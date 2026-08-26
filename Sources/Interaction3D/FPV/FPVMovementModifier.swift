#if os(macOS)

import AsyncAlgorithms
import simd
import SwiftUI

public struct FPVMovementModifier: ViewModifier {
    @Binding
    var cameraMatrix: matrix_float4x4

    @State
    private var fpvController = FPVMovementController()

    @State
    private var wasdController = WASDController()

    @State
    private var gameController = GameControllerMovementController()

    public init(cameraMatrix: Binding<matrix_float4x4>) {
        self._cameraMatrix = cameraMatrix
    }

    public func body(content: Content) -> some View {
        content
            .focusable()
            .disableWASDKeys()
            .toolbar { toolbarContent }
            .task { await handleKeyboardEvents() }
            .task { await handleGameControllerEvents() }
            .task { await updateMovement() }
            .onChange(of: fpvController.movementController.transform, initial: true) {
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
            Button(fpvController.mouseTrackingEnabled ? "Disable Mouse (⌘T)" : "Enable Mouse (⌘T)") {
                fpvController.mouseTrackingEnabled.toggle()
                if !fpvController.mouseTrackingEnabled, wasdController.isMouseCaptured {
                    wasdController.toggleMouseCapture()
                }
            }
            .keyboardShortcut("t", modifiers: .command)
        }

        ToolbarItem {
            Button(wasdController.isMouseCaptured ? "Release Mouse (⌘M)" : "Capture Mouse (⌘M)") {
                wasdController.toggleMouseCapture()
            }
            .keyboardShortcut("m", modifiers: .command)
            .disabled(!fpvController.mouseTrackingEnabled)
        }

        ToolbarItem {
            Button("Reset to Origin (⌘0)") {
                fpvController.reset()
            }
            .keyboardShortcut("0", modifiers: .command)
        }
    }
}

public extension View {
    func fpvMovement(cameraMatrix: Binding<matrix_float4x4>) -> some View {
        modifier(FPVMovementModifier(cameraMatrix: cameraMatrix))
    }
}

private extension Duration {
    var timeInterval: Float {
        let components = self.components
        return Float(components.seconds) + Float(components.attoseconds) / 1e18
    }
}

#endif
