import SwiftUI
import Interaction3D
import DemoKit
import simd
import GeometryLite3D
import SwiftFormats

struct PitchYawDemoView: View {

    @State
    var rotation: simd_quatf = simd_quatf(angle: 0, axis: [0, 1, 0])

    @State
    var distance: Double = 10.0

    // Transform options
    @State
    var pitchScale: Double = 1.0

    @State
    var yawScale: Double = 1.0

    @State
    var distanceScale: Double = 1.0

    @State
    var pitchClamping: Bool = true

    @State
    var pitchClampRange: ClosedRange<Double> = -90...90

    init() {
    }

    @ViewBuilder
    func applyModifier<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        let contentView = content()

        let verticalTransform: (Angle) -> Angle = { angle in
            let scaled = angle.degrees * pitchScale
            if pitchClamping {
                return Angle(degrees: scaled.clamped(to: pitchClampRange))
            }
            return Angle(degrees: scaled)
        }

        let horizontalTransform: (Angle) -> Angle = { angle in
            Angle(degrees: angle.degrees * yawScale)
        }

        let distanceTransform: (Double) -> Double = { value in
            value * distanceScale
        }

        contentView
            .modifier(PitchYawDragViewModifier(
                rotation: $rotation,
                pitchTransform: verticalTransform,
                yawTransform: horizontalTransform
            ))
            .modifier(DistanceGestureModifier(
                distance: $distance,
                distanceTransform: distanceTransform
            ))
    }

    var body: some View {
        applyModifier {
        GeometryReader { geometry in
            Canvas { context, size in
                renderColoredCube(context: context, size: size, rotation: rotation, distance: Float(distance))
            }
            .background(Color.black)
        }
        .overlay(alignment: .topTrailing) {
            RotationWidget(rotation: $rotation)
                .frame(width: 120, height: 120)
                .padding()
                .background(Color.black, in: RoundedRectangle(cornerRadius: 8))
                .padding()
        }
        }
        .overlay(alignment: .bottom) {
            Form {
                LabeledContent("Distance") {
                    VStack {
                        Slider(value: $distance, in: 0.001 ... 50)
                        Text(distance, format: .number)
                    }
                }
                LabeledContent("Rotation") {
                    Text("[\(rotation.vector.x, format: .number.precision(.fractionLength(2))), \(rotation.vector.y, format: .number.precision(.fractionLength(2))), \(rotation.vector.z, format: .number.precision(.fractionLength(2))), \(rotation.vector.w, format: .number.precision(.fractionLength(2)))]")
                }

                Section("Transform Options") {
                    LabeledContent("Pitch Scale") {
                        HStack {
                            Slider(value: $pitchScale, in: -5.0...5.0)
                            Text(pitchScale, format: .number.precision(.fractionLength(2)))
                                .frame(width: 50, alignment: .trailing)
                        }
                    }

                    LabeledContent("Yaw Scale") {
                        HStack {
                            Slider(value: $yawScale, in: -5.0...5.0)
                            Text(yawScale, format: .number.precision(.fractionLength(2)))
                                .frame(width: 50, alignment: .trailing)
                        }
                    }

                    LabeledContent("Distance Scale") {
                        HStack {
                            Slider(value: $distanceScale, in: -20.0...20.0)
                            Text(distanceScale, format: .number.precision(.fractionLength(2)))
                                .frame(width: 50, alignment: .trailing)
                        }
                    }

                    Toggle("Clamp Pitch", isOn: $pitchClamping)

                    if pitchClamping {
                        LabeledContent("Clamp Range") {
                            VStack(spacing: 4) {
                                HStack {
                                    Text("Min:")
                                    Slider(value: Binding(
                                        get: { pitchClampRange.lowerBound },
                                        set: { newValue in
                                            pitchClampRange = min(newValue, pitchClampRange.upperBound)...pitchClampRange.upperBound
                                        }
                                    ), in: -180...180)
                                    Text(pitchClampRange.lowerBound, format: .number.precision(.fractionLength(0)))
                                        .frame(width: 40, alignment: .trailing)
                                }
                                HStack {
                                    Text("Max:")
                                    Slider(value: Binding(
                                        get: { pitchClampRange.upperBound },
                                        set: { newValue in
                                            pitchClampRange = pitchClampRange.lowerBound...max(newValue, pitchClampRange.lowerBound)
                                        }
                                    ), in: -180...180)
                                    Text(pitchClampRange.upperBound, format: .number.precision(.fractionLength(0)))
                                        .frame(width: 40, alignment: .trailing)
                                }
                            }
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

extension PitchYawDemoView: DemoView {
    static var metadata = DemoMetadata(
        name: "Pitch Yaw Demo"
    )

}

extension Angle {
    init(radians: Float) {
        self.init(radians: Double(radians))
    }
}
