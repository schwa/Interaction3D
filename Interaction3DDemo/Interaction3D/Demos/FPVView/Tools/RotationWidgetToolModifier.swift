import GeometryLite3D
import Interaction3D
import SceneKit
import simd
import SwiftUI

struct RotationWidgetToolModifier: ViewModifier {
    @Binding
    var cameraMatrix: simd_float4x4

    @State
    private var rotation: simd_quatf = .identity

    func body(content: Content) -> some View {
        content
            .onChange(of: rotation, initial: false) {
                let position = cameraMatrix.translation
                let rotationMatrix = rotation.matrix
                cameraMatrix = rotationMatrix * simd_float4x4(translation: position)
            }
            .overlay(alignment: .bottomTrailing) {
                RotationWidget(rotation: $rotation)
                    .frame(width: 120, height: 120)
                    .padding()
                    .background(Color.black, in: RoundedRectangle(cornerRadius: 8))
                    .padding()
            }
    }
}
