import GeometryLite3D
import SwiftUI

struct FloatSlider<Value>: View where Value: BinaryFloatingPoint, Value.Stride: BinaryFloatingPoint {
    @Binding
    var value: Value
    let range: ClosedRange<Double>

    var body: some View {
        HStack {
            Text("\(Double(value), format: .number.precision(.fractionLength(2)))")
                .font(.system(.body, design: .monospaced))
                .frame(width: 60, alignment: .trailing)
            Slider(value: $value, in: Value(range.lowerBound) ... Value(range.upperBound))
        }
    }
}

struct AngleSlider: View {
    @Binding
    var value: AngleF

    var body: some View {
        HStack {
            Text("\(value.degrees, format: .number.precision(.fractionLength(1)))°")
                .font(.system(.body, design: .monospaced))
                .frame(width: 80, alignment: .trailing)
            Slider(value: $value.degrees, in: 0...360)
        }
    }
}

#Preview {
    @Previewable @State
    var floatValue = 0.5

    @Previewable @State
    var angleValue: AngleF = .degrees(45)

    Form {
        FloatSlider(value: $floatValue, range: 0...1)
        AngleSlider(value: $angleValue)
    }
    .padding()
}
