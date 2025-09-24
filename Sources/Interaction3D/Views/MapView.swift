import simd
import SwiftUI

public struct MapView: View {
    public let transform: float4x4
    public let breadcrumbs: [SIMD2<Float>]
    public let scale: CGFloat

    public init(transform: float4x4, breadcrumbs: [SIMD2<Float>] = [], scale: CGFloat = 2.0) {
        self.transform = transform
        self.breadcrumbs = breadcrumbs
        self.scale = scale
    }

    public var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))
            let centerX = size.width / 2
            let centerY = size.height / 2
            var blueAxisPath = Path()
            blueAxisPath.move(to: CGPoint(x: centerX, y: 0))
            blueAxisPath.addLine(to: CGPoint(x: centerX, y: size.height))
            context.stroke(blueAxisPath, with: .color(.blue), lineWidth: 0.5)

            var redAxisPath = Path()
            redAxisPath.move(to: CGPoint(x: 0, y: centerY))
            redAxisPath.addLine(to: CGPoint(x: size.width, y: centerY))
            context.stroke(redAxisPath, with: .color(.red), lineWidth: 0.5)

            // Add axis labels
            let labelOffset: CGFloat = 15
            context.draw(Text("-Z").font(.system(size: 10, weight: .bold)).foregroundColor(.blue), at: CGPoint(x: centerX, y: labelOffset), anchor: .center)
            context.draw(Text("+Z").font(.system(size: 10, weight: .bold)).foregroundColor(.blue), at: CGPoint(x: centerX, y: size.height - labelOffset), anchor: .center)
            context.draw(Text("+X").font(.system(size: 10, weight: .bold)).foregroundColor(.red), at: CGPoint(x: size.width - labelOffset, y: centerY), anchor: .center)
            context.draw(Text("-X").font(.system(size: 10, weight: .bold)).foregroundColor(.red), at: CGPoint(x: labelOffset, y: centerY), anchor: .center)

            let position = transform.columns.3
            let markerX = centerX + CGFloat(position.x) * scale
            let markerY = centerY + CGFloat(position.z) * scale  // Removed negation since -Z is now north/top

            if !breadcrumbs.isEmpty {
                var breadcrumbPath = Path()
                for crumb in breadcrumbs {
                    let x = centerX + CGFloat(crumb.x) * scale
                    let y = centerY + CGFloat(crumb.y) * scale
                    let rect = CGRect(x: x - 1.5, y: y - 1.5, width: 3, height: 3)
                    breadcrumbPath.addEllipse(in: rect)
                }
                context.fill(breadcrumbPath, with: .color(.yellow.opacity(0.7)))
            }

            var trianglePath = Path()
            let triangleSize: CGFloat = 8
            trianglePath.move(to: CGPoint(x: 0, y: -triangleSize))
            trianglePath.addLine(to: CGPoint(x: -triangleSize * 0.6, y: triangleSize * 0.6))
            trianglePath.addLine(to: CGPoint(x: triangleSize * 0.6, y: triangleSize * 0.6))
            trianglePath.closeSubpath()

            // Transform the forward vector to get the direction we're facing
            let forward = SIMD4<Float>(0, 0, -1, 0)  // Local forward direction
            let worldForward = transform * forward  // Transform to world space

            // Calculate angle for the map (top-down view)
            // We want the arrow to point in the direction we're facing
            let angle = atan2(Double(worldForward.x), Double(-worldForward.z))

            context.drawLayer { layerContext in
                layerContext.translateBy(x: markerX, y: markerY)
                layerContext.rotate(by: Angle(radians: angle))
                layerContext.fill(trianglePath, with: .color(.green))
                layerContext.stroke(trianglePath, with: .color(.white), lineWidth: 1)
            }
        }
    }
}
