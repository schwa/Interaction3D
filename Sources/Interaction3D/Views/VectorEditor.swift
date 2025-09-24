import simd
import SwiftUI

public struct VectorEditor <Value, Label, Style>: View where Value: SIMD, Style: ParseableFormatStyle, Style.FormatInput == Value.Scalar, Style.FormatOutput == String, Label: View {

    @Binding
    var value: Value

    var style: Style

    @ViewBuilder
    var labels: Label

    @Environment(\.labelsVisibility)
    var labelsVisibility

    public init(value: Binding<Value>, style: Style, @ViewBuilder labels: () -> Label) {
        self._value = value
        self.style = style
        self.labels = labels()
    }

    public var body: some View {
        HStack {
            Group(subviews: labels) { collection in
                ForEach(collection[..<value.scalarCount].enumerated(), id: \.offset) { offset, label in
                    if labelsVisibility != .hidden {
                        LabeledContent {
                            TextField(value: $value.scalars[offset], format: style) { label }
                                .labelsVisibility(.hidden)
                        }
                        label: {
                            label
                        }
                    }
                    else {
                        TextField(value: $value.scalars[offset], format: style) { label }
                            .labelsVisibility(.hidden)
                    }
                }
            }
        }
    }
}

public extension VectorEditor {

    enum VectorSemantics {
        case point
        case direction
        case color
        case quaternion
        case scale
    }

    init<T>(value: Binding<SIMD3<T>>, style: Style, semantic: VectorSemantics) where Value == SIMD3<T>, T: SIMDScalar, Label == TupleView<(Text, Text, Text)> {
        switch semantic {
        case .point, .direction:
            self.init(value: value, style: style) {
                Text("X")
                Text("Y")
                Text("Z")
            }
        case .color:
            self.init(value: value, style: style) {
                Text("Red")
                Text("Green")
                Text("Blue")
            }
        case .quaternion:
            fatalError("Quaternion editing not implemented")
        case .scale:
            self.init(value: value, style: style) {
                Text("X")
                Text("Y")
                Text("Z")
            }
        }
    }

    init<T>(value: Binding<SIMD4<T>>, style: Style, semantic: VectorSemantics) where Value == SIMD4<T>, T: SIMDScalar, Label == TupleView<(Text, Text, Text, Text)> {
        switch semantic {
        case .point, .direction:
            self.init(value: value, style: style) {
                Text("X")
                Text("Y")
                Text("Z")
                Text("W")
            }
        case .color:
            self.init(value: value, style: style) {
                Text("Red")
                Text("Green")
                Text("Blue")
                Text("Alpha")
            }
        case .quaternion:
            self.init(value: value, style: style) {
                Text("Imaginary X")
                Text("Imaginary Y")
                Text("Imaginary Z")
                Text("Real")
            }
        case .scale:
            self.init(value: value, style: style) {
                Text("Width")
                Text("Height")
                Text("Depth")
                Text("W")
            }
        }
    }

}

#Preview {
    @Previewable @State
    var vector: SIMD4<Float> = .zero

    VectorEditor(value: $vector, style: .number, semantic: .point)
    VectorEditor(value: $vector, style: .number, semantic: .scale)
    VectorEditor(value: $vector, style: .number, semantic: .quaternion)
    VectorEditor(value: $vector, style: .number, semantic: .color)

}
