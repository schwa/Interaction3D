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
        VStack(alignment: .leading, spacing: 4) {
            Text(parameter.name)
                .font(.headline)

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
            if let floatValue = value as? Float {
                FloatSlider(value: Binding(get: { Double(floatValue) }, set: { parameter.setValue(&transformer, Float($0)) }), range: range ?? 0...1)
            } else if let doubleValue = value as? Double {
                FloatSlider(value: Binding(get: { doubleValue }, set: { parameter.setValue(&transformer, $0) }), range: range ?? 0...1)
            }

        case .vector:
            let value = parameter.getValue(transformer)
            if let simd3Value = value as? SIMD3<Float> {
                VectorEditor(value: Binding(get: { simd3Value }, set: { parameter.setValue(&transformer, $0) }), style: .number, semantic: .point)
            }

        case .angle:
            let value = parameter.getValue(transformer)
            if let angleValue = value as? AngleF {
                AngleSlider(value: Binding(get: { angleValue }, set: { parameter.setValue(&transformer, $0) }))
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
