import DemoKit
import Interaction3D
import SwiftUI

struct NewGestureManagerDemo: View {
    @State private var drag: CGSize = .zero
    @State private var commandDrag: CGSize = .zero
    @State private var optionDragX: CGFloat = 0
    @State private var scrollValue: Double = 0
    @State private var magnifyValue: Double = 1.0
    @State private var lockZoom = true
    @State private var showInspector = true
    @State private var dragSensitivity: CGFloat = 0.02
    @State private var scrollSensitivity: Double = 0.05
    @State private var magnifySensitivity: Double = 2.0

    private let gridSize = 10
    private let dotSpacing: CGFloat = 30

    private var widthTransformer: some Transformer<CGSize, CGFloat> {
        KeyPathTransformer(keyPath: \CGSize.width) | ScalingTransformer(magnitude: dragSensitivity)
    }

    private var heightTransformer: some Transformer<CGSize, CGFloat> {
        KeyPathTransformer(keyPath: \CGSize.height) | ScalingTransformer(magnitude: dragSensitivity)
    }

    private var clampedWidthTransformer: some Transformer<CGSize, CGFloat> {
        KeyPathTransformer(keyPath: \CGSize.width) | ScalingTransformer(magnitude: dragSensitivity) | ClampingTransformer(range: CGFloat(-5)...5)
    }

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
        .newDragGesture([], transformer: widthTransformer, writes: $drag.width)
        .newDragGesture([], transformer: heightTransformer, writes: $drag.height)
        .newDragGesture(.command, transformer: widthTransformer, writes: $commandDrag.width)
        .newDragGesture(.command, transformer: heightTransformer, writes: $commandDrag.height)
        .newDragGesture(.option, transformer: clampedWidthTransformer, writes: $optionDragX)
        #if os(macOS)
        .newScrollGesture(transformer: ScalingTransformer(magnitude: scrollSensitivity), writes: lockZoom ? $scrollValue.synced(to: $magnifyValue) : $scrollValue)
        #endif
        .newMagnifyGesture(transformer: ScalingTransformer(magnitude: magnifySensitivity), writes: lockZoom ? $magnifyValue.synced(to: $scrollValue) : $magnifyValue)
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

                Section("Sensitivity") {
                    LabeledContent("Drag") {
                        Slider(value: $dragSensitivity, in: 0.001...0.1)
                    }
                    LabeledContent("Scroll") {
                        Slider(value: $scrollSensitivity, in: 0.01...0.5)
                    }
                    LabeledContent("Magnify") {
                        Slider(value: $magnifySensitivity, in: 0.1...10.0)
                    }
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

private extension Binding where Value: AdditiveArithmetic {
    func synced(to other: Binding<Value>) -> Binding<Value> {
        Binding(
            get: { self.wrappedValue },
            set: { newValue in
                self.wrappedValue = newValue
                other.wrappedValue = newValue
            }
        )
    }
}

extension NewGestureManagerDemo: DemoView {
    static var metadata = DemoMetadata(
        name: "Gesture Manager",
        description: "Composable gesture-to-binding system using ViewModifier chaining.",
        group: "Interaction"
    )
}
