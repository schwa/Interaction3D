import SwiftUI

public struct ScrubbableValueField: View {
    private let label: LocalizedStringKey
    private let suffix: String
    private let range: ClosedRange<Double>?
    private let sensitivity: Double
    private let precision: Int

    @Binding private var value: Double
    @Environment(\.cameraControlStyle) private var style
    @Environment(\.labelsVisibility) private var labelsVisibility
    @State private var dragStartValue: Double?

    public init(_ label: LocalizedStringKey, value: Binding<Double>, suffix: String = "", range: ClosedRange<Double>? = nil, sensitivity: Double = 0.01, precision: Int = 1) {
        self.label = label
        self._value = value
        self.suffix = suffix
        self.range = range
        self.sensitivity = sensitivity
        self.precision = precision
    }

    public var body: some View {
        HStack(spacing: style.fieldSpacing) {
            if labelsVisibility != .hidden {
                Text(label)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize()
                    .frame(minWidth: style.labelWidth, alignment: .leading)
                    .contentShape(.rect)
                    .gesture(scrubGesture)
                    .accessibilityHint("Drag horizontally to adjust")
            }
            TextField(label, value: clampedValue, format: .number.precision(.fractionLength(precision)))
                .labelsHidden()
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .frame(width: style.valueWidth)

            if !suffix.isEmpty {
                Text(suffix)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var clampedValue: Binding<Double> {
        Binding(
            get: { value },
            set: { newValue in
                value = range.map { min(max(newValue, $0.lowerBound), $0.upperBound) } ?? newValue
            }
        )
    }

    private var scrubGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { gesture in
                let initialValue = dragStartValue ?? value
                dragStartValue = initialValue
                clampedValue.wrappedValue = initialValue + gesture.translation.width * sensitivity
            }
            .onEnded { _ in
                dragStartValue = nil
            }
    }
}

#Preview {
    @Previewable @State var value = 42.5

    ScrubbableValueField("X", value: $value, suffix: "°", range: -180 ... 180)
        .cameraControlStyle(.compact)
        .padding()
}
