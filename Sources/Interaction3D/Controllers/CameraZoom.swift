import SwiftUI

/// How scroll and magnify gestures change camera distance.
public enum CameraZoomModel: Equatable, Sendable {
    /// Adds the zoom transform's output to the distance. One step moves the same amount at any distance.
    case additive

    /// Scales the distance by `exp(output * rate)`, where `output` is the zoom transform's output. One step moves
    /// the same fraction of the distance, so zoom feels the same whether the camera is near or far.
    case multiplicative(rate: Double = 0.1)

    /// Zoom step in coordinate units (distance, or log distance) for a zoom transform output.
    func step(forZoomOutput output: Double) -> Double {
        switch self {
        case .additive:
            output
        case let .multiplicative(rate):
            output * rate
        }
    }
}

/// Maps between a distance and the coordinate that zoom gestures add to: the distance itself, or its logarithm.
struct CameraZoomCoordinate<Scalar: BinaryFloatingPoint> {
    var model: CameraZoomModel
    var distanceRange: ClosedRange<Scalar>

    func coordinate(for distance: Scalar) -> Double {
        switch model {
        case .additive:
            Double(distance)
        case .multiplicative:
            log(max(Double(distance), .leastNormalMagnitude))
        }
    }

    func distance(for coordinate: Double) -> Scalar {
        let distance: Scalar
        switch model {
        case .additive:
            distance = Scalar(coordinate)
        case .multiplicative:
            distance = Scalar(exp(coordinate))
        }
        return min(max(distance, distanceRange.lowerBound), distanceRange.upperBound)
    }
}

struct CameraZoomStepTransformer: Transformer {
    var transforms: InteractionAxisTransforms
    var magnitude: Double
    var zoom: CameraZoomModel

    func transform(_ input: Double) -> Double {
        zoom.step(forZoomOutput: transforms.zoom(input * magnitude))
    }
}

/// Scroll (macOS) and magnify zoom for a distance of any floating-point type.
struct CameraZoomModifier<Scalar: BinaryFloatingPoint>: ViewModifier {
    @Binding var distance: Scalar
    var transforms: InteractionAxisTransforms
    var zoom: CameraZoomModel
    var distanceRange: ClosedRange<Scalar>

    func body(content: Content) -> some View {
        content
            #if os(macOS)
            .transformedScrollGesture(
                transformer: CameraZoomStepTransformer(transforms: transforms, magnitude: 1, zoom: zoom),
                writes: coordinate
            )
            #endif
            .transformedMagnifyGesture(
                transformer: CameraZoomStepTransformer(transforms: transforms, magnitude: 100, zoom: zoom),
                writes: coordinate
            )
    }

    private var coordinate: Binding<Double> {
        let mapping = CameraZoomCoordinate(model: zoom, distanceRange: distanceRange)
        return Binding {
            mapping.coordinate(for: distance)
        } set: { newValue in
            distance = mapping.distance(for: newValue)
        }
    }
}
