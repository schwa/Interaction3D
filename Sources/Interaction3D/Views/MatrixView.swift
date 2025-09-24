import simd
import SwiftUI

public struct MatrixView<Value, Style>: View where Value: Matrix, Style: FormatStyle, Style.FormatInput == Value.Scalar, Style.FormatOutput == String {
    var value: Value
    var style: Style
    var colorize: Bool

    public init(value: Value, style: Style, colorize: Bool = false) {
        self.value = value
        self.style = style
        self.colorize = colorize
    }

    private func styleForPosition(row: Int, column: Int) -> ShapeStyle {
        guard colorize else {
            return .foreground
        }

        // For a 4x4 transformation matrix:
        // Column 3 (rightmost) contains translation (X, Y, Z, W)
        if column == 3 {
            switch row {
            case 0: return .red    // X translation
            case 1: return .green  // Y translation
            case 2: return .blue   // Z translation
            case 3: return .foreground  // W component (usually 1)
            default:
                return .foreground
            }
        } else if row < 3 {
            // Top-left 3x3 contains rotation/scale
            return .yellow
        }

        return .foreground
    }

    public var body: some View {
        Grid {
            ForEach(0..<value.height, id: \.self) { row in
                GridRow {
                    ForEach(0..<value.width, id: \.self) { column in
                        Text(style.format(value[row, column]))
                            .foregroundStyle(styleForPosition(row: row, column: column))
                    }
                }
            }
        }
    }
}

#Preview {
    @Previewable @State
    var matrix: float4x4 = .init(diagonal: [1, 2, 3, 4])

    MatrixView(value: matrix, style: .number.precision(.fractionLength(2)))
}
