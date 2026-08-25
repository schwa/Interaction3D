import SwiftUI

public enum AngleOfViewAxis: String, CaseIterable, Sendable {
    case horizontal = "H"
    case vertical = "V"
}

public struct AngleOfView: Equatable, Sendable {
    public var verticalDegrees: Double
    public var aspectRatio: Double

    public init(verticalDegrees: Double, aspectRatio: Double) {
        self.verticalDegrees = verticalDegrees
        self.aspectRatio = aspectRatio
    }

    public var horizontalDegrees: Double {
        guard aspectRatio > 0 else {
            return verticalDegrees
        }
        return 2 * atan(tan(verticalDegrees * .pi / 360) * aspectRatio) * 180 / .pi
    }

    public func degrees(for axis: AngleOfViewAxis) -> Double {
        axis == .horizontal ? horizontalDegrees : verticalDegrees
    }

    public static func verticalDegrees(from degrees: Double, axis: AngleOfViewAxis, aspectRatio: Double) -> Double {
        guard axis == .horizontal, aspectRatio > 0 else {
            return degrees
        }
        return 2 * atan(tan(degrees * .pi / 360) / aspectRatio) * 180 / .pi
    }
}

public struct AngleOfViewControl: View {
    @Binding private var verticalDegrees: Double
    private let aspectRatio: Double

    @State private var axis = AngleOfViewAxis.horizontal

    public init(verticalDegrees: Binding<Double>, aspectRatio: Double) {
        self._verticalDegrees = verticalDegrees
        self.aspectRatio = aspectRatio
    }

    public var body: some View {
        VStack {
            HStack {
                Text("Angle of view")
                Picker("Axis", selection: $axis) {
                    ForEach(AngleOfViewAxis.allCases, id: \.self) { axis in
                        Text(axis.rawValue).tag(axis)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()

                Spacer()
                ScrubbableValueField("Angle", value: displayedDegrees, suffix: "°", range: 1 ... 179, sensitivity: 0.2, precision: 0)
                    .labelsHidden()
            }

            Slider(value: displayedDegrees, in: 1 ... 179)
        }
    }

    private var displayedDegrees: Binding<Double> {
        Binding(
            get: { AngleOfView(verticalDegrees: verticalDegrees, aspectRatio: aspectRatio).degrees(for: axis) },
            set: { verticalDegrees = AngleOfView.verticalDegrees(from: $0, axis: axis, aspectRatio: aspectRatio) }
        )
    }
}

public struct ClippingRangeControl: View {
    @Binding private var near: Double
    @Binding private var far: Double

    public init(near: Binding<Double>, far: Binding<Double>) {
        self._near = near
        self._far = far
    }

    public var body: some View {
        HStack {
            Text("Clipping")
            Spacer()
            ScrubbableValueField("Near", value: nearValue, range: 0.0001 ... far, sensitivity: 0.001, precision: 3)
            ScrubbableValueField("Far", value: farValue, range: near ... 1_000_000, sensitivity: 0.1, precision: 1)
        }
    }

    private var nearValue: Binding<Double> {
        Binding(get: { near }, set: { near = min(max($0, 0.0001), far) })
    }

    private var farValue: Binding<Double> {
        Binding(get: { far }, set: { far = max($0, near) })
    }
}

#Preview {
    @Previewable @State var verticalAngle = 71.0
    @Previewable @State var near = 0.01
    @Previewable @State var far = 60.0

    Form {
        AngleOfViewControl(verticalDegrees: $verticalAngle, aspectRatio: 1.4)
        ClippingRangeControl(near: $near, far: $far)
    }
    .cameraControlStyle(.compact)
}
