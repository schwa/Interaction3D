import DemoKit
import GeometryLite3D
import Interaction3D
import simd
import SwiftFormats
import SwiftUI

struct PitchYawDemoView: View {
    @State
    private var rotation = simd_quatf(angle: 0, axis: [0, 1, 0])

    @State
    private var distance: Float = 5.0

    @State
    private var target: SIMD3<Float> = .zero

    @State
    private var mode: InteractiveCameraModifier.Mode = .turntable()

    @State
    private var transforms: InteractionAxisTransforms = .default

    @State
    private var cubeScale: Float = 1.0

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                renderColoredCube(context: context, size: size, rotation: rotation, distance: distance, modelMatrix: float4x4(scale: [cubeScale, cubeScale, cubeScale]))
            }
            .background(Color.black)
        }
        .interactiveCamera(
            rotation: $rotation,
            distance: $distance,
            target: $target,
            mode: mode,
            transforms: transforms
        )
        .overlay(alignment: .topTrailing) {
            RotationWidget(rotation: $rotation)
                .frame(width: 120, height: 120)
                .padding()
                .background(Color.black, in: RoundedRectangle(cornerRadius: 8))
                .padding()
        }
        .overlay(alignment: .bottom) {
            InteractiveCameraDebugView(
                rotation: $rotation,
                distance: $distance,
                target: $target,
                mode: $mode,
                transforms: $transforms
            )
            .frame(width: 450)
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            .padding()
        }
        .overlay(alignment: .topLeading) {
            cubePanel
        }
    }

    private var cubePanel: some View {
        Form {
            LabeledContent("Cube Scale") {
                HStack {
                    Slider(value: Binding(
                        get: { Double(cubeScale) },
                        set: { cubeScale = Float($0) }
                    ), in: 0.1...5.0)
                    Text(Double(cubeScale), format: .number.precision(.fractionLength(2)))
                        .frame(width: 50, alignment: .trailing)
                }
            }
        }
        .frame(width: 300)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .padding()
    }
}

extension PitchYawDemoView: DemoView {
    static var metadata = DemoMetadata(
        name: "Interaction Controller",
        description: "Demo of the interaction controller with arcball, trackball, and first-person modes.",
        group: "Old"
    )
}
