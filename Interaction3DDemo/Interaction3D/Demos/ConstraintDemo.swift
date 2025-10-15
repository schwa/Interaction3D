import DemoKit
import GeometryLite3D
import Interaction3D
import simd
import SwiftUI

enum ConstraintType: String, CaseIterable, Identifiable {
    case lerp = "Lerp"
    case orbit = "Orbit"

    var id: String { rawValue }
}

struct ConstraintDemo: View {
    @State
    private var constraintType: ConstraintType = .lerp

    @State
    private var position: SIMD3<Float> = [0, 0, 0]

    var body: some View {
        VStack(spacing: 20) {
            Picker("Constraint Type", selection: $constraintType) {
                ForEach(ConstraintType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            switch constraintType {
            case .lerp:
                LerpConstraintView(position: $position)
            case .orbit:
                OrbitTransformerView(position: $position)
            }
        }
    }
}

struct LerpConstraintView: View {
    @Binding
    var position: SIMD3<Float>

    @State
    private var constraint = LerpPositionTransformer(start: [0, 0, 0], end: [100, 100, 0], t: 0)

    var body: some View {
        VStack(spacing: 20) {
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let startPoint = CGPoint(x: center.x + CGFloat(constraint.start.x), y: center.y + CGFloat(constraint.start.y))
                let endPoint = CGPoint(x: center.x + CGFloat(constraint.end.x), y: center.y + CGFloat(constraint.end.y))
                let currentPoint = CGPoint(x: center.x + CGFloat(position.x), y: center.y + CGFloat(position.y))

                var startPath = Path()
                startPath.addEllipse(in: CGRect(x: startPoint.x - 5, y: startPoint.y - 5, width: 10, height: 10))
                context.fill(startPath, with: .color(.green))

                var endPath = Path()
                endPath.addEllipse(in: CGRect(x: endPoint.x - 5, y: endPoint.y - 5, width: 10, height: 10))
                context.fill(endPath, with: .color(.red))

                var linePath = Path()
                linePath.move(to: startPoint)
                linePath.addLine(to: endPoint)
                context.stroke(linePath, with: .color(.gray), lineWidth: 1)

                var currentPath = Path()
                currentPath.addEllipse(in: CGRect(x: currentPoint.x - 8, y: currentPoint.y - 8, width: 16, height: 16))
                context.fill(currentPath, with: .color(.blue))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 16) {
                TransformerParameterEditor(transformer: $constraint)
                    .onChange(of: constraint) {
                        position = constraint.apply(to: position)
                    }

                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                    GridRow {
                        Text("Start:")
                        Text("[\(constraint.start.x, format: .number), \(constraint.start.y, format: .number), \(constraint.start.z, format: .number)]")
                            .foregroundStyle(.green)
                    }
                    GridRow {
                        Text("End:")
                        Text("[\(constraint.end.x, format: .number), \(constraint.end.y, format: .number), \(constraint.end.z, format: .number)]")
                            .foregroundStyle(.red)
                    }
                    GridRow {
                        Text("Current:")
                        Text("[\(position.x, format: .number), \(position.y, format: .number), \(position.z, format: .number)]")
                            .foregroundStyle(.blue)
                    }
                }
                .font(.system(.body, design: .monospaced))
            }
            .padding()
        }
        .onAppear {
            position = constraint.apply(to: position)
        }
    }
}

struct OrbitTransformerView: View {
    @Binding
    var position: SIMD3<Float>

    @State
    private var constraint = OrbitTransformer(center: [0, 0, 0], radius: 100, angle: .zero)

    var body: some View {
        VStack(spacing: 20) {
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let centerPoint = CGPoint(x: center.x + CGFloat(constraint.center.x), y: center.y + CGFloat(constraint.center.y))
                let currentPoint = CGPoint(x: center.x + CGFloat(position.x), y: center.y + CGFloat(position.y))

                var centerPath = Path()
                centerPath.addEllipse(in: CGRect(x: centerPoint.x - 5, y: centerPoint.y - 5, width: 10, height: 10))
                context.fill(centerPath, with: .color(.green))

                var orbitPath = Path()
                orbitPath.addEllipse(in: CGRect(x: centerPoint.x - CGFloat(constraint.radius), y: centerPoint.y - CGFloat(constraint.radius), width: CGFloat(constraint.radius) * 2, height: CGFloat(constraint.radius) * 2))
                context.stroke(orbitPath, with: .color(.gray), lineWidth: 1)

                var currentPath = Path()
                currentPath.addEllipse(in: CGRect(x: currentPoint.x - 8, y: currentPoint.y - 8, width: 16, height: 16))
                context.fill(currentPath, with: .color(.blue))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 16) {
                TransformerParameterEditor(transformer: $constraint)
                    .onChange(of: constraint) {
                        position = constraint.apply(to: position)
                    }

                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                    GridRow {
                        Text("Center:")
                        Text("[\(constraint.center.x, format: .number), \(constraint.center.y, format: .number), \(constraint.center.z, format: .number)]")
                            .foregroundStyle(.green)
                    }
                    GridRow {
                        Text("Current:")
                        Text("[\(position.x, format: .number), \(position.y, format: .number), \(position.z, format: .number)]")
                            .foregroundStyle(.blue)
                    }
                }
                .font(.system(.body, design: .monospaced))
            }
            .padding()
        }
        .onAppear {
            position = constraint.apply(to: position)
        }
    }
}

extension ConstraintDemo: DemoView {
    static var metadata = DemoMetadata(name: "Constraints", systemImage: "point.3.connected.trianglepath.dotted", description: "Interactive demonstration of position constraints", group: "Interaction3D", keywords: ["constraint", "lerp", "orbit", "interpolation"], color: .blue)
}
