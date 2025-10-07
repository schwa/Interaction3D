import GeometryLite3D
import Interaction3D
import simd
import SwiftUI

public struct OrbitToolModifier: ViewModifier {
    @Binding
    var cameraMatrix: simd_float4x4

    @State
    private var rotation: simd_quatf = .identity

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
                    VStack(spacing: 12) {
                        Button(isAnimating ? "Stop" : "Start") {
                            isAnimating.toggle()
                            if isAnimating {
                                animationStartTime = context.date.timeIntervalSinceReferenceDate
                            }
                        }
                        .buttonStyle(.borderedProminent)

                        RotationWidget(rotation: $rotation)
                            .frame(width: 120, height: 120)
                            .background(Color.black, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .padding()
                }
                .onChange(of: rotation, initial: false) {
                    updateCamera()
                }
                .onChange(of: context.date) {
                    if isAnimating, let startTime = animationStartTime {
                        let elapsed = Float(context.date.timeIntervalSinceReferenceDate - startTime)
                        rotation = simd_quatf(angle: elapsed, axis: [0, 1, 0])
                    }
                }
        }
    }

    func updateCamera() {
        let position = cameraMatrix.translation
        let rotationMatrix = rotation.matrix
        cameraMatrix = rotationMatrix * simd_float4x4(translation: position)
    }
}
