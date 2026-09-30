import GeometryLite3D
import SwiftUI

public struct TransformerParameterEditor<Transformer>: View where Transformer: ParameterizedTransformer {
    @Binding
    var transformer: Transformer

    public init(transformer: Binding<Transformer>) {
        self._transformer = transformer
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Transformer.parameters.enumerated(), id: \.element.name) { _, parameter in
                ParameterControl(transformer: $transformer, parameter: parameter)
            }
        }
    }
}

struct ParameterControl<Transformer>: View where Transformer: ParameterizedTransformer {
    @Binding
    var transformer: Transformer
    let parameter: AnyTransformerParameter<Transformer>

    var body: some View {
        LabeledContent(parameter.name) {
            if let metadata = parameter.metadata {
                ParameterMetadataEditorView(transformer: $transformer, parameter: parameter, metadata: metadata)
            } else {
                Text("No metadata")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct ParameterMetadataEditorView<Transformer>: View where Transformer: ParameterizedTransformer {
    @Binding
    var transformer: Transformer
    let parameter: AnyTransformerParameter<Transformer>
    let metadata: ParameterMetadata

    var body: some View {
        switch metadata {
        case .floatingPoint(let range, _):
            let value = parameter.getValue(transformer)
            if value is Float {
                FloatSlider(value: $transformer[parameter: parameter] as Binding<Float>, range: range ?? 0...1)
            } else if value is Double {
                FloatSlider(value: $transformer[parameter: parameter] as Binding<Double>, range: range ?? 0...1)
            }

        case .vector:
            let value = parameter.getValue(transformer)
            if value is SIMD3<Float> {
                VectorEditor(value: $transformer[parameter: parameter] as Binding<SIMD3<Float>>, style: .number, semantic: .point)
            }

        case .angle:
            let value = parameter.getValue(transformer)
            if value is AngleF {
                AngleSlider(value: $transformer[parameter: parameter] as Binding<AngleF>)
            }
        }
    }
}

#Preview {
    @Previewable @State
    var transformer = OrbitTransformer(center: .zero, radius: 10, angle: .degrees(45))

    TransformerParameterEditor(transformer: $transformer)
        .padding()
}
