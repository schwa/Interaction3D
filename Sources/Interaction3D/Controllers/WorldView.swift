import GeometryLite3D
import Interaction3D
import simd
import SwiftUI

public struct WorldView<Content: View>: View {
    @Binding
    var projection: any ProjectionProtocol

    @Binding
    private var cameraMatrix: simd_float4x4

    var content: Content

    public init(projection: Binding<any ProjectionProtocol>, cameraMatrix: Binding<simd_float4x4>, @ViewBuilder content: @escaping () -> Content) {
        self._projection = projection
        self._cameraMatrix = cameraMatrix
        self.content = content()
    }

    public var body: some View {
        ToolPickerHost {
            content
                .tool("Turntable", id: "turntable", modifier: TurnableCameraModifier(cameraMatrix: $cameraMatrix))
        }
    }
}
