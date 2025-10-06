import Interaction3D
import SceneKit
import simd
import SwiftUI

struct TurnableModifier: ViewModifier {
    @Binding
    var cameraMatrix: simd_float4x4

    @State private var constraint = TurntableControllerConstraint(target: .zero, radius: 10)
    @State private var showsConstraintEditor = false

    func body(content: Content) -> some View {
        content
            .modifier(
                TurntableCameraController(constraint: $constraint, transform: $cameraMatrix)
            )
            .inspector(isPresented: .constant(true)) {
                Form {
                    TurntableConstraintEditor(value: $constraint)
                }
            }
    }
}
