import simd
import SwiftUI

/// A convenience view that composes all flight simulation controls together.
/// Users can also use the individual views (`ArtificialHorizonView`, `CompassView`, etc.)
/// to build their own custom layouts.
public struct FlightSimControlsView: View {
    public var transform: matrix_float4x4
    public var linearVelocity: SIMD3<Float>
    public var angularVelocity: SIMD3<Float>
    public var pitch: Float
    public var verticalFOV: CGFloat
    public var breadcrumbs: [SIMD2<Float>]
    public var mapScale: CGFloat
    public var speed: Float

    public init(
        transform: matrix_float4x4,
        linearVelocity: SIMD3<Float> = .zero,
        angularVelocity: SIMD3<Float> = .zero,
        pitch: Float = 0,
        verticalFOV: CGFloat = 60,
        breadcrumbs: [SIMD2<Float>] = [],
        mapScale: CGFloat = 2.0,
        speed: Float = 0
    ) {
        self.transform = transform
        self.linearVelocity = linearVelocity
        self.angularVelocity = angularVelocity
        self.pitch = pitch
        self.verticalFOV = verticalFOV
        self.breadcrumbs = breadcrumbs
        self.mapScale = mapScale
        self.speed = speed
    }

    public var body: some View {
        ZStack {
            VStack {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top) {
                        ArtificialHorizonView(transform: transform)
                            .aspectRatio(1, contentMode: .fit)
                            .clipShape(.rect(cornerRadius: 8))
                        CompassView(heading: heading, labelStyle: .axis)
                            .aspectRatio(1, contentMode: .fit)
                            .clipShape(.rect(cornerRadius: 8))
                        Spacer()
                        MapView(transform: transform, breadcrumbs: breadcrumbs, scale: mapScale)
                            .aspectRatio(1, contentMode: .fit)
                            .clipShape(.rect(cornerRadius: 8))
                    }

                    VStack {
                        HStack {
                            ArtificialHorizonView(transform: transform)
                                .aspectRatio(1, contentMode: .fit)
                                .clipShape(.rect(cornerRadius: 8))
                            CompassView(heading: heading, labelStyle: .axis)
                                .aspectRatio(1, contentMode: .fit)
                                .clipShape(.rect(cornerRadius: 8))
                        }
                        MapView(transform: transform, breadcrumbs: breadcrumbs, scale: mapScale)
                            .aspectRatio(1, contentMode: .fit)
                            .clipShape(.rect(cornerRadius: 8))
                    }
                }

                Spacer()

                HStack(alignment: .bottom) {
                    SpeedometerView(linearVelocity: linearVelocity, angularVelocity: angularVelocity)
                        .frame(maxWidth: 240)
                    Spacer()
                    FlightInfoPanelView(heading: heading, transform: transform, speed: speed)
                }
            }

            HorizonCue(pitch: pitch, verticalFOV: verticalFOV)
                .allowsHitTesting(false)
        }
        .padding()
    }

    private var heading: Angle {
        let forward = SIMD4<Float>(0, 0, -1, 0)
        let worldForward = transform * forward
        let headingRadians = atan2(Double(worldForward.x), Double(-worldForward.z))
        let normalizedHeading = headingRadians < 0 ? headingRadians + 2 * .pi : headingRadians
        return Angle(radians: normalizedHeading)
    }

}

private struct FlightInfoPanelView: View {
    let heading: Angle
    let transform: matrix_float4x4
    let speed: Float

    var body: some View {
        VStack(alignment: .trailing) {
            Text("Heading: \(heading.degrees, format: .number.precision(.fractionLength(1)))°")
            Text("Position: (\(transform.columns.3.x, format: .number.precision(.fractionLength(1))), \(transform.columns.3.y, format: .number.precision(.fractionLength(1))), \(transform.columns.3.z, format: .number.precision(.fractionLength(1))))")
            Text("Speed: \(speed, format: .number.precision(.fractionLength(1))) m/s")
        }
        .font(.caption)
        .foregroundStyle(.white)
        .padding()
        .background(.black.opacity(0.5), in: .rect(cornerRadius: 12))
    }
}

#Preview {
    FlightSimControlsView(
        transform: matrix_identity_float4x4,
        linearVelocity: [1, 0, 5],
        pitch: 0.1,
        speed: 10
    )
    .background(Color.gray)
}

#Preview("Info Panel") {
    FlightInfoPanelView(heading: .degrees(45), transform: matrix_identity_float4x4, speed: 10)
        .padding()
}
