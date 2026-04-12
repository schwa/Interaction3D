import GeometryLite3D
import SwiftUI

struct FloatSlider: View {
    @Binding
    var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        HStack {
            Text("\(value, format: .number.precision(.fractionLength(2)))")
                .font(.system(.body, design: .monospaced))
                .frame(width: 60, alignment: .trailing)
            Slider(value: $value, in: range)
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
            Slider(value: Binding(get: { Double(value.degrees) }, set: { value = .degrees(Float($0)) }), in: 0...360)
        }
    }
}
