import simd
import SwiftUI

public struct MatrixEditor <Value, Style>: View where Value: Matrix, Style: ParseableFormatStyle, Style.FormatInput == Value.Scalar, Style.FormatOutput == String {
    @Binding
    var value: Value

    var style: Style

    public init(value: Binding<Value>, style: Style) {
        self._value = value
        self.style = style
    }

    public var body: some View {
        Grid {
            ForEach(0..<value.height, id: \.self) { row in
                GridRow {
                    ForEach(0..<value.width, id: \.self) { column in
                        let binding = Binding<Value.Scalar>(
                            get: { value[row, column] },
                            set: { newValue in value[row, column] = newValue }
                        )
                        TextField(value: binding, format: style) {
                            // This line intentionally left blank
                        }
                        .labelsHidden()
                    }
                }
            }
        }
    }
}

#Preview {
    @Previewable @State
    var matrix: float4x4 = .init(diagonal: [1, 2, 3, 4])

    MatrixEditor(value: $matrix, style: .number)
}
