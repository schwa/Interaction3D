import GeometryLite3D
import simd
import SwiftUI

public struct RotationWidget: View {
    @Binding
    public var rotation: simd_quatf

    public var mesh: Mesh

    public init(rotation: Binding<simd_quatf>, mesh: Mesh = .cube) {
        self._rotation = rotation
        self.mesh = mesh
    }

    @State
    private var verticalFOV: Double = 30

    @State
    private var isDragging: Bool = false

    @State
    private var slerpProgress: Double = 1.0

    @State
    private var slerpFrom: simd_quatf = .identity

    @State
    private var slerpTo: simd_quatf = .identity

    public var body: some View {
        RotationWidgetCanvas(mesh: mesh, rotation: $rotation, isDragging: $isDragging, onRotateTo: { target in
            slerpFrom = rotation
            slerpTo = target
            slerpProgress = 0
            withAnimation(.easeInOut(duration: 0.5)) {
                slerpProgress = 1.0
            }
        }, verticalFOV: verticalFOV)
        .modifier(PitchYawDragModifier(rotation: $rotation, isDragging: $isDragging))
        .modifier(SlerpModifier(progress: slerpProgress) { progress in
            if !isDragging {
                rotation = simd_slerp(slerpFrom, slerpTo, Float(progress))
            }
        })
        .onAppear {
            slerpFrom = rotation
            slerpTo = rotation
        }
    }
}

private struct RotationWidgetCanvas: View {
    let mesh: Mesh

    @Binding
    var rotation: simd_quatf

    @Binding
    var isDragging: Bool

    var onRotateTo: (simd_quatf) -> Void

    @State
    private var size: CGSize = .zero

    var verticalFOV: Double

    @State
    private var renderState = MeshRenderState()

    @State
    private var leastVertex: SIMD3<Float> = .zero

    @State
    private var hoverAreas: [(Path, Color, () -> Void)] = []

    var body: some View {
        ZStack {
            Canvas { context, size in
                let modelMatrix = matrix_identity_float4x4

                for face in renderState.rearFaces {
                    let path = mesh.path(forFace: face, context: renderState.rendererContext, modelMatrix: modelMatrix)
                    context.fill(path, with: .color(.white.opacity(0.3)))
                }
                for edge in renderState.rearEdges {
                    guard let start = renderState.rendererContext.project(edge.start), let end = renderState.rendererContext.project(edge.end) else {
                        continue
                    }
                    var path = Path()
                    path.move(to: start)
                    path.addLine(to: end)
                    let color = color(for: edge)
                    context.stroke(path, with: .color(color.opacity(0.4)))
                }

                for edge in renderState.frontEdges {
                    guard let start = renderState.rendererContext.project(edge.start), let end = renderState.rendererContext.project(edge.end) else {
                        continue
                    }
                    var path = Path()
                    path.move(to: start)
                    path.addLine(to: end)
                    let color = color(for: edge)
                    context.stroke(path, with: .color(color))
                }
            }
            .onGeometryChange(for: CGSize.self, of: \.size) {
                size = $0
                update()
            }

            ForEach(renderState.frontFaces, id: \.self) { face in
                if let center = renderState.rendererContext.project(face.center), let label = renderState.label(for: face.normal), let color = renderState.color(for: face.normal) {
                    Text(label)
                        .foregroundStyle(color)
                        .padding([.leading, .trailing], 4)
                        .background(.black, in: Capsule())
                        .fixedSize()
                        .position(center)
                }
            }
            if !isDragging {
                HoverArea(actions: hoverAreas)
            }
        }
        .onChange(of: mesh, initial: true) {
            update()
        }
        .onChange(of: rotation, initial: true) {
            update()
        }
    }

    func update() {
        leastVertex = mesh.vertices.reduce([Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude]) { min($0, $1) }
        renderState.update(mesh: mesh, rotation: rotation, size: size, verticalFOV: verticalFOV)

        hoverAreas = []
        hoverAreas += mesh.vertices.compactMap { vertex -> (Path, Color, () -> Void)? in
            guard let center = renderState.rendererContext.project(vertex) else {
                return nil
            }
            let rect = CGRect(x: center.x - 5, y: center.y - 5, width: 10, height: 10)
            let path = Path(ellipseIn: rect)
            return (path, Color.accentColor, {
                onRotateTo(mesh.calculateLookAt(at: vertex))
            })
        }
        hoverAreas += renderState.frontEdges.compactMap { edge -> (Path, Color, () -> Void)? in
            guard let start = renderState.rendererContext.project(edge.start), let end = renderState.rendererContext.project(edge.end) else {
                return nil
            }
            let path = Path { path in
                path.move(to: start)
                path.addLine(to: end)
                path = path.strokedPath(StrokeStyle(lineWidth: 5, lineCap: .round))
            }
            return (path, Color.accentColor, {
                onRotateTo(mesh.calculateLookAt(at: edge.center))
            })
        }
        hoverAreas += renderState.frontFaces.compactMap { face in
            let path = mesh.path(forFace: face, context: renderState.rendererContext, modelMatrix: matrix_identity_float4x4)
            return (path, Color.accentColor.opacity(0.3), {
                onRotateTo(mesh.calculateLookAt(at: face.center))
            })
        }
    }

    func color(for edge: Mesh.Edge) -> Color {
        if edge.start == leastVertex || edge.end == leastVertex {
            let delta = normalize(edge.end - edge.start)
            if abs(delta.x) > abs(delta.y), abs(delta.x) > abs(delta.z) {
                return Color.red
            }
            if abs(delta.y) > abs(delta.x), abs(delta.y) > abs(delta.z) {
                return Color.green
            }
            if abs(delta.z) > abs(delta.x), abs(delta.z) > abs(delta.y) {
                return Color.blue
            }
        }
        return Color.white
    }
}

private struct PitchYawDragModifier: ViewModifier {
    @Binding
    var rotation: simd_quatf

    @Binding
    var isDragging: Bool

    @State
    private var pitch: Float = 0

    @State
    private var yaw: Float = 0

    @State
    private var dragStartAngles: (pitch: Float, yaw: Float)?

    func body(content: Content) -> some View {
        content
            .gesture(dragGesture)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                isDragging = true
                if dragStartAngles == nil {
                    let angles = rotation.extractPitchYaw()
                    pitch = angles.pitch
                    yaw = angles.yaw
                    dragStartAngles = angles
                }
                guard let start = dragStartAngles else {
                    return
                }

                let radiansPerPoint: Float = 0.005
                let deltaYaw = -Float(value.translation.width) * radiansPerPoint
                let deltaPitch = -Float(value.translation.height) * radiansPerPoint

                let pitchLimit: Float = .pi / 2
                let newPitch = min(max(start.pitch + deltaPitch, -pitchLimit), pitchLimit)
                let newYaw = fmod(start.yaw + deltaYaw + .pi * 2, .pi * 2)

                pitch = newPitch
                yaw = newYaw
                rotation = .fromPitchYaw(pitch: newPitch, yaw: newYaw)
            }
            .onEnded { _ in
                dragStartAngles = nil
                isDragging = false
            }
    }
}

struct HoverArea: View {
    let actions: [(Path, Color, () -> Void)]

    @State
    private var activePath: Path?

    var body: some View {
        ZStack {
            Color.clear
            if let activePath, let index = actions.firstIndex(where: { $0.0 == activePath }) {
                activePath.fill(actions[index].1)
                    .contentShape(activePath)
                    .onTapGesture {
                        actions[index].2()
                    }
            }
        }
        .onContinuousHover { phase in
            switch phase {
            case .active(let position):
                activePath = actions.first { $0.0.contains(position) }?.0
            case .ended:
                activePath = nil
            }
        }
    }
}
