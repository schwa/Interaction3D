import simd
import SwiftUI

public struct ArtificialHorizonView: View {
    public let transform: float4x4

    public init(transform: float4x4) {
        self.transform = transform
    }

    private var roll: Angle {
        let m = transform
        let roll = atan2(m[0][1], m[1][1])
        return Angle(radians: Double(roll))
    }

    private var pitch: Angle {
        let m = transform
        let pitch = atan2(-m[2][1], sqrt(m[0][1] * m[0][1] + m[1][1] * m[1][1]))
        return Angle(radians: Double(pitch))
    }

    public var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2

            let circlePath = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))

            context.drawLayer { ctx in
                ctx.clip(to: circlePath)
                ctx.translateBy(x: center.x, y: center.y)
                ctx.rotate(by: roll)

                let pixelsPerDegree = radius / 45
                let pitchOffset = CGFloat(pitch.degrees) * pixelsPerDegree

                let skyRect = CGRect(x: -radius * 2, y: -radius * 4 - pitchOffset, width: radius * 4, height: radius * 4)
                ctx.fill(Path(skyRect), with: .color(.blue.opacity(0.6)))

                let groundRect = CGRect(x: -radius * 2, y: -pitchOffset, width: radius * 4, height: radius * 4)
                ctx.fill(Path(groundRect), with: .color(.brown.opacity(0.6)))

                ctx.stroke(Path(CGRect(x: -radius * 2, y: -pitchOffset - 0.5, width: radius * 4, height: 1)), with: .color(.white), lineWidth: 2)

                for i in stride(from: -90, through: 90, by: 10) {
                    guard i != 0 else { continue }
                    let y = CGFloat(i) * pixelsPerDegree - pitchOffset

                    if abs(y) < radius {
                        let lineLength: CGFloat = i.isMultiple(of: 30) ? radius * 0.4 : radius * 0.2
                        let path = Path { p in
                            p.move(to: CGPoint(x: -lineLength / 2, y: y))
                            p.addLine(to: CGPoint(x: lineLength / 2, y: y))
                        }
                        ctx.stroke(path, with: .color(.white.opacity(0.8)), lineWidth: i.isMultiple(of: 30) ? 2 : 1)

                        if i.isMultiple(of: 30) {
                            let text = Text("\(abs(i))°").font(.system(size: 10, weight: .medium)).foregroundColor(.white)
                            ctx.draw(text, at: CGPoint(x: lineLength / 2 + 15, y: y))
                            ctx.draw(text, at: CGPoint(x: -lineLength / 2 - 15, y: y))
                        }
                    }
                }
            }

            let aircraftPath = Path { p in
                p.move(to: CGPoint(x: center.x - radius * 0.3, y: center.y))
                p.addLine(to: CGPoint(x: center.x - radius * 0.15, y: center.y))
                p.move(to: CGPoint(x: center.x - radius * 0.15, y: center.y))
                p.addLine(to: CGPoint(x: center.x - radius * 0.15, y: center.y + 10))

                p.move(to: CGPoint(x: center.x + radius * 0.15, y: center.y))
                p.addLine(to: CGPoint(x: center.x + radius * 0.3, y: center.y))
                p.move(to: CGPoint(x: center.x + radius * 0.15, y: center.y))
                p.addLine(to: CGPoint(x: center.x + radius * 0.15, y: center.y + 10))
            }
            context.stroke(aircraftPath, with: .color(.yellow), lineWidth: 3)

            context.fill(Path(ellipseIn: CGRect(x: center.x - 3, y: center.y - 3, width: 6, height: 6)), with: .color(.yellow))

            context.stroke(circlePath, with: .color(.white.opacity(0.5)), lineWidth: 2)

            for angle in stride(from: 0, through: 360, by: 30) {
                let radians = Angle(degrees: Double(angle)).radians
                let inner = radius - 10
                let outer = radius - 5
                let path = Path { p in
                    p.move(to: CGPoint(x: center.x + cos(radians) * inner, y: center.y + sin(radians) * inner))
                    p.addLine(to: CGPoint(x: center.x + cos(radians) * outer, y: center.y + sin(radians) * outer))
                }
                context.stroke(path, with: .color(.white.opacity(0.7)), lineWidth: angle.isMultiple(of: 90) ? 2 : 1)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

#Preview {
    ArtificialHorizonView(transform: float4x4(1))
        .frame(width: 300, height: 300)
        .background(Color.black)
}
