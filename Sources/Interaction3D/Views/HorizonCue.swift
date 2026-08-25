import SwiftUI

public struct HorizonCue: View {
    public var pitch: Float
    public var verticalFOV: CGFloat

    public init(pitch: Float, verticalFOV: CGFloat) {
        self.pitch = pitch
        self.verticalFOV = verticalFOV
    }

    public var body: some View {
        Canvas { context, size in
            let fovRadians = max(0.1, min(.pi - 0.1, Double(verticalFOV) * .pi / 180))
            let ratio = tan(Double(pitch)) / tan(fovRadians / 2)
            let clamped = max(-1, min(1, ratio))
            let y = size.height / 2 + CGFloat(clamped) * (size.height / 2)
            let centerX = size.width / 2

            let bracketHeight: CGFloat = 48
            let bracketGap: CGFloat = 80
            let horizontalExtension: CGFloat = 20

            let innerLeftX = centerX - bracketGap
            let outerLeftX = innerLeftX - horizontalExtension
            let innerRightX = centerX + bracketGap
            let outerRightX = innerRightX + horizontalExtension

            var left = Path()
            left.move(to: CGPoint(x: innerLeftX, y: y - bracketHeight / 2))
            left.addLine(to: CGPoint(x: outerLeftX, y: y - bracketHeight / 2))
            left.addLine(to: CGPoint(x: outerLeftX, y: y + bracketHeight / 2))
            left.addLine(to: CGPoint(x: innerLeftX, y: y + bracketHeight / 2))

            var right = Path()
            right.move(to: CGPoint(x: innerRightX, y: y - bracketHeight / 2))
            right.addLine(to: CGPoint(x: outerRightX, y: y - bracketHeight / 2))
            right.addLine(to: CGPoint(x: outerRightX, y: y + bracketHeight / 2))
            right.addLine(to: CGPoint(x: innerRightX, y: y + bracketHeight / 2))

            context.stroke(left, with: .color(.white), lineWidth: 2)
            context.stroke(right, with: .color(.white), lineWidth: 2)
        }
    }
}

#Preview {
    HorizonCue(pitch: 0.2, verticalFOV: 60)
        .frame(width: 300, height: 300)
        .background(Color.black)
}
