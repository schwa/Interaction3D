import DemoKit
import Interaction3D
import simd
import SwiftUI

private enum WidgetsFormStyle: String, CaseIterable, Identifiable {
    case grouped = "Grouped"
    #if os(macOS)
    case columns = "Columns"
    #endif

    var id: Self { self }
}

private enum WidgetsColorScheme: String, CaseIterable, Identifiable {
    case light = "Light"
    case dark = "Dark"

    var id: Self { self }

    var colorScheme: ColorScheme {
        switch self {
        case .light: .light
        case .dark: .dark
        }
    }

    init(_ colorScheme: ColorScheme) {
        self = colorScheme == .dark ? .dark : .light
    }
}

private struct WidgetsFormStyleModifier: ViewModifier {
    let style: WidgetsFormStyle

    @ViewBuilder
    func body(content: Content) -> some View {
        switch style {
        case .grouped:
            content.formStyle(.grouped)
        #if os(macOS)
        case .columns:
            ScrollView {
                content.formStyle(.columns)
            }
        #endif
        }
    }
}

struct WidgetsDemo: View {
    @Environment(\.colorScheme) private var systemColorScheme

    @State private var rotation = simd_quatf(angle: 0, axis: [0, 1, 0])
    @State private var matrix: float4x4 = .init(diagonal: [1, 1, 1, 1])
    @State private var vector: SIMD3<Float> = [1, 2, 3]
    @State private var formStyle = WidgetsFormStyle.grouped
    @State private var colorScheme: WidgetsColorScheme?
    @State private var verticalFieldOfView = 60.0
    @State private var nearClippingPlane = 0.1
    @State private var farClippingPlane = 1_000.0
    @State private var scrubbedValue = 12.0
    @State private var transformer = LerpPositionTransformer(start: .zero, end: [10, 10, 10], t: 0.5)

    var body: some View {
        Form {
            Section("Rotation Widget") {
                RotationWidget(rotation: $rotation)
                    .frame(width: 200, height: 200)
            }

            Section("Matrix View") {
                MatrixView(value: matrix, style: .number.precision(.fractionLength(2)), colorize: true)
                    .monospaced()
            }

            Section("Matrix Editor") {
                MatrixEditor(value: $matrix, style: .number.precision(.fractionLength(2)))
                    .monospaced()
                    .frame(maxWidth: 400)
            }

            Section("Vector Editor") {
                VectorEditor(value: $vector, style: .number.precision(.fractionLength(2)), semantic: .point)
                    .frame(maxWidth: 400)
            }

            Section("Scrubbable Value Field") {
                ScrubbableValueField("Value", value: $scrubbedValue, range: 0 ... 100)
            }

            Section("Camera Position Editor") {
                CameraPositionEditor(matrix: $matrix)
            }

            Section("Camera Orientation Editor") {
                CameraOrientationEditor(matrix: $matrix)
            }

            Section("Angle of View Control") {
                AngleOfViewControl(verticalDegrees: $verticalFieldOfView, aspectRatio: 16 / 9)
            }

            Section("Clipping Range Control") {
                ClippingRangeControl(near: $nearClippingPlane, far: $farClippingPlane)
            }

            Section("Compass") {
                CompassView(heading: .degrees(45))
                    .frame(height: 100)
            }

            Section("Artificial Horizon") {
                ArtificialHorizonView(transform: matrix)
                    .frame(width: 240, height: 160)
            }

            Section("Horizon Cue") {
                HorizonCue(pitch: 0.2, verticalFOV: verticalFieldOfView)
                    .frame(width: 300, height: 160)
                    .background(.black)
            }

            Section("Map") {
                MapView(transform: matrix, breadcrumbs: [[-20, -10], [-10, 5], [0, 0], [15, 20]])
                    .frame(width: 300, height: 240)
            }

            Section("Speedometer") {
                SpeedometerView(linearVelocity: [0.25, -0.1, 0.75], angularVelocity: [0.1, 0.2, -0.1])
                    .frame(width: 320, height: 160)
            }

            Section("Measurement Dial") {
                SpeedometerDialView(
                    measurement: Measurement(value: 80, unit: UnitSpeed.kilometersPerHour),
                    maxMeasurement: Measurement(value: 200, unit: UnitSpeed.kilometersPerHour),
                    displayUnit: .kilometersPerHour,
                    minorTick: Measurement(value: 10, unit: UnitSpeed.kilometersPerHour),
                    majorTick: Measurement(value: 20, unit: UnitSpeed.kilometersPerHour),
                    labels: stride(from: 0.0, through: 200.0, by: 20).map { Measurement(value: $0, unit: UnitSpeed.kilometersPerHour) }
                )
                .frame(width: 240, height: 240)
            }

            Section("Game Controller") {
                GameControllerSnapshotView()
            }

            Section("Transformer Parameters") {
                TransformerParameterEditor(transformer: $transformer)
            }
        }
        .modifier(WidgetsFormStyleModifier(style: formStyle))
        .toolbar {
            ToolbarItemGroup {
                Picker("Form Style", selection: $formStyle) {
                    ForEach(WidgetsFormStyle.allCases) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                .pickerStyle(.menu)

                Picker("Color Scheme", selection: $colorScheme) {
                    ForEach(WidgetsColorScheme.allCases) { scheme in
                        Text(scheme.rawValue).tag(Optional(scheme))
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .preferredColorScheme(colorScheme?.colorScheme)
        .onAppear {
            colorScheme = colorScheme ?? WidgetsColorScheme(systemColorScheme)
        }
    }
}

extension WidgetsDemo: DemoView {
    static var metadata = DemoMetadata(
        name: "Widgets",
        description: "Interactive catalog of Interaction3D controls and instruments.",
        group: "Interaction"
    )
}
