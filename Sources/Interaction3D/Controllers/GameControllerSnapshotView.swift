import GameController
import SwiftUI

public struct GameControllerSnapshotView: View {
    @State private var display = SnapshotDisplay.empty

    public init() {
    }

    public var body: some View {
        TimelineView(.animation) { context in
            let date = context.date
            VStack(alignment: .leading, spacing: 4) {
                switch display.kind {
                case .none:
                    Text("No controller connected")
                        .font(.headline)
                case .extended, .standard, .micro:
                    Text(display.title)
                        .font(.headline)
                    ForEach(display.entries) { entry in
                        Text("\(entry.label): \(entry.value)")
                            .font(.system(.body, design: .monospaced))
                    }
                }
            }
            .padding(12)
            .onAppear { display = SnapshotDisplay.capture() }
            .onChange(of: date) { _, _ in display = SnapshotDisplay.capture() }
        }
    }
}

private struct SnapshotDisplay {
    enum Kind {
        case none
        case extended
        case standard
        case micro
    }

    struct Entry: Identifiable {
        let label: String
        let value: String
        var id: String { label }
    }

    let kind: Kind
    let title: String
    let entries: [Entry]

    static let empty = Self(kind: .none, title: "No Controller", entries: [])

    static func capture() -> Self {
        guard let controller = GCController.controllers().first else {
            return .empty
        }

        let rawName = controller.vendorName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = (rawName?.isEmpty == false ? rawName : nil) ?? "Game Controller"

        if let snapshot = controller.extendedGamepad?.saveSnapshot() {
            let entries: [Entry] = [
                Entry(label: "LeftStick X", value: format(snapshot.leftThumbstick.xAxis.value)),
                Entry(label: "LeftStick Y", value: format(snapshot.leftThumbstick.yAxis.value)),
                Entry(label: "RightStick X", value: format(snapshot.rightThumbstick.xAxis.value)),
                Entry(label: "RightStick Y", value: format(snapshot.rightThumbstick.yAxis.value)),
                Entry(label: "DPad X", value: format(snapshot.dpad.xAxis.value)),
                Entry(label: "DPad Y", value: format(snapshot.dpad.yAxis.value)),
                Entry(label: "L1", value: format(snapshot.leftShoulder.value)),
                Entry(label: "R1", value: format(snapshot.rightShoulder.value)),
                Entry(label: "L2", value: format(snapshot.leftTrigger.value)),
                Entry(label: "R2", value: format(snapshot.rightTrigger.value)),
                Entry(label: "Button A", value: format(snapshot.buttonA.value)),
                Entry(label: "Button B", value: format(snapshot.buttonB.value)),
                Entry(label: "Button X", value: format(snapshot.buttonX.value)),
                Entry(label: "Button Y", value: format(snapshot.buttonY.value))
            ]
            return Self(kind: .extended, title: "\(name) (Extended)", entries: entries)
        }

        if let snapshot = controller.gamepad?.saveSnapshot() {
            let entries: [Entry] = [
                Entry(label: "DPad X", value: format(snapshot.dpad.xAxis.value)),
                Entry(label: "DPad Y", value: format(snapshot.dpad.yAxis.value)),
                Entry(label: "L1", value: format(snapshot.leftShoulder.value)),
                Entry(label: "R1", value: format(snapshot.rightShoulder.value)),
                Entry(label: "Button A", value: format(snapshot.buttonA.value)),
                Entry(label: "Button B", value: format(snapshot.buttonB.value)),
                Entry(label: "Button X", value: format(snapshot.buttonX.value)),
                Entry(label: "Button Y", value: format(snapshot.buttonY.value))
            ]
            return Self(kind: .standard, title: "\(name) (Standard)", entries: entries)
        }

        if let snapshot = controller.microGamepad?.saveSnapshot() {
            let entries: [Entry] = [
                Entry(label: "DPad X", value: format(snapshot.dpad.xAxis.value)),
                Entry(label: "DPad Y", value: format(snapshot.dpad.yAxis.value)),
                Entry(label: "Button A", value: format(snapshot.buttonA.value)),
                Entry(label: "Button X", value: format(snapshot.buttonX.value))
            ]
            return Self(kind: .micro, title: "\(name) (Micro)", entries: entries)
        }

        return .empty
    }

    private static func format(_ value: Float) -> String {
        String(format: "%.2f", value)
    }
}

#Preview {
    GameControllerSnapshotView()
        .padding()
}
