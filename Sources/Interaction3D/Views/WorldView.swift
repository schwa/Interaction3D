import GeometryLite3D
import Interaction3D
import simd
import SwiftUI


public struct WorldView<Content: View>: View {
    public enum Tool: String, CaseIterable, Sendable {
        case turntable
        case orbit
        case rotationWidget
        case fpvFlight

        public static var `default`: [Tool] {
            //[.turntable, .orbit, .rotationWidget, .fpvFlight]
            [.turntable]
        }
    }

    @Binding
    var projection: any ProjectionProtocol

    @Binding
    private var cameraMatrix: simd_float4x4

    var content: Content
    var tools: [Tool]

    public init(projection: Binding<any ProjectionProtocol>, cameraMatrix: Binding<simd_float4x4>, tools: [Tool] = Tool.default, @ViewBuilder content: @escaping () -> Content) {
        self._projection = projection
        self._cameraMatrix = cameraMatrix
        self.tools = tools
        self.content = content()
    }

    public var body: some View {
        ToolPickerHost {
            content
                .tool("Turntable", id: "turntable", enabled: tools.contains(.turntable), modifier: { TurntableCameraController(transform: $cameraMatrix) })
                .tool("Orbit", id: "orbit", enabled: tools.contains(.orbit), modifier: { OrbitRotationModifier(cameraMatrix: $cameraMatrix) })
                .tool("Rotation Widget", id: "rotation-widget", enabled: tools.contains(.rotationWidget), modifier: { RotationWidgetToolModifier(cameraMatrix: $cameraMatrix) })
                .tool("FPV Flight", id: "fpv-flight", enabled: tools.contains(.fpvFlight), modifier: { FPVMovementModifier(cameraMatrix: $cameraMatrix, verticalFOV: verticalFOV) })
        }
    }

    private var verticalFOV: CGFloat {
        if let perspectiveProjection = projection as? PerspectiveProjection {
            return CGFloat(perspectiveProjection.verticalAngleOfView.degrees)
        }
        return 90
    }
}
