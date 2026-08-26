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
    @State private var cameraDistance: Float = 5
    @State private var cameraTarget = SIMD3<Float>.zero
    @State private var cameraMode = InteractiveCameraModifier.Mode.turntable()
    @State private var cameraTransforms = InteractionAxisTransforms.default

    var body: some View {
        Form {
            Section("Presentation") {
                Picker("Form Style", selection: $formStyle) {
                    ForEach(WidgetsFormStyle.allCases) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                Picker("Color Scheme", selection: $colorScheme) {
                    ForEach(WidgetsColorScheme.allCases) { scheme in
                        Text(scheme.rawValue).tag(Optional(scheme))
                    }
                }
                .pickerStyle(.segmented)
            }
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

            Section("Camera Controls") {
                ScrubbableValueField("Value", value: $scrubbedValue, range: 0 ... 100)
                CameraPositionEditor(matrix: $matrix)
                CameraOrientationEditor(matrix: $matrix)
                AngleOfViewControl(verticalDegrees: $verticalFieldOfView, aspectRatio: 16 / 9)
                ClippingRangeControl(near: $nearClippingPlane, far: $farClippingPlane)
            }

            Section("Game Controller") {
                GameControllerSnapshotView()
            }

            Section("Interactive Camera Debug") {
                InteractiveCameraDebugView(
                    rotation: $rotation,
                    distance: $cameraDistance,
                    target: $cameraTarget,
                    mode: $cameraMode,
                    transforms: $cameraTransforms
                )
                .frame(minHeight: 500)
            }

            Section("Transformer Parameters") {
                TransformerParameterEditor(transformer: $transformer)
            }
        }
        .modifier(WidgetsFormStyleModifier(style: formStyle))
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
