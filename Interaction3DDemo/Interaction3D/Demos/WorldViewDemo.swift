import SwiftUI
import DemoKit
import Interaction3D
import GeometryLite3D
import simd
import SceneKit
import DemoKit
import Observation
import SceneKit
import simd
import Spatial
import SwiftUI

struct WorldViewDemo: View {
    @State private var model = CityModel()

    @State
    var projection: any ProjectionProtocol = PerspectiveProjection()

    var body: some View {
        WorldView(projection: $projection, cameraMatrix: $model.cameraNode.simdTransform, tools: [
            .orbit,
            .turntable,
//            .fpvFlight,
//            .rotationWidget
        ]) {
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

@Observable
class CityModel {
    var scene: SCNScene
    var cameraNode: SCNNode
    var sceneBounds: (min: SCNVector3, max: SCNVector3)?

    init() {
        guard let url = Bundle.main.url(forResource: "Beautiful_city", withExtension: "usdz") else {
            preconditionFailure("Failed to locate Beautiful_city.usdz in bundle")
        }

        let scene: SCNScene
        do {
            scene = try SCNScene(url: url)
        } catch {
            preconditionFailure("Failed to load Beautiful_city.usdz: \(error)")
        }
        scene.background.contents = NSColor.black

        let originMarker = SCNNode(geometry: SCNSphere(radius: 0.1))
        scene.rootNode.addChildNode(originMarker)

        // Add coordinate axes
        let axisLength: CGFloat = 100
        let axisThickness: CGFloat = 0.05

        // X axis (red)
        let xAxis = SCNCylinder(radius: axisThickness, height: axisLength)
        xAxis.firstMaterial?.diffuse.contents = NSColor.red
        let xAxisNode = SCNNode(geometry: xAxis)
        xAxisNode.eulerAngles.z = .pi / 2
        xAxisNode.position = SCNVector3(axisLength / 2, 0, 0)
        scene.rootNode.addChildNode(xAxisNode)

        // Y axis (green)
        let yAxis = SCNCylinder(radius: axisThickness, height: axisLength)
        yAxis.firstMaterial?.diffuse.contents = NSColor.green
        let yAxisNode = SCNNode(geometry: yAxis)
        yAxisNode.position = SCNVector3(0, axisLength / 2, 0)
        scene.rootNode.addChildNode(yAxisNode)

        // Z axis (blue)
        let zAxis = SCNCylinder(radius: axisThickness, height: axisLength)
        zAxis.firstMaterial?.diffuse.contents = NSColor.blue
        let zAxisNode = SCNNode(geometry: zAxis)
        zAxisNode.eulerAngles.x = .pi / 2
        zAxisNode.position = SCNVector3(0, 0, axisLength / 2)
        scene.rootNode.addChildNode(zAxisNode)

        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.zFar = 10_000
        cameraNode.simdPosition = [0, 0, 0]
        scene.rootNode.addChildNode(cameraNode)

        self.scene = scene
        self.cameraNode = cameraNode

        // Calculate scene bounds
        let (min, max) = scene.rootNode.boundingBox
        self.sceneBounds = (min, max)
    }
}
