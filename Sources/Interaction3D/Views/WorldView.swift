import GeometryLite3D
import simd
import SwiftUI

enum WorldViewProjectionCapabilities {
    static func verticalFOV(for projection: any ProjectionProtocol, override: CGFloat?) -> CGFloat? {
        override ?? (projection as? PerspectiveProjection).map { CGFloat($0.verticalAngleOfView.degrees) }
    }
}

public struct WorldView<Content: View>: View {
    public enum Tool: String, CaseIterable, Sendable {
        case turntable
        case rotationWidget
        case fpvFlight
        case fpvFlightSim
        case debugOverlay

        public static var `default`: [Self] {
            [.turntable, .rotationWidget, .fpvFlight, .fpvFlightSim]
        }
    }

    @Binding
    var projection: any ProjectionProtocol

    @Binding
    private var cameraMatrix: simd_float4x4

    var content: Content
    var tools: [Tool]
    var turntableTarget: SIMD3<Float>
    var flightSimulationVerticalFOV: CGFloat?

    public init(
        projection: Binding<any ProjectionProtocol>,
        cameraMatrix: Binding<simd_float4x4>,
        tools: [Tool] = Tool.default,
        turntableTarget: SIMD3<Float> = .zero,
        flightSimulationVerticalFOV: CGFloat? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self._projection = projection
        self._cameraMatrix = cameraMatrix
        self.tools = tools
        self.turntableTarget = turntableTarget
        self.flightSimulationVerticalFOV = flightSimulationVerticalFOV
        self.content = content()
    }

    public var body: some View {
        ToolPickerHost {
            content
                .tool("Turntable", group: .interaction, id: "turntable", enabled: tools.contains(.turntable)) {
                    InteractiveCameraMatrixModifier(
                        cameraMatrix: $cameraMatrix,
                        mode: .turntable(),
                        target: turntableTarget
                    )
                }
                .tool("Rotation Widget", group: .interaction, id: "rotation-widget", enabled: tools.contains(.rotationWidget)) { RotationWidgetToolModifier(cameraMatrix: $cameraMatrix) }
                #if os(macOS)
                .tool("FPV", group: .interaction, id: "fpv-flight", enabled: tools.contains(.fpvFlight)) { FPVMovementModifier(cameraMatrix: $cameraMatrix) }
                .tool(
                    "FPV Flight Sim",
                    group: .interaction,
                    id: "fpv-flight-sim",
                    enabled: tools.contains(.fpvFlightSim) && verticalFOV != nil
                ) {
                    FPVFlightSimModifier(cameraMatrix: $cameraMatrix, verticalFOV: requiredVerticalFOV)
                }
                #endif
                .tool("Off", group: .debug, id: "debug-off", enabled: tools.contains(.debugOverlay)) { EmptyModifier() }
                .tool("Overlay", group: .debug, id: "debug-overlay", enabled: tools.contains(.debugOverlay)) { DebugOverlayToolModifier() }
        }
    }

    private var verticalFOV: CGFloat? {
        WorldViewProjectionCapabilities.verticalFOV(
            for: projection,
            override: flightSimulationVerticalFOV
        )
    }

    private var requiredVerticalFOV: CGFloat {
        guard let verticalFOV else {
            preconditionFailure("FPV flight simulation requires a vertical field of view.")
        }
        return verticalFOV
    }
}

#Preview {
    @Previewable @State var projection: any ProjectionProtocol = PerspectiveProjection(verticalAngleOfView: .degrees(60))
    @Previewable @State var cameraMatrix = matrix_identity_float4x4

    WorldView(projection: $projection, cameraMatrix: $cameraMatrix) {
        Color.blue
    }
}
