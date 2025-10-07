import SwiftUI
import DemoKit
import Interaction3D
import GeometryLite3D
import simd
import SceneKit

struct WorldViewDemo: View {
    @State private var model = CityModel()

    @State
    var projection: any ProjectionProtocol = PerspectiveProjection()

    var body: some View {
        WorldView(projection: $projection, cameraMatrix: $model.cameraNode.simdTransform) {
            SceneView(
                scene: model.scene,
                pointOfView: model.cameraNode,
                options: [.autoenablesDefaultLighting, .rendersContinuously]
            )
        }
    }
}

extension WorldViewDemo: DemoView {
    static var metadata = DemoMetadata(
        name: "World View"
    )
}
