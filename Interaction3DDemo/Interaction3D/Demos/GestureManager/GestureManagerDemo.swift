import DemoKit
import Interaction3D
import SwiftUI

struct GestureManagerDemo: View {
    @State private var drag: CGSize = .zero
    @State private var commandDrag: CGSize = .zero
    @State private var optionDragX: CGFloat = 0
    @State private var scrollValue: Double = 0
    @State private var magnifyValue: Double = 1.0
    @State private var lockZoom = true
    @State private var showInspector = true

    private let gridSize = 10
    private let dotSpacing: CGFloat = 30

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let gridExtent = CGFloat(gridSize) * dotSpacing
            let padding: CGFloat = dotSpacing / 2
            let gridRect = CGRect(
                x: center.x - gridExtent - padding,
                y: center.y - gridExtent - padding,
                width: (gridExtent + padding) * 2,
                height: (gridExtent + padding) * 2
            )
            let border = Path(roundedRect: gridRect, cornerRadius: 12)
            context.stroke(border, with: .color(.white.opacity(0.3)), lineWidth: 1)

            for row in -gridSize...gridSize {
                for col in -gridSize...gridSize {
                    let x = center.x + CGFloat(col) * dotSpacing
                    let y = center.y + CGFloat(row) * dotSpacing
                    let rect = CGRect(x: x, y: y, width: 1, height: 1)
                    context.fill(Path(rect), with: .color(.white))
                }
            }
        }
        .background(Color.black)
        .dragGesture([], transformer: KeyPathTransformer(keyPath: \CGSize.width) | ScalingTransformer(magnitude: 0.02), writes: $drag.width)
        .dragGesture([], transformer: KeyPathTransformer(keyPath: \CGSize.height) | ScalingTransformer(magnitude: 0.02), writes: $drag.height)
        .dragGesture(.command, transformer: KeyPathTransformer(keyPath: \CGSize.width) | ScalingTransformer(magnitude: 0.02), writes: $commandDrag.width)
        .dragGesture(.command, transformer: KeyPathTransformer(keyPath: \CGSize.height) | ScalingTransformer(magnitude: 0.02), writes: $commandDrag.height)
        .dragGesture(.option, transformer: KeyPathTransformer(keyPath: \CGSize.width) | ScalingTransformer(magnitude: 0.02) | ClampingTransformer(range: -5.0...5.0), writes: $optionDragX)
        #if os(macOS)
        .scrollGesture(transformer: ScalingTransformer(magnitude: 0.05), writes: lockZoom ? $scrollValue.synced(to: $magnifyValue) : $scrollValue)
        #endif
        .magnifyGesture(transformer: ScalingTransformer(magnitude: 2.0), writes: lockZoom ? $magnifyValue.synced(to: $scrollValue) : $magnifyValue)
        .overlay(alignment: .bottom) {
            VStack(spacing: 4) {
                Text("Drag horizontally")
                Text("⌘-Drag")
                Text("⌥-Drag")
                Text("Scroll wheel")
                Text("Pinch to magnify")
            }
            .font(.body)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            .padding()
        }
        .toolbar {
            Toggle(isOn: $showInspector) {
                Label("Inspector", systemImage: "sidebar.trailing")
            }
        }
        .inspector(isPresented: $showInspector) {
            Form {
                Section("Values") {
                    InspectorXYRow(label: "Drag", x: drag.width, y: drag.height)
                    InspectorXYRow(label: "⌘-Drag", x: commandDrag.width, y: commandDrag.height)
                    InspectorValueRow(label: "⌥-Drag X (clamped -5...5)", value: optionDragX)
                    InspectorValueRow(label: "Scroll", value: scrollValue)
                    Toggle("Lock", isOn: $lockZoom)
                    InspectorValueRow(label: "Magnify", value: magnifyValue)
                }

                Section("Actions") {
                    Button("Reset") {
                        drag = .zero
                        commandDrag = .zero
                        optionDragX = 0
                        scrollValue = 0
                        magnifyValue = 1.0
                    }
                }
            }
            .inspectorColumnWidth(min: 200, ideal: 250, max: 300)
        }
    }
}

// MARK: - Inspector Helpers

private struct InspectorXYRow: View {
    let label: String
    let x: Double
    let y: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.headline)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Text("X").foregroundStyle(.secondary)
                    Text(Double(x), format: .number.precision(.fractionLength(2)))
                        .contentTransition(.numericText())
                        .animation(.snappy, value: x)
                }
                HStack(spacing: 4) {
                    Text("Y").foregroundStyle(.secondary)
                    Text(Double(y), format: .number.precision(.fractionLength(2)))
                        .contentTransition(.numericText())
                        .animation(.snappy, value: y)
                }
            }
            .font(.system(size: 24, weight: .medium, design: .monospaced))
        }
    }
}

private struct InspectorValueRow: View {
    let label: String
    let value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(Double(value), format: .number.precision(.fractionLength(2)))
                .font(.system(size: 32, weight: .medium, design: .monospaced))
                .contentTransition(.numericText())
                .animation(.snappy, value: value)
        }
    }
}

extension GestureManagerDemo: DemoView {
    static var metadata = DemoMetadata(
        name: "Gesture Manager",
        description: "Composable gesture-to-binding system using ViewModifier chaining.",
        group: "Interaction"
    )
}
