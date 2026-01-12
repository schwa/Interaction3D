#if os(macOS)

import simd
import SwiftUI

/// A full-featured FPV flight modifier that includes all flight simulation controls.
/// This is the "kitchen sink" version that shows navigation instruments, map, speedometers, etc.
/// For a minimal version without overlays, use `FPVMovementModifier`.
public struct FPVFlightSimModifier: ViewModifier {
    @Binding
    var cameraMatrix: matrix_float4x4

    let verticalFOV: CGFloat

    @State
    private var fpvController = FPVMovementController()

    @State
    private var wasdController = WASDController()

    @State
    private var gameController = GameControllerMovementController()

    @State
    private var breadcrumbs: [SIMD2<Float>] = []

    @State
    private var mapScale: CGFloat = 2.0

    @State
    private var isShowingControlsPopover = false

    public init(cameraMatrix: Binding<matrix_float4x4>, verticalFOV: CGFloat = 60) {
        self._cameraMatrix = cameraMatrix
        self.verticalFOV = verticalFOV
    }

    public func body(content: Content) -> some View {
        content
            .focusable()
            .disableWASDKeys()
            .overlay {
                FlightSimControlsView(
                    transform: fpvController.movementController.transform,
                    linearVelocity: fpvController.movementController.linearVelocity,
                    angularVelocity: fpvController.movementController.angularVelocity,
                    pitch: fpvController.pitch,
                    verticalFOV: verticalFOV,
                    breadcrumbs: breadcrumbs,
                    mapScale: mapScale,
                    speed: fpvController.speed
                )
                .allowsHitTesting(false)
            }
            .overlay(alignment: .leading) {
                GameControllerSnapshotView()
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .padding()
            }
            .toolbar { toolbarContent }
            .task { await handleKeyboardEvents() }
            .task { await handleGameControllerEvents() }
            .onChange(of: fpvController.movementController.transform, initial: true) {
                cameraMatrix = fpvController.movementController.transform
                updateBreadcrumbs()
            }
    }

    private func handleKeyboardEvents() async {
        for await event in wasdController.events {
            await MainActor.run {
                fpvController.process(event: event)
            }
        }
    }

    private func handleGameControllerEvents() async {
        for await event in gameController.events {
            await MainActor.run {
                fpvController.process(event: event)
            }
        }
    }

    private func updateBreadcrumbs() {
        let position = fpvController.movementController.transform.columns.3
        let crumb = SIMD2<Float>(position.x, position.z)
        breadcrumbs.append(crumb)
        if breadcrumbs.count > 300 {
            breadcrumbs.removeFirst(breadcrumbs.count - 300)
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
                breadcrumbs.removeAll()
            }
            .keyboardShortcut("0", modifiers: .command)
        }

        ToolbarItem {
            Button {
                isShowingControlsPopover.toggle()
            } label: {
                Label("Flight Controls", systemImage: "slider.horizontal.3")
            }
            .popover(isPresented: $isShowingControlsPopover) {
                controlsPanel
                    .padding(20)
                    .frame(minWidth: 320)
            }
        }

        ToolbarItem {
            HStack(spacing: 4) {
                Button {
                    mapScale = max(mapScale / 1.2, 0.25)
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                }

                Button {
                    mapScale = min(mapScale * 1.2, 20)
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                }
            }
        }
    }

    private var controlsPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Flight Controls")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Movement Speed")
                    Spacer()
                    Text(fpvController.speed, format: .number.precision(.fractionLength(1)))
                        .monospacedDigit()
                }
                Slider(value: $fpvController.speed, in: 1...50, step: 0.5)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Mouse Sensitivity")
                    Spacer()
                    Text(fpvController.mouseSensitivity, format: .number.precision(.fractionLength(3)))
                        .monospacedDigit()
                }
                Slider(value: $fpvController.mouseSensitivity, in: 0.001...0.05, step: 0.001)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Controller Turn Speed")
                    Spacer()
                    Text(fpvController.controllerTurnSpeed, format: .number.precision(.fractionLength(2)))
                        .monospacedDigit()
                }
                Slider(
                    value: Binding(
                        get: { Double(fpvController.controllerTurnSpeed) },
                        set: { fpvController.controllerTurnSpeed = Float($0) }
                    ),
                    in: 0.1...Double.pi * 2,
                    step: 0.1
                )
            }

            Toggle("Capture Mouse", isOn: $fpvController.mouseTrackingEnabled)
                .toggleStyle(.switch)

            Button("Reset") {
                fpvController.reset()
                breadcrumbs.removeAll()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

public extension View {
    func fpvFlightSim(cameraMatrix: Binding<matrix_float4x4>, verticalFOV: CGFloat = 60) -> some View {
        modifier(FPVFlightSimModifier(cameraMatrix: cameraMatrix, verticalFOV: verticalFOV))
    }
}

#endif
