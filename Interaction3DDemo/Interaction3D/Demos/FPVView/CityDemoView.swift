import Interaction3D
import Observation
import SceneKit
import simd
import Spatial
import SwiftUI
import DemoKit

struct CityDemoView: View {
    @State private var model = CityModel()

    init() {        
    }

    var body: some View {
        ToolPickerHost {
            SceneView(
                scene: model.scene,
                pointOfView: model.cameraNode,
                options: [.autoenablesDefaultLighting, .rendersContinuously]
            )
            .tool("FPV Flight", id: "fpv-flight", modifier: FPVMomentModifier(cameraMatrix: $model.cameraNode.simdTransform, verticalFOV: model.cameraNode.camera!.fieldOfView))
            .tool("Turntable", id: "turntable", modifier: TurnableModifier(cameraMatrix: $model.cameraNode.simdTransform))
        }
    }
}


extension CityDemoView: DemoView {
    static var metadata = DemoMetadata(
        name: "FPV Explorer",
        systemImage: "scope",
        description: "First-person navigation through the sample city scene.",
        group: "Interaction3D",
        keywords: ["fpv", "flight", "navigation", "interaction3d"],
        color: .accentColor
    )
}
