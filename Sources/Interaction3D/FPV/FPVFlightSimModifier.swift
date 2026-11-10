#if os(macOS)

import simd
import SwiftUI

// FPV movement plus flight instruments (horizon, compass, map, speedometers), a game controller panel,
// and a toolbar with capture, reset, a settings popover and map zoom.
struct FPVFlightSimModifier: ViewModifier {
    let navigator: FPVNavigator
    let verticalFOV: CGFloat

    @State
    private var breadcrumbs: [SIMD2<Float>] = []

    @State
    private var mapScale: CGFloat = 2.0

    @State
    private var isShowingControlsPopover = false

    func body(content: Content) -> some View {
        content
            .modifier(FPVMovementModifier(navigator: navigator))
            .overlay {
                FlightSimControlsView(
                    transform: navigator.transform,
                    linearVelocity: navigator.linearVelocity,
                    angularVelocity: navigator.angularVelocity,
                    pitch: navigator.pitch,
                    verticalFOV: verticalFOV,
                    breadcrumbs: breadcrumbs,
                    mapScale: mapScale,
                    speed: navigator.speed
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
            .onChange(of: navigator.transform) {
                updateBreadcrumbs()
            }
    }

    private func updateBreadcrumbs() {
        let position = navigator.transform.columns.3
        breadcrumbs.append(SIMD2<Float>(position.x, position.z))
        if breadcrumbs.count > 300 {
            breadcrumbs.removeFirst(breadcrumbs.count - 300)
        }
    }

    private func reset() {
        navigator.reset()
        breadcrumbs.removeAll()
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
            Button(navigator.isMouseCaptured ? "Release Mouse" : "Capture Mouse") {
                navigator.toggleMouseCapture()
            }
            .disabled(!navigator.isMouseLookEnabled)
        }

        ToolbarItem {
            Button("Reset to Origin", action: reset)
        }

        ToolbarItem {
            Button {
                isShowingControlsPopover.toggle()
            } label: {
                Label("Flight Controls", systemImage: "slider.horizontal.3")
            }
            .popover(isPresented: $isShowingControlsPopover) {
                FlightControlsPanelView(navigator: navigator, onReset: reset)
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
    @Bindable
    var navigator: FPVNavigator

    let onReset: () -> Void

    var body: some View {
        VStack(alignment: .leading) {
            Text("Flight Controls")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Movement Speed") {
                    Text(navigator.speed, format: .number.precision(.fractionLength(1)))
                        .monospacedDigit()
                }
                Slider(value: $navigator.settings.speed, in: 1...50, step: 0.5)
            }

            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Mouse Sensitivity") {
                    Text(navigator.settings.mouseSensitivity, format: .number.precision(.fractionLength(3)))
                        .monospacedDigit()
                }
                Slider(value: $navigator.settings.mouseSensitivity, in: 0.001...0.05, step: 0.001)
            }

            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Controller Turn Speed") {
                    Text(navigator.settings.controllerTurnSpeed, format: .number.precision(.fractionLength(2)))
                        .monospacedDigit()
                }
                Slider(value: $navigator.settings.controllerTurnSpeed, in: 0.1...Float.pi * 2, step: 0.1)
            }

            Toggle("Mouse Look", isOn: $navigator.isMouseLookEnabled)
                .toggleStyle(.switch)

            Button("Reset", action: onReset)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

public extension View {
    // Settings, hooks and input live on the navigator.
    func fpvFlightSim(_ navigator: FPVNavigator, verticalFOV: CGFloat = 60) -> some View {
        modifier(FPVFlightSimModifier(navigator: navigator, verticalFOV: verticalFOV))
    }

    // Without a mouse look binding, the flight controls popover owns the toggle.
    func fpvFlightSim(
        cameraMatrix: Binding<matrix_float4x4>,
        isMouseLookEnabled: Binding<Bool>? = nil,
        settings: FPVMovementSettings = .init(),
        hooks: FPVMovementHooks = .init(),
        verticalFOV: CGFloat = 60
    ) -> some View {
        modifier(
            FPVCameraMatrixModifier(
                cameraMatrix: cameraMatrix,
                isMouseLookEnabled: isMouseLookEnabled,
                settings: settings,
                hooks: hooks,
                style: .flightSim(verticalFOV: verticalFOV)
            )
        )
    }
}

#endif
