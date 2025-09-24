import simd
import SwiftUI

public typealias SpeedometerDialView = MeasurementDial<UnitSpeed>

// TODO: Make ignorant of UnitSpeed and rename to measurement dial.
public struct MeasurementDial <U>: View where U: Dimension {
    var measurement: Measurement<U>
    var maxMeasurement: Measurement<U>
    var displayUnit: U
    var format: FloatingPointFormatStyle<Double>
    var minorTick: Measurement<U>
    var majorTick: Measurement<U>
    var labels: [Measurement<U>]

    public init(measurement: Measurement<U>, maxMeasurement: Measurement<U>, displayUnit: U, format: FloatingPointFormatStyle<Double> = .number, minorTick: Measurement<U>, majorTick: Measurement<U>, labels: [Measurement<U>]) {
        self.measurement = measurement
        self.maxMeasurement = maxMeasurement
        self.displayUnit = displayUnit
        self.format = format
        self.minorTick = minorTick
        self.majorTick = majorTick
        self.labels = labels
    }

    public var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - 1

            context.translateBy(x: center.x, y: center.y)

            let outerCircle = Path.circle(center: .zero, radius: radius)
            context.stroke(outerCircle, with: .color(.white.opacity(0.3)), lineWidth: 2)

            let speedRatio = min(measurement.value / maxMeasurement.value, 1.0)

            let startAngle = Angle(degrees: 135)
            let endAngle = Angle(degrees: 360 + 45)
            let sweepAngle = 270.0
            let currentAngle = startAngle.degrees + speedRatio * sweepAngle

            let speedArc = Path { path in
                path.addArc(center: .zero, radius: radius - 5, startAngle: startAngle, endAngle: Angle(degrees: currentAngle), clockwise: false)
            }

            let speedColor: Color
            if speedRatio < 0.333 {
                speedColor = .green
            } else if speedRatio < 0.666 {
                speedColor = .yellow
            } else {
                speedColor = .red
            }
            context.stroke(speedArc, with: .color(speedColor), lineWidth: 4)

            for tick in stride(from: 0, through: maxMeasurement.value, by: minorTick.value) {
                guard tick.truncatingRemainder(dividingBy: majorTick.value) != 0 else {
                    continue
                }
                let angle = lerp(start: startAngle, end: endAngle, t: tick / maxMeasurement.value)
                let path = Path { path in
                    path.move(to: CGPoint(angle: angle, radius: radius))
                    path.addLine(to: CGPoint(angle: angle, radius: radius * 0.95))
                }
                context.stroke(path, with: .color(.white), lineWidth: 2)
            }
            for tick in stride(from: 0, through: maxMeasurement.value, by: majorTick.value) {
                let angle = lerp(start: startAngle, end: endAngle, t: tick / maxMeasurement.value)
                let path = Path { path in
                    path.move(to: CGPoint(angle: angle, radius: radius))
                    path.addLine(to: CGPoint(angle: angle, radius: radius * 0.9))
                }
                context.stroke(path, with: .color(.white), lineWidth: 2)
            }
            for label in labels {
                let angle = lerp(start: startAngle, end: endAngle, t: label.value / maxMeasurement.value)
                let labelPoint = CGPoint(angle: angle, radius: radius * 0.8)

                let convertedLabel = label.converted(to: displayUnit)

                let text = Text("\(convertedLabel.value, format: format)")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.7))
                context.draw(text, at: labelPoint, anchor: .center)
            }

            let needleAngle = startAngle.degrees + Double(speedRatio) * sweepAngle
            let needleRad = needleAngle * .pi / 180

            let needleEnd = CGPoint(x: cos(needleRad) * (radius - 20), y: sin(needleRad) * (radius - 20))

            let needlePath = Path { p in
                p.move(to: .zero)
                p.addLine(to: needleEnd)
            }
            context.stroke(needlePath, with: .color(.white), lineWidth: 2)

            let pivotCircle = Path(ellipseIn: CGRect(x: -5, y: -5, width: 10, height: 10))
            context.fill(pivotCircle, with: .color(.white))

            let convertedSpeed = measurement.converted(to: displayUnit)
            let speedText = Text("\(convertedSpeed.value, format: format)")
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            context.draw(speedText, at: CGPoint(x: 0, y: 30), anchor: .center)

            let unitsText = Text("\(convertedSpeed.unit.symbol)")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
            context.draw(unitsText, at: CGPoint(x: 0, y: 45), anchor: .center)
        }
        .background(Color.black, in: Circle())
    }
}

#Preview {
    let speed = Measurement(value: 15, unit: UnitSpeed.metersPerSecond)
    SpeedometerDialView(
        measurement: .init(value: 5, unit: .metersPerSecond),
        maxMeasurement: .init(value: 50, unit: .milesPerHour),
        displayUnit: .milesPerHour,
        format: .number.precision(.fractionLength(0)),
        minorTick: .init(value: 2, unit: .milesPerHour),
        majorTick: .init(value: 10, unit: .milesPerHour),
        labels: [
            .init(value: 0, unit: .milesPerHour),
            .init(value: 10, unit: .milesPerHour),
            .init(value: 20, unit: .milesPerHour),
            .init(value: 30, unit: .milesPerHour),
            .init(value: 40, unit: .milesPerHour),
            .init(value: 50, unit: .milesPerHour)
        ]
    )
        .frame(width: 200, height: 200)
        .padding()
}

extension Path {
    static func circle(center: CGPoint, radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        ))
    }
}

func lerp(start: Double, end: Double, t: Double) -> Double {
    start + (end - start) * t
}

func lerp(start: Angle, end: Angle, t: Double) -> Angle {
    Angle(degrees: lerp(start: start.degrees, end: end.degrees, t: t))
}
