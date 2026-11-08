import simd
import SwiftUI

// MARK: - Interaction State & Inputs

/// Camera state for interactive orbit controls: rotation quaternion, distance from target, and target point.
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

/// Per-frame input deltas from gestures: rotation, pan, and zoom deltas plus absolute positions for arcball.
public struct InteractionInput: Equatable, Sendable {
    // Deltas (turntable uses these)
    public var rotation: CGSize
    public var pan: CGSize
    public var zoom: Double

    // Absolute positions (arcball uses these)
    public var startLocation: CGPoint
    public var currentLocation: CGPoint
    public var viewSize: CGSize
    public var rotationAtDragStart: simd_quatf

    public init(
        rotation: CGSize = .zero,
        pan: CGSize = .zero,
        zoom: Double = 0,
        startLocation: CGPoint = .zero,
        currentLocation: CGPoint = .zero,
        viewSize: CGSize = .zero,
        rotationAtDragStart: simd_quatf = simd_quatf(angle: 0, axis: [0, 1, 0])
    ) {
        self.rotation = rotation
        self.pan = pan
        self.zoom = zoom
        self.startLocation = startLocation
        self.currentLocation = currentLocation
        self.viewSize = viewSize
        self.rotationAtDragStart = rotationAtDragStart
    }
}

// MARK: - Axis Transforms

/// Linear sensitivity for each interaction axis (yaw, pitch, zoom, pan).
/// Plain values rather than closures, so SwiftUI can compare gesture modifier inputs. Negative scales invert an axis.
public struct InteractionAxisTransforms: Equatable, Sendable {
    public var yawScale: Double
    public var pitchScale: Double
    public var zoomScale: Double
    // Maps drag x/y points to pan x/y; pan never moves along z.
    public var panScale: SIMD2<Double>

    public init(yaw: Double = 0.005, pitch: Double = 0.005, zoom: Double = -0.01, pan: SIMD2<Double> = [0.01, -0.01]) {
        self.yawScale = yaw
        self.pitchScale = pitch
        self.zoomScale = zoom
        self.panScale = pan
    }

    public func yaw(_ delta: Double) -> Double {
        delta * yawScale
    }

    public func pitch(_ delta: Double) -> Double {
        delta * pitchScale
    }

    public func zoom(_ delta: Double) -> Double {
        delta * zoomScale
    }

    public func pan(_ delta: SIMD2<Double>) -> SIMD3<Float> {
        let scaled = delta * panScale
        return SIMD3<Float>(Float(scaled.x), Float(scaled.y), 0)
    }
}

public extension InteractionAxisTransforms {
    static let `default` = InteractionAxisTransforms()

    static let turntableDefault = InteractionAxisTransforms(yaw: 0.01, pitch: 0.01, zoom: -0.5, pan: [0.02, -0.02])
}

// MARK: - Transformers Protocol

/// A transformer that takes interaction input and applies it to camera state, returning updated state.
public protocol InteractionTransformer: Transformer where Input == InteractionState, Output == InteractionState {
    var input: InteractionInput { get set }
    var transforms: InteractionAxisTransforms { get set }
}
