import SwiftUI

public struct CompassView: View {
    public enum LabelStyle {
        case cardinal
        case axis
    }

    public let heading: Angle
    public let labelStyle: LabelStyle
    public let majorTickStep: Angle
    public let minorTickStep: Angle

    public let labels: [Angle: String]

    public init(heading: Angle, labelStyle: LabelStyle = .cardinal, majorTickStep: Angle = .degrees(45), minorTickStep: Angle = .degrees(5)) {
        self.heading = heading
        self.labelStyle = labelStyle
        self.majorTickStep = majorTickStep
        self.minorTickStep = minorTickStep
        switch labelStyle {
        case .cardinal:
            self.labels = [
                .degrees(0): "N",
                .degrees(45): "NE",
                .degrees(90): "E",
                .degrees(135): "SE",
                .degrees(180): "S",
                .degrees(225): "SW",
                .degrees(270): "W",
                .degrees(315): "NW"

            ]
        case .axis:
            self.labels = [
                .degrees(0): "-Z",
                .degrees(90): "+X",
                .degrees(180): "+Z",
                .degrees(270): "-X"
            ]
        }
    }

    public var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2
            let palette: (major: Color, minor: Color, text: Color) = {
                switch labelStyle {
                case .cardinal:
                    return (.white, .white.opacity(0.6), .white)
                case .axis:
                    return (.white, .white.opacity(0.6), .white)
                }
            }()

            context.drawLayer { ctx in
                ctx.translateBy(x: center.x, y: center.y)

                for angle in stride(from: 0, through: 360, by: minorTickStep.degrees) {
                    let angle = Angle(degrees: angle)

                    guard angle.degrees.truncatingRemainder(dividingBy: majorTickStep.degrees) != 0 else {
                        continue
                    }

                    let outer = CGPoint(angle: angle - .degrees(90) - heading, radius: radius)
                    let inner = CGPoint(angle: angle - .degrees(90) - heading, radius: radius * 0.95)
                    let path = Path { p in
                        p.move(to: inner)
                        p.addLine(to: outer)
                    }
                    ctx.stroke(path, with: .color(palette.minor), lineWidth: 1)
                }

                for angle in stride(from: 0, through: 360, by: majorTickStep.degrees) {
                    let angle = Angle(degrees: angle)
                    let outer = CGPoint(angle: angle - .degrees(90) - heading, radius: radius)
                    let inner = CGPoint(angle: angle - .degrees(90) - heading, radius: radius * 0.9)
                    let path = Path { p in
                        p.move(to: inner)
                        p.addLine(to: outer)
                    }
                    ctx.stroke(path, with: .color(palette.major), lineWidth: 2)
                }

                for (angle, label) in labels {
                    let textRadius = radius - 30
                    let textPoint = CGPoint(angle: angle - .degrees(90) - heading, radius: textRadius)
                    ctx.drawLayer { textCtx in
                        textCtx.translateBy(x: textPoint.x, y: textPoint.y)
                        let textColor: Color = angle == .zero ? .red : palette.text
                        let text = Text(label).font(.system(size: 16, weight: .bold)).foregroundColor(textColor)
                        textCtx.draw(text, at: .zero, anchor: .center)
                    }
                }

                //                for i in 0..<360 {
                //                    let angle = Angle(degrees: Double(i))
                //                    let radians = angle.radians - .pi/2
                //
                //                    let majorDeg = Int(majorTickStep.degrees)
                //                    let minorDeg = Int(minorTickStep.degrees)
                //
                //                    if i % majorDeg == 0 {
                //                        let inner = radius - 15
                //                        let outer = radius - 5
                //                        let path = Path { p in
                //                            p.move(to: CGPoint(x: cos(radians) * inner, y: sin(radians) * inner))
                //                            p.addLine(to: CGPoint(x: cos(radians) * outer, y: sin(radians) * outer))
                //                        }
                //                        ctx.stroke(path, with: .color(.white), lineWidth: 2)
                //                    } else if i % minorDeg == 0 && (i % majorDeg != 0) {
                //                        let inner = radius - 10
                //                        let outer = radius - 5
                //                        let path = Path { p in
                //                            p.move(to: CGPoint(x: cos(radians) * inner, y: sin(radians) * inner))
                //                            p.addLine(to: CGPoint(x: cos(radians) * outer, y: sin(radians) * outer))
                //                        }
                //                        ctx.stroke(path, with: .color(.white.opacity(0.6)), lineWidth: 1)
                //                    } else if i % 5 == 0 {
                //                        let inner = radius - 7
                //                        let outer = radius - 5
                //                        let path = Path { p in
                //                            p.move(to: CGPoint(x: cos(radians) * inner, y: sin(radians) * inner))
                //                            p.addLine(to: CGPoint(x: cos(radians) * outer, y: sin(radians) * outer))
                //                        }
                //                        ctx.stroke(path, with: .color(.white.opacity(0.3)), lineWidth: 0.5)
                //                    }
                //
                //
                //                    if let label = labels[angle] {
                //                        let textRadius = radius - 30
                //                        let textPoint = CGPoint(x: cos(radians) * textRadius, y: sin(radians) * textRadius)
                //                        ctx.drawLayer { textCtx in
                //                            textCtx.translateBy(x: textPoint.x, y: textPoint.y)
                //                            textCtx.rotate(by: heading)
                //                            let text = Text(label).font(.system(size: 16, weight: .bold)).foregroundColor(angle == .zero ? .red : .white)
                //                            textCtx.draw(text, at: .zero, anchor: .center)
                //                        }
                //
                //                    }
                //                }

                let circle = Path(ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2))
                ctx.stroke(circle, with: .color(.white), lineWidth: 2)
            }

            let trianglePath = Path { p in
                p.move(to: CGPoint(x: center.x, y: center.y - radius + 2))
                p.addLine(to: CGPoint(x: center.x - 8, y: center.y - radius + 15))
                p.addLine(to: CGPoint(x: center.x + 8, y: center.y - radius + 15))
                p.closeSubpath()
            }
            context.fill(trianglePath, with: .color(.red))

            let centerDot = Path(ellipseIn: CGRect(x: center.x - 3, y: center.y - 3, width: 6, height: 6))
            context.fill(centerDot, with: .color(.white))

            let formattedHeading = heading.degrees.formatted(.number.precision(.fractionLength(0)))
            let headingText = Text("\(formattedHeading)°")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
            context.draw(headingText, at: CGPoint(x: center.x, y: center.y + 20), anchor: .center)
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(2)
        .background(.black, in: Circle())
    }
}

#Preview {
    VStack {
        HStack {
            CompassView(heading: Angle(degrees: 0))
                .frame(width: 200, height: 200)
            CompassView(heading: Angle(degrees: 30))
                .frame(width: 200, height: 200)
        }
        HStack {
            CompassView(heading: Angle(degrees: 45))
                .frame(width: 200, height: 200)
            CompassView(heading: Angle(degrees: 90))
                .frame(width: 200, height: 200)
        }
    }
}

extension CGPoint {
    init(angle: Angle, radius: CGFloat) {
        self.init(x: cos(angle.radians) * radius, y: sin(angle.radians) * radius)
    }
}
