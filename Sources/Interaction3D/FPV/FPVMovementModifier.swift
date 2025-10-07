import Interaction3D
import SceneKit
import simd
import SwiftUI

public struct FPVMovementModifier: ViewModifier {
    @Binding
    var cameraMatrix: matrix_float4x4

    let verticalFOV: CGFloat

    @State private var fpvController = FPVMovementController()
    @State private var wasdController = WASDController()
    @State private var gameController = GameControllerMovementController()
    @State private var positionTrail: [SIMD2<Float>] = []
    @State private var mapScale: CGFloat = 2.0
    @State private var isShowingControlsPopover = false

    public init(cameraMatrix: Binding<matrix_float4x4>, verticalFOV: CGFloat) {
        self._cameraMatrix = cameraMatrix
        self.verticalFOV = verticalFOV
    }

    public func body(content: Content) -> some View {
        content
            .focusable()
            .disableWASDKeys()
            .overlay(alignment: .topLeading) { navigationInstruments }
            .overlay(alignment: .topTrailing) { mapOverlay }
            .overlay(alignment: .bottomLeading) { speedometers }
            .overlay(alignment: .bottomTrailing) { infoPanel }
            .overlay(alignment: .leading) {
                GameControllerSnapshotView()
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .padding()
            }
            .toolbar { toolbarContent }
            .overlay {
                HorizonCue(
                    pitch: fpvController.pitch,
                    verticalFOV: verticalFOV
                )
                .allowsHitTesting(false)
            }
            .environment(fpvController.movementController)
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
        positionTrail.append(crumb)
        if positionTrail.count > 300 {
            positionTrail.removeFirst(positionTrail.count - 300)
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
                positionTrail.removeAll()
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
    }

    private var navigationInstruments: some View {
        HStack(alignment: .top, spacing: 12) {
            ArtificialHorizonView(transform: fpvController.movementController.transform)
                .frame(width: 150, height: 150)
                .cornerRadius(8)

            CompassView(heading: computedHeading, labelStyle: .axis)
                .frame(width: 150, height: 150)
                .cornerRadius(8)
        }
        .padding()
    }

    private var mapOverlay: some View {
        VStack(alignment: .trailing, spacing: 10) {
            MapView(
                transform: fpvController.movementController.transform,
                breadcrumbs: positionTrail,
                scale: mapScale
            )
            .frame(width: 200, height: 200)
            .cornerRadius(8)

            HStack(spacing: 10) {
                zoomButton(systemName: "plus") {
                    mapScale = min(mapScale * 1.2, 20)
                }
                zoomButton(systemName: "minus") {
                    mapScale = max(mapScale / 1.2, 0.25)
                }

                Text("\(Int(mapScale * 100))%")
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .padding(8)
            .background(Color.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding()
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
                positionTrail.removeAll()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var speedometers: some View {
        HStack(spacing: 12) {
            SpeedometerView()
                .frame(width: 240)
                .environment(fpvController.movementController)
        }
        .padding()
    }

    private var infoPanel: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("Heading: \(computedHeading.degrees, format: .number.precision(.fractionLength(1)))°")
            Text("Position: (\(fpvController.movementController.transform.columns.3.x, format: .number.precision(.fractionLength(1))), \(fpvController.movementController.transform.columns.3.y, format: .number.precision(.fractionLength(1))), \(fpvController.movementController.transform.columns.3.z, format: .number.precision(.fractionLength(1))))")
            Text("Speed: \(fpvController.speed, format: .number.precision(.fractionLength(1))) m/s")
        }
        .font(.caption)
        .foregroundStyle(.white)
        .padding(12)
        .background(Color.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding()
    }

    private var computedHeading: Angle {
        let m = fpvController.movementController.transform
        let forward = SIMD4<Float>(0, 0, -1, 0)
        let worldForward = m * forward
        let heading = atan2(Double(worldForward.x), Double(-worldForward.z))
        let normalizedHeading = heading < 0 ? heading + 2 * .pi : heading
        return Angle(radians: normalizedHeading)
    }

    private func zoomButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .padding(8)
                .background(Color.black.opacity(0.7), in: Circle())
                .accessibilityHidden(true)
        }
        .buttonStyle(.plain)
    }
}
