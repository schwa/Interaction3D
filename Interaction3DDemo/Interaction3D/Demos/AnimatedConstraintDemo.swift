import DemoKit
import GeometryLite3D
import Interaction3D
import simd
import SwiftUI

enum AnimationMode {
    case once
    case loop
    case pingPong
}

struct AnimatedConstraintDemo: View {
    @State
    private var animator: AnyTransformerAnimator<OrbitTransformer, AngleF>

    @State
    private var position: SIMD3<Float> = [0, 0, 0]

    @State
    private var isAnimating = false

    @State
    private var animationMode: AnimationMode = .loop

    init() {
        let transformer = OrbitTransformer(center: [0, 0, 0], radius: 100, angle: .zero, normal: [0, 0, 1])
        _animator = State(initialValue: AnyTransformerAnimator(transformer: transformer, parameter: \.angle, from: AngleF.degrees(0), to: AngleF.degrees(360), duration: 3.0, timingTransformer: LoopTransformer(duration: 3.0)))
    }

    var body: some View {
        TimelineView(.animation) { context in
            VStack(spacing: 20) {
                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let centerPoint = CGPoint(x: center.x + CGFloat(animator.transformer.center.x), y: center.y + CGFloat(animator.transformer.center.y))
                    let currentPoint = CGPoint(x: center.x + CGFloat(position.x), y: center.y + CGFloat(position.y))

                    var centerPath = Path()
                    centerPath.addEllipse(in: CGRect(x: centerPoint.x - 5, y: centerPoint.y - 5, width: 10, height: 10))
                    context.fill(centerPath, with: .color(.green))

                    var orbitPath = Path()
                    orbitPath.addEllipse(in: CGRect(x: centerPoint.x - CGFloat(animator.transformer.radius), y: centerPoint.y - CGFloat(animator.transformer.radius), width: CGFloat(animator.transformer.radius) * 2, height: CGFloat(animator.transformer.radius) * 2))
                    context.stroke(orbitPath, with: .color(.gray), lineWidth: 1)

                    var currentPath = Path()
                    currentPath.addEllipse(in: CGRect(x: currentPoint.x - 8, y: currentPoint.y - 8, width: 16, height: 16))
                    context.fill(currentPath, with: .color(.blue))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                VStack(spacing: 16) {
                    HStack {
                        Button(isAnimating ? "Stop" : "Start") {
                            isAnimating.toggle()
                            if !isAnimating {
                                animator.reset()
                            }
                        }
                        .buttonStyle(.borderedProminent)

                        Picker("Mode", selection: $animationMode) {
                            Text("Once").tag(AnimationMode.once)
                            Text("Loop").tag(AnimationMode.loop)
                            Text("Ping Pong").tag(AnimationMode.pingPong)
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: animationMode) {
                            animator = switch animationMode {
                            case .once:
                                AnyTransformerAnimator(transformer: animator.transformer, parameter: animator.parameter, from: animator.fromValue, to: animator.toValue, duration: animator.duration, timingTransformer: OnceTransformer(duration: animator.duration))
                            case .loop:
                                AnyTransformerAnimator(transformer: animator.transformer, parameter: animator.parameter, from: animator.fromValue, to: animator.toValue, duration: animator.duration, timingTransformer: LoopTransformer(duration: animator.duration))
                            case .pingPong:
                                AnyTransformerAnimator(transformer: animator.transformer, parameter: animator.parameter, from: animator.fromValue, to: animator.toValue, duration: animator.duration, timingTransformer: PingPongTransformer(duration: animator.duration))
                            }
                        }
                    }

                }
                .padding()
            }
            .onChange(of: context.date) {
                if isAnimating {
                    animator.update(at: context.date.timeIntervalSinceReferenceDate)
                    position = animator.transformer.apply(to: position)
                }
            }
        }
    }
}

extension AnimatedConstraintDemo: DemoView {
    static var metadata = DemoMetadata(name: "Animated Constraint", systemImage: "arrow.triangle.2.circlepath", description: "Demonstrates constraint animation with different modes", group: "Interaction3D", keywords: ["constraint", "animation", "orbit"], color: .purple)
}
