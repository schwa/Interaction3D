import DemoKit
import Interaction3D
import SwiftFormats
import SwiftUI

struct DragDemo: View {

    @State
    private var dragState: DragGestureModifier.DragState = .zero

    @State
    private var translation: CGSize = .zero

    @State
    private var breadcrumbs: [CGPoint] = []

    @State
    private var isDragging: Bool = false

    @State
    private var viewSize: CGSize = .zero

    // Transform options
    @State
    private var horizontalScale: Double = 0.2

    @State
    private var verticalScale: Double = 0.2

    init() {
        // No configuration needed
    }

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)

            // Draw center crosshair
            var crosshairPath = Path()
            crosshairPath.move(to: CGPoint(x: center.x - 20, y: center.y))
            crosshairPath.addLine(to: CGPoint(x: center.x + 20, y: center.y))
            crosshairPath.move(to: CGPoint(x: center.x, y: center.y - 20))
            crosshairPath.addLine(to: CGPoint(x: center.x, y: center.y + 20))
            context.stroke(crosshairPath, with: .color(.gray), lineWidth: 1)

            // Draw breadcrumbs
            for breadcrumb in breadcrumbs {
                let crumbRect = CGRect(
                    x: breadcrumb.x - 2,
                    y: breadcrumb.y - 2,
                    width: 4,
                    height: 4
                )
                context.fill(Path(ellipseIn: crumbRect), with: .color(.white.opacity(0.3)))
            }

            // Draw translation line
            let endPoint = CGPoint(
                x: center.x + translation.width,
                y: center.y + translation.height
            )

            var linePath = Path()
            linePath.move(to: center)
            linePath.addLine(to: endPoint)
            context.stroke(linePath, with: .color(.blue), lineWidth: 1)

            // Draw circle at end point
            let circleRect = CGRect(
                x: endPoint.x - 5,
                y: endPoint.y - 5,
                width: 10,
                height: 10
            )
            context.fill(Path(ellipseIn: circleRect), with: .color(.blue))

            // Draw start location (green)
            if dragState.startLocation != .zero {
                let startRect = CGRect(
                    x: dragState.startLocation.x - 8,
                    y: dragState.startLocation.y - 8,
                    width: 16,
                    height: 16
                )
                context.stroke(Path(ellipseIn: startRect), with: .color(.green), lineWidth: 2)
            }

            // Draw current location (orange)
            if dragState.currentLocation != .zero {
                let currentRect = CGRect(
                    x: dragState.currentLocation.x - 6,
                    y: dragState.currentLocation.y - 6,
                    width: 12,
                    height: 12
                )
                context.fill(Path(ellipseIn: currentRect), with: .color(.orange))
            }

            // Draw axes indicators
            context.draw(Text("X: \(translation.width, format: .number.precision(.fractionLength(1)))").font(.caption), at: CGPoint(x: 60, y: 20))
            context.draw(Text("Y: \(translation.height, format: .number.precision(.fractionLength(1)))").font(.caption), at: CGPoint(x: 60, y: 40))
        }
        .background(Color.black)
        .onGeometryChange(for: CGSize.self, of: \.size) { viewSize = $0 }
        .modifier(DragGestureModifier(
            state: $dragState
        ))
        .onChange(of: dragState.translation) { oldValue, newValue in
            // Apply scaling transforms
            translation = CGSize(
                width: newValue.width * horizontalScale,
                height: newValue.height * verticalScale
            )
        }
        .onChange(of: translation) { oldValue, newValue in
            // Detect start of new drag
            if oldValue == .zero, newValue != .zero {
                // Clear breadcrumbs when new drag starts
                breadcrumbs.removeAll()
                isDragging = true
            } else if newValue == .zero {
                isDragging = false
            }

            // Add breadcrumb during drag
            if newValue != .zero {
                let center = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
                let point = CGPoint(
                    x: center.x + newValue.width,
                    y: center.y + newValue.height
                )
                breadcrumbs.append(point)
                // Limit breadcrumbs to last 1000 points
                if breadcrumbs.count > 1_000 {
                    breadcrumbs.removeFirst()
                }
            }
        }
        .onChange(of: horizontalScale) { oldValue, newValue in
            // Reapply transform when scale changes
            translation = CGSize(
                width: dragState.translation.width * newValue,
                height: dragState.translation.height * verticalScale
            )
        }
        .onChange(of: verticalScale) { oldValue, newValue in
            // Reapply transform when scale changes
            translation = CGSize(
                width: dragState.translation.width * horizontalScale,
                height: dragState.translation.height * newValue
            )
        }
        .overlay(alignment: .bottom) {
            Form {
                Section("Legend") {
                    HStack {
                        Circle().stroke(.green, lineWidth: 2).frame(width: 12, height: 12)
                        Text("Start Location")
                    }
                    HStack {
                        Circle().fill(.orange).frame(width: 12, height: 12)
                        Text("Current Location")
                    }
                    HStack {
                        Circle().fill(.blue).frame(width: 12, height: 12)
                        Text("Scaled Translation")
                    }
                    HStack {
                        Circle().fill(.white.opacity(0.3)).frame(width: 8, height: 8)
                        Text("Breadcrumbs")
                    }
                }

                LabeledContent("Translation") {
                    Text("[\(translation.width, format: .number.precision(.fractionLength(1))), \(translation.height, format: .number.precision(.fractionLength(1)))]")
                }

                Section("Transform Options") {
                    LabeledContent("Horizontal Scale") {
                        HStack {
                            Slider(value: $horizontalScale, in: -1.0...1.0)
                            Text(horizontalScale, format: .number.precision(.fractionLength(2)))
                                .frame(width: 50, alignment: .trailing)
                        }
                    }

                    LabeledContent("Vertical Scale") {
                        HStack {
                            Slider(value: $verticalScale, in: -1.0...1.0)
                            Text(verticalScale, format: .number.precision(.fractionLength(2)))
                                .frame(width: 50, alignment: .trailing)
                        }
                    }
                }
            }
            .frame(width: 450)
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            .padding()
        }
    }
}

extension DragDemo: DemoView {
    static var metadata = DemoMetadata(
        name: "Drag Gesture",
        description: "Low-level drag gesture debugging with visual feedback.",
        group: "Old"
    )
}
