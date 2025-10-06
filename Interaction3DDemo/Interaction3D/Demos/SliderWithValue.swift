import SwiftUI

struct SliderWithValue: View {
    var label: String
    @Binding var value: Double
    var range: ClosedRange<Double>

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                Spacer()
                Text(value.formatted(.number.precision(.fractionLength(1))) + "°")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Slider(value: $value, in: range)
        }
    }
}
