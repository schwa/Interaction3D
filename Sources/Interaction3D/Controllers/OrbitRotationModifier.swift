import GeometryLite3D
import Interaction3D
import simd
import SwiftUI

public struct OrbitRotationModifier: ViewModifier {
    @Binding
    var cameraMatrix: simd_float4x4

    @State
    private var constraint = OrbitTransformer(center: [0, 0, 0], radius: 5, angle: .zero, normal: [0, 1, 0])

    @State
    private var isAnimating = false

    @State
    private var animationStartTime: TimeInterval?

    public init(cameraMatrix: Binding<simd_float4x4>) {
        self._cameraMatrix = cameraMatrix
    }

    public func body(content: Content) -> some View {
        TimelineView(.animation) { context in
            content
                .overlay(alignment: .bottomTrailing) {
                    Button(isAnimating ? "Stop" : "Start") {
                        isAnimating.toggle()
                        if isAnimating {
                            animationStartTime = context.date.timeIntervalSinceReferenceDate
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                }
                .onChange(of: constraint, initial: true) {
                    updateCamera()
                }
                .onChange(of: context.date) {
                    if isAnimating, let startTime = animationStartTime {
                        let elapsed = Float(context.date.timeIntervalSinceReferenceDate - startTime)
                        constraint.angle = .radians(elapsed)
                    }
                }
        }
    }

    func updateCamera() {
        let position = constraint.apply(to: .zero)
        let forward = normalize(constraint.center - position)
        let right = normalize(cross(forward, constraint.normal))
        let up = cross(right, forward)
        cameraMatrix = float4x4(
            [right.x, up.x, -forward.x, 0],
            [right.y, up.y, -forward.y, 0],
            [right.z, up.z, -forward.z, 0],
            [position.x, position.y, position.z, 1]
        )
    }
}
