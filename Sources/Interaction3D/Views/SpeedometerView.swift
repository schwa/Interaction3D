import SwiftUI

public struct SpeedometerView: View {
    @Environment(MovementController.self) var controller

    public init() {
        // This line intentionally left blank
    }

    public var body: some View {
        Canvas { context, size in
            let padding: CGFloat = 10
            let lineHeight: CGFloat = 20
            let barHeight: CGFloat = 6
            let maxBarWidth = size.width - padding * 2 - 80

            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))

            let velocities: [(String, Float, Color)] = [
                ("Lateral", controller.linearVelocity.x, .blue),
                ("Vertical", controller.linearVelocity.y, .orange),
                ("Forward", controller.linearVelocity.z, .green),
                ("Pitch", controller.angularVelocity.x, .yellow),
                ("Yaw", controller.angularVelocity.y, .cyan),
                ("Roll", controller.angularVelocity.z, .purple)
            ]

            for (index, (label, value, color)) in velocities.enumerated() {
                let y = padding + CGFloat(index) * (lineHeight + 5)

                let labelText = Text(label).font(.system(size: 12, weight: .medium)).foregroundColor(.white)
                context.draw(labelText, at: CGPoint(x: padding + 35, y: y), anchor: .leading)

                let centerX = size.width / 2
                let barWidth = abs(CGFloat(value)) * maxBarWidth / 10.0

                if value != 0 {
                    let barRect: CGRect
                    if value > 0 {
                        barRect = CGRect(x: centerX, y: y - barHeight / 2, width: barWidth, height: barHeight)
                    } else {
                        barRect = CGRect(x: centerX - barWidth, y: y - barHeight / 2, width: barWidth, height: barHeight)
                    }
                    context.fill(Path(barRect), with: .color(color.opacity(0.7)))
                }

                let centerLine = Path { p in
                    p.move(to: CGPoint(x: centerX, y: y - barHeight))
                    p.addLine(to: CGPoint(x: centerX, y: y + barHeight))
                }
                context.stroke(centerLine, with: .color(.white.opacity(0.3)), lineWidth: 1)

                let valueText = Text(String(format: "%.2f", value)).font(.system(size: 10, weight: .regular, design: .monospaced)).foregroundColor(.white.opacity(0.8))
                context.draw(valueText, at: CGPoint(x: size.width - padding - 20, y: y), anchor: .trailing)
            }

            let centerLine = Path { p in
                p.move(to: CGPoint(x: size.width / 2, y: 0))
                p.addLine(to: CGPoint(x: size.width / 2, y: size.height))
            }
            context.stroke(centerLine, with: .color(.white.opacity(0.2)), lineWidth: 1)
        }
        .frame(height: 160)
    }
}

#Preview {
    struct PreviewContainer: View {
        @State private var controller = MovementController()

        var body: some View {
            SpeedometerView()
                .environment(controller)
                .frame(width: 300)
                .onAppear {
                    controller.linearVelocity.z = 5
                    controller.angularVelocity.y = 2
                }
        }
    }

    return PreviewContainer()
}
