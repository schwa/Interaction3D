import DemoKit
import GeometryLite3D
import Interaction3D
import SceneKit
import simd
import SpaceMouse
import SwiftUI

struct SpaceMouseDemo: View {
    @State private var cameraMatrix: simd_float4x4 = float4x4(translation: [0, 0, 5])
    @State private var scene: SCNScene = SpaceMouseDemo.makeScene()
    @State private var cameraNode: SCNNode = SpaceMouseDemo.makeCameraNode()
    @State private var spaceMouse: SpaceMouse?
    @State private var isConnected = false
    @State private var lastCommand: String?
    @State private var showInspector = true
    @State private var viewTarget: SIMD3<Double> = .zero
    @State private var pivotPosition: SIMD3<Double> = .zero
    @State private var pivotVisible = false
    @State private var fieldOfView: Double = 0
    @State private var isMoving = false

    private let modelExtents: [Double] = [-1.2, -1.2, -1.2, 1.2, 1.2, 1.2]

    var body: some View {
        SceneView(
            scene: scene,
            pointOfView: cameraNode,
            options: [.rendersContinuously]
        )
        .overlay(alignment: .topLeading) {
            HStack(spacing: 8) {
                Circle()
                    .fill(isConnected ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
                Text(isConnected ? "SpaceMouse Connected" : "SpaceMouse Disconnected")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            .padding()
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: 4) {
                Text("Use SpaceMouse to navigate the 3D scene")
                Text("Push/pull to zoom, tilt to rotate, slide to pan")
            }
            .font(.body)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            .padding()
        }
        .toolbar {
            Toggle(isOn: $showInspector) {
                Label("Inspector", systemImage: "sidebar.trailing")
            }
        }
        .inspector(isPresented: $showInspector) {
            Form {
                Section("Camera Matrix") {
                    MatrixView(value: cameraMatrix, style: .number.precision(.fractionLength(2)), colorize: true)
                        .monospaced()
                }

                Section("SpaceMouse State") {
                    LabeledContent("Moving") {
                        Image(systemName: isMoving ? "circle.fill" : "circle")
                            .foregroundStyle(isMoving ? .green : .secondary)
                    }
                    LabeledContent("View Target") {
                        Text(formatVec3(viewTarget))
                            .monospaced()
                    }
                    LabeledContent("Pivot") {
                        Text(formatVec3(pivotPosition))
                            .monospaced()
                    }
                    LabeledContent("Pivot Visible") {
                        Image(systemName: pivotVisible ? "eye" : "eye.slash")
                    }
                    LabeledContent("FOV") {
                        Text(String(format: "%.1f°", fieldOfView * 180.0 / .pi))
                            .monospaced()
                    }
                    if let lastCommand {
                        LabeledContent("Last Command") {
                            Text(lastCommand)
                                .monospaced()
                        }
                    }
                }


                Section("Actions") {
                    Button("Reset") {
                        cameraMatrix = float4x4(translation: [0, 0, 5])
                        syncCameraToDriver()
                    }
                }
            }
            .inspectorColumnWidth(min: 250, ideal: 300, max: 400)
        }
        .task {
            await connectSpaceMouse()
        }
    }

    private func connectSpaceMouse() async {
        let mouse = SpaceMouse(appName: "Interaction3D")
        let camera = cameraNode.camera!
        mouse.isPerspective = true
        mouse.modelExtents = modelExtents
        mouse.isRotatable = true
        mouse.unitsToMeters = 1.0
        mouse.fieldOfView = camera.fieldOfView * .pi / 180.0
        mouse.viewFrustum = [
            -Double(camera.zNear), Double(camera.zNear),
            -Double(camera.zNear), Double(camera.zNear),
            Double(camera.zNear), Double(camera.zFar),
        ]
        mouse.viewMatrix = matrixToColumnMajorArray(cameraMatrix)

        spaceMouse = mouse

        do {
            let events = try await mouse.events
            isConnected = true
            for await event in events {
                handleEvent(event)
            }
            isConnected = false
        } catch {
            isConnected = false
        }
    }

    private func handleEvent(_ event: SpaceMouseEvent) {
        switch event {
        case .viewMatrix(let values):
            cameraMatrix = columnMajorArrayToMatrix(values)
            cameraNode.simdTransform = cameraMatrix
            syncCameraToDriver()
        case .command(let command):
            lastCommand = command
        case .viewTarget(let t) where t.count >= 3:
            viewTarget = SIMD3(t[0], t[1], t[2])
        case .pivotPosition(let p) where p.count >= 3:
            pivotPosition = SIMD3(p[0], p[1], p[2])
        case .pivotVisible(let v):
            pivotVisible = v
        case .fieldOfView(let fov):
            fieldOfView = fov
        case .motionStart:
            isMoving = true
        case .motionStop:
            isMoving = false
        default:
            break
        }
    }



    private func syncCameraToDriver() {
        spaceMouse?.viewMatrix = matrixToColumnMajorArray(cameraMatrix)
    }

    private func formatVec3(_ v: SIMD3<Double>) -> String {
        String(format: "%.2f, %.2f, %.2f", v.x, v.y, v.z)
    }

    // MARK: - Scene Setup

    private static func makeScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = NSColor.darkGray

        // Ground plane
        let floor = SCNFloor()
        let floorMat = SCNMaterial()
        floorMat.diffuse.contents = NSColor.gray.withAlphaComponent(0.5)
        floor.materials = [floorMat]
        floor.reflectivity = 0.1
        let floorNode = SCNNode(geometry: floor)
        scene.rootNode.addChildNode(floorNode)

        // Cube sitting on the ground
        let box = SCNBox(width: 1, height: 1, length: 1, chamferRadius: 0)
        let boxMat = SCNMaterial()
        boxMat.diffuse.contents = NSColor.white
        box.materials = [boxMat]
        let boxNode = SCNNode(geometry: box)
        boxNode.position = SCNVector3(0, 0.5, 0)
        scene.rootNode.addChildNode(boxNode)

        // Axes
        let axisLength: CGFloat = 3
        let axisRadius: CGFloat = 0.02
        func addAxis(position: SCNVector3, rotation: SCNVector3, color: NSColor) {
            let cylinder = SCNCylinder(radius: axisRadius, height: axisLength)
            let mat = SCNMaterial()
            mat.diffuse.contents = color
            cylinder.materials = [mat]
            let node = SCNNode(geometry: cylinder)
            node.eulerAngles = rotation
            node.position = position
            scene.rootNode.addChildNode(node)
        }
        let half = Float(axisLength / 2)
        addAxis(position: SCNVector3(half, 0, 0), rotation: SCNVector3(0, 0, -Float.pi / 2), color: .red)
        addAxis(position: SCNVector3(0, half, 0), rotation: SCNVector3(0, 0, 0), color: .green)
        addAxis(position: SCNVector3(0, 0, half), rotation: SCNVector3(Float.pi / 2, 0, 0), color: .blue)

        // Light
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light?.type = .omni
        lightNode.light?.intensity = 1000
        lightNode.position = SCNVector3(5, 8, 5)
        scene.rootNode.addChildNode(lightNode)

        let ambientNode = SCNNode()
        ambientNode.light = SCNLight()
        ambientNode.light?.type = .ambient
        ambientNode.light?.intensity = 400
        scene.rootNode.addChildNode(ambientNode)

        return scene
    }

    private static func makeCameraNode() -> SCNNode {
        let camera = SCNCamera()
        camera.zNear = 0.1
        camera.zFar = 100
        camera.fieldOfView = 60
        let node = SCNNode()
        node.camera = camera
        node.simdTransform = float4x4(translation: [0, 0, 5])
        return node
    }

    // MARK: - Matrix Conversion

    private func columnMajorArrayToMatrix(_ values: [Double]) -> simd_float4x4 {
        guard values.count == 16 else {
            return .init(diagonal: [1, 1, 1, 1])
        }
        return simd_float4x4(
            SIMD4<Float>(Float(values[0]), Float(values[1]), Float(values[2]), Float(values[3])),
            SIMD4<Float>(Float(values[4]), Float(values[5]), Float(values[6]), Float(values[7])),
            SIMD4<Float>(Float(values[8]), Float(values[9]), Float(values[10]), Float(values[11])),
            SIMD4<Float>(Float(values[12]), Float(values[13]), Float(values[14]), Float(values[15]))
        )
    }

    private func matrixToColumnMajorArray(_ matrix: simd_float4x4) -> [Double] {
        (0..<4).flatMap { col in
            (0..<4).map { row in
                Double(matrix[col][row])
            }
        }
    }
}


extension SpaceMouseDemo: DemoView {
    static var metadata = DemoMetadata(
        name: "SpaceMouse",
        description: "3D navigation using a 3Dconnexion SpaceMouse.",
        group: "Interaction"
    )
}
