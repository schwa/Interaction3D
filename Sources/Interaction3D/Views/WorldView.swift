import GeometryLite3D
import simd
import SwiftUI

public struct WorldView<Content: View>: View {
    public enum Tool: String, CaseIterable, Sendable {
        case trackball
        case rotationWidget
        case fpvFlight
        case fpvFlightSim

        public static var `default`: [Tool] {
            [.trackball, .rotationWidget, .fpvFlight, .fpvFlightSim]
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
                .tool("Trackball", group: .interaction, id: "trackball", enabled: tools.contains(.trackball), modifier: {
                    CameraMatrixInteractionController(
                        cameraMatrix: $cameraMatrix,
                        mode: .trackball()
                    )
                })
                .tool("Rotation Widget", group: .interaction, id: "rotation-widget", enabled: tools.contains(.rotationWidget), modifier: { RotationWidgetToolModifier(cameraMatrix: $cameraMatrix) })
                #if os(macOS)
                .tool("FPV", group: .interaction, id: "fpv-flight", enabled: tools.contains(.fpvFlight), modifier: { FPVMovementModifier(cameraMatrix: $cameraMatrix) })
                .tool("FPV Flight Sim", group: .interaction, id: "fpv-flight-sim", enabled: tools.contains(.fpvFlightSim), modifier: { FPVFlightSimModifier(cameraMatrix: $cameraMatrix, verticalFOV: verticalFOV) })
                #endif
                .tool("Off", group: .debug, id: "debug-off", modifier: { EmptyModifier() })
                .tool("Overlay", group: .debug, id: "debug-overlay", modifier: { DebugOverlayToolModifier() })
        }
    }

    private var verticalFOV: CGFloat {
        if let perspectiveProjection = projection as? PerspectiveProjection {
            return CGFloat(perspectiveProjection.verticalAngleOfView.degrees)
        }
        return 60
    }
}
