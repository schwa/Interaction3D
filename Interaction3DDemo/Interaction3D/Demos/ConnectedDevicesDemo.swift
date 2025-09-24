import DemoKit
import GameController
import Observation
import SwiftUI

struct ConnectedDevicesDemo: DemoView {
    static var metadata = DemoMetadata(
        name: "Input Devices",
        systemImage: "gamecontroller",
        description: "Inspect all GameController devices currently attached to this Mac.",
        group: "Diagnostics",
        keywords: ["controller", "keyboard", "mouse", "game controller", "input"],
        color: .purple
    )

    var body: some View {
        ConnectedDevicesView()
    }
}

private struct ConnectedDevicesView: View {
    @State private var store = GameInputDeviceStore()

    var body: some View {
        @Bindable var storeBinding = store
        List {
            if storeBinding.devices.isEmpty {
                ContentUnavailableView("No Devices", systemImage: "questionmark.app.dashed", description: Text("Connect a supported controller, keyboard, or pointing device to populate this list."))
            } else {
                ForEach(storeBinding.devices) { device in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Image(systemName: device.iconName)
                                .foregroundStyle(device.tint)
                                .accessibilityHidden(true)
                            Text(device.name)
                                .font(.headline)
                            Spacer()
                            Text(device.kind.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if let detail = device.detail, !detail.isEmpty {
                            Text(detail)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        if !device.capabilities.isEmpty {
                            Text(device.capabilities.joined(separator: " • "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.automatic)
        #endif
        .overlay(alignment: .bottomLeading) {
            if let lastUpdated = storeBinding.lastUpdated {
                Text("Updated \(lastUpdated.formatted(date: .omitted, time: .standard))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding([.horizontal, .bottom])
            }
        }
        .navigationTitle("Connected Devices")
        .toolbar {
            Button {
                storeBinding.refreshDevices()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .help("Force a refresh of the connected device list")
        }
    }
}

@MainActor
@Observable
private final class GameInputDeviceStore {
    struct Device: Identifiable {
        enum Kind: String {
            case controller = "Controller"
            case keyboard = "Keyboard"
            case mouse = "Mouse"
            case unknown = "Unknown"
        }

        let id: String
        let kind: Kind
        let name: String
        let detail: String?
        let capabilities: [String]
        let iconName: String
        let tint: Color
    }

    private(set) var devices: [Device] = []
    private(set) var lastUpdated: Date?

    @ObservationIgnored
    private var observers: [NSObjectProtocol] = []

    init() {
        refreshDevices()
        startMonitoring()
    }

    deinit {
        MainActor.assumeIsolated {
            stopMonitoring()
        }
    }

    func refreshDevices() {
        var deduped: [String: Device] = [:]

        for controller in GCController.controllers() {
            let device = device(for: controller)
            deduped[device.id] = device
        }

        if let keyboard = GCKeyboard.coalesced {
            let device = device(for: keyboard)
            deduped[device.id] = device
        }

        for mouse in GCMouse.mice() {
            let device = device(for: mouse)
            deduped[device.id] = device
        }

        let sorted = deduped.values.sorted { lhs, rhs in
            if lhs.kind == rhs.kind {
                return lhs.name < rhs.name
            }
            return lhs.kind.sortOrder < rhs.kind.sortOrder
        }

        devices = sorted
        lastUpdated = Date()
    }

    private func startMonitoring() {
        let center = NotificationCenter.default
        let names: [Notification.Name] = [
            .GCControllerDidConnect,
            .GCControllerDidDisconnect,
            .GCControllerDidBecomeCurrent,
            .GCControllerDidStopBeingCurrent,
            .GCKeyboardDidConnect,
            .GCKeyboardDidDisconnect,
            .GCKeyboardDidBecomeCurrent,
            .GCKeyboardDidStopBeingCurrent,
            .GCMouseDidConnect,
            .GCMouseDidDisconnect,
            .GCMouseDidBecomeCurrent,
            .GCMouseDidStopBeingCurrent
        ]

        observers = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                guard let self else {
                    return
                }
                Task { @MainActor in
                    self.refreshDevices()
                }
            }
        }
    }

    private func stopMonitoring() {
        let center = NotificationCenter.default
        observers.forEach { center.removeObserver($0) }
        observers.removeAll()
    }

    private func device(for controller: GCController) -> Device {
        let identifier = "controller-\(Unmanaged.passUnretained(controller).toOpaque())"
        var attributes: [String] = []

        if let vendor = controller.vendorName, !vendor.isEmpty {
            attributes.append(vendor)
        }
        let category = controller.productCategory
        if !category.isEmpty {
            attributes.append(category)
        }
        if controller.isAttachedToDevice {
            attributes.append("Built-in")
        }
        if controller.playerIndex != .indexUnset {
            attributes.append("Player \(controller.playerIndex.rawValue + 1)")
        }

        var capabilities: [String] = []
        if controller.extendedGamepad != nil {
            capabilities.append("Extended Gamepad")
        }
        if controller.microGamepad != nil {
            capabilities.append("Micro Gamepad")
        }
        if controller.motion != nil {
            capabilities.append("Motion Sensors")
        }
        if controller.haptics != nil {
            capabilities.append("Haptics")
        }
        if controller.isSnapshot {
            capabilities.append("Snapshot")
        }

        let vendorName = controller.vendorName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = vendorName?.isEmpty == false ? vendorName : nil
        let name = resolvedName ?? (category.isEmpty ? "Controller" : category)
        return Device(
            id: identifier,
            kind: .controller,
            name: name,
            detail: attributes.joined(separator: " • "),
            capabilities: capabilities,
            iconName: "gamecontroller.fill",
            tint: .blue
        )
    }

    private func device(for keyboard: GCKeyboard) -> Device {
        let identifier = "keyboard-coalesced"
        let vendorName = keyboard.keyboardInput?.device?.vendorName
        let resolvedName = vendorName?.isEmpty == false ? vendorName : nil
        let name = resolvedName ?? "Keyboard"
        var attributes: [String] = []
        if let vendor = keyboard.keyboardInput?.device?.vendorName, !vendor.isEmpty {
            attributes.append(vendor)
        }
        attributes.append("Coalesced")

        return Device(
            id: identifier,
            kind: .keyboard,
            name: name,
            detail: attributes.joined(separator: " • "),
            capabilities: ["Key Events"],
            iconName: "keyboard",
            tint: .green
        )
    }

    private func device(for mouse: GCMouse) -> Device {
        let identifier = "mouse-\(Unmanaged.passUnretained(mouse).toOpaque())"
        let deviceInfo = mouse.mouseInput?.device
        let vendorName = deviceInfo?.vendorName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let category = deviceInfo?.productCategory ?? ""
        let resolvedName = vendorName?.isEmpty == false ? vendorName : nil
        let name = resolvedName ?? (category.isEmpty ? "Mouse" : category)
        var attributes: [String] = []
        if let vendor = vendorName, !vendor.isEmpty {
            attributes.append(vendor)
        }
        if !category.isEmpty {
            attributes.append(category)
        }
        if mouse == GCMouse.current {
            attributes.append("Current")
        }

        var capabilities: [String] = []
        if mouse.mouseInput != nil {
            capabilities.append("Pointer Delta")
        }
        if mouse.mouseInput?.scroll != nil {
            capabilities.append("Scroll")
        }
        if mouse.mouseInput?.rightButton != nil {
            capabilities.append("Secondary Button")
        }
        if mouse.mouseInput?.middleButton != nil {
            capabilities.append("Middle Button")
        }
        if let auxiliary = mouse.mouseInput?.auxiliaryButtons, !auxiliary.isEmpty {
            capabilities.append("Auxiliary Buttons x\(auxiliary.count)")
        }

        return Device(
            id: identifier,
            kind: .mouse,
            name: name,
            detail: attributes.joined(separator: " • "),
            capabilities: capabilities,
            iconName: "computermouse",
            tint: .pink
        )
    }
}

private extension GameInputDeviceStore.Device.Kind {
    var sortOrder: Int {
        switch self {
        case .controller:
            return 0
        case .keyboard:
            return 1
        case .mouse:
            return 2
        case .unknown:
            return 3
        }
    }
}

#if os(macOS)
private extension Notification.Name {
    static let GCKeyboardDidBecomeCurrent = Notification.Name("GCKeyboardDidBecomeCurrentNotification")
    static let GCKeyboardDidStopBeingCurrent = Notification.Name("GCKeyboardDidStopBeingCurrentNotification")
}
#endif
