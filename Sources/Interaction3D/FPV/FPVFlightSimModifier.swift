#if os(macOS)

import simd
import SwiftUI

/// A full-featured FPV flight modifier that includes all flight simulation controls.
/// This is the "kitchen sink" version that shows navigation instruments, map, speedometers, etc.
/// For a minimal version without overlays, use `FPVMovementModifier`.
struct FPVFlightSimModifier: ViewModifier {
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

    @State
    private var localMouseLookEnabled = true

    private let externalMouseLookEnabled: Binding<Bool>?

    // Without a binding, the controls popover owns the mouse look toggle.
    private var isMouseLookEnabled: Binding<Bool> {
        externalMouseLookEnabled ?? $localMouseLookEnabled
    }

    init(cameraMatrix: Binding<matrix_float4x4>, isMouseLookEnabled: Binding<Bool>? = nil, verticalFOV: CGFloat = 60) {
        self._cameraMatrix = cameraMatrix
        self.externalMouseLookEnabled = isMouseLookEnabled
        self.verticalFOV = verticalFOV
    }

    func body(content: Content) -> some View {
        content
            .movementInputFocus(claiming: .fpvMovementKeys()) { isFocused in
                wasdController.isKeyboardEnabled = isFocused
            }
            .onChange(of: isMouseLookEnabled.wrappedValue, initial: true) {
                fpvController.mouseTrackingEnabled = isMouseLookEnabled.wrappedValue
                if !isMouseLookEnabled.wrappedValue {
                    wasdController.releaseMouse()
                }
            }
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
            .onChange(of: cameraMatrix, initial: true) {
                if cameraMatrix != fpvController.movementController.transform {
                    fpvController.setPose(cameraMatrix)
                }
            }
            .onChange(of: fpvController.movementController.transform) {
                cameraMatrix = fpvController.movementController.transform
                updateBreadcrumbs()
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

    private func updateBreadcrumbs() {
        let position = fpvController.movementController.transform.columns.3
        let crumb = SIMD2<Float>(position.x, position.z)
        breadcrumbs.append(crumb)
        if breadcrumbs.count > 300 {
            breadcrumbs.removeFirst(breadcrumbs.count - 300)
        }
    }

    private func zoomMapOut() {
        mapScale = max(mapScale / 1.2, 0.25)
    }

    private func zoomMapIn() {
        mapScale = min(mapScale * 1.2, 20)
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
                breadcrumbs.removeAll()
            }
        }

        ToolbarItem {
            Button {
                isShowingControlsPopover.toggle()
            } label: {
                Label("Flight Controls", systemImage: "slider.horizontal.3")
            }
            .popover(isPresented: $isShowingControlsPopover) {
                FlightControlsPanelView(fpvController: $fpvController, isMouseLookEnabled: isMouseLookEnabled, breadcrumbs: $breadcrumbs)
                    .padding()
                    .frame(minWidth: 320)
            }
        }

        ToolbarItem {
            HStack(spacing: 4) {
                Button("Zoom Map Out", systemImage: "minus.magnifyingglass", action: zoomMapOut)
                    .labelStyle(.iconOnly)

                Button("Zoom Map In", systemImage: "plus.magnifyingglass", action: zoomMapIn)
                    .labelStyle(.iconOnly)
            }
        }
    }

}

struct FlightControlsPanelView: View {
    @Binding
    var fpvController: FPVMovementController

    @Binding
    var isMouseLookEnabled: Bool

    @Binding
    var breadcrumbs: [SIMD2<Float>]

    var body: some View {
        VStack(alignment: .leading) {
            Text("Flight Controls")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Movement Speed") {
                    Text(fpvController.speed, format: .number.precision(.fractionLength(1)))
                        .monospacedDigit()
                }
                Slider(value: $fpvController.speed, in: 1...50, step: 0.5)
            }

            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Mouse Sensitivity") {
                    Text(fpvController.mouseSensitivity, format: .number.precision(.fractionLength(3)))
                        .monospacedDigit()
                }
                Slider(value: $fpvController.mouseSensitivity, in: 0.001...0.05, step: 0.001)
            }

            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Controller Turn Speed") {
                    Text(fpvController.controllerTurnSpeed, format: .number.precision(.fractionLength(2)))
                        .monospacedDigit()
                }
                Slider(value: $fpvController.controllerTurnSpeed, in: 0.1...Float.pi * 2, step: 0.1)
            }

            Toggle("Mouse Look", isOn: $isMouseLookEnabled)
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
    func fpvFlightSim(cameraMatrix: Binding<matrix_float4x4>, isMouseLookEnabled: Binding<Bool>? = nil, verticalFOV: CGFloat = 60) -> some View {
        modifier(FPVFlightSimModifier(cameraMatrix: cameraMatrix, isMouseLookEnabled: isMouseLookEnabled, verticalFOV: verticalFOV))
    }
}

#endif
