import simd
import SwiftUI

// MARK: - Interaction State & Inputs

public struct InteractionState: Equatable, Sendable {
    public var rotation: simd_quatf
    public var distance: Float
    public var target: SIMD3<Float>

    public init(rotation: simd_quatf = simd_quatf(angle: 0, axis: [0, 1, 0]), distance: Float = 5, target: SIMD3<Float> = .zero) {
        self.rotation = rotation
        self.distance = distance
        self.target = target
    }
}

public struct InteractionInput: Equatable, Sendable {
    public var rotation: CGSize
    public var pan: CGSize
    public var zoom: Double

    public init(rotation: CGSize = .zero, pan: CGSize = .zero, zoom: Double = 0) {
        self.rotation = rotation
        self.pan = pan
        self.zoom = zoom
    }
}

// MARK: - Axis Transforms

public struct InteractionAxisTransforms: Sendable {
    public typealias AxisTransform = @Sendable (Double) -> Double
    public typealias PanTransform = @Sendable (SIMD2<Double>) -> SIMD3<Float>

    public var yaw: AxisTransform
    public var pitch: AxisTransform
    public var zoom: AxisTransform
    public var pan: PanTransform

    public init(
        yaw: @escaping AxisTransform = InteractionAxisTransforms.defaultYaw,
        pitch: @escaping AxisTransform = InteractionAxisTransforms.defaultPitch,
        zoom: @escaping AxisTransform = InteractionAxisTransforms.defaultZoom,
        pan: @escaping PanTransform = InteractionAxisTransforms.defaultPan
    ) {
        self.yaw = yaw
        self.pitch = pitch
        self.zoom = zoom
        self.pan = pan
    }
}

public extension InteractionAxisTransforms {
    static let `default` = InteractionAxisTransforms()

    static let defaultYaw: AxisTransform = { delta in
        delta * 0.005
    }

    static let defaultPitch: AxisTransform = { delta in
        delta * 0.005
    }

    static let defaultZoom: AxisTransform = { delta in
        -delta * 0.01
    }

    static let defaultPan: PanTransform = { delta in
        SIMD3<Float>(Float(delta.x * 0.01), Float(-delta.y * 0.01), 0)
    }

    static let turntableDefault = InteractionAxisTransforms(
        yaw: { $0 * 0.01 },
        pitch: { $0 * 0.01 },
        zoom: { -$0 * 0.5 },
        pan: { delta in SIMD3<Float>(Float(delta.x * 0.02), Float(-delta.y * 0.02), 0) }
    )
}

// MARK: - Transformers Protocol

public protocol InteractionTransformer: TransformerProtocol where Value == InteractionState {
    var input: InteractionInput { get set }
    var transforms: InteractionAxisTransforms { get set }
}
