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
            // Top leading: Navigation instruments
            VStack(alignment: .leading) {
                HStack(alignment: .top, spacing: 12) {
                    ArtificialHorizonView(transform: transform)
                        .frame(width: 150, height: 150)
                        .cornerRadius(8)

                    CompassView(heading: heading, labelStyle: .axis)
                        .frame(width: 150, height: 150)
                        .cornerRadius(8)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()

            // Top trailing: Map
            VStack(alignment: .trailing) {
                MapView(
                    transform: transform,
                    breadcrumbs: breadcrumbs,
                    scale: mapScale
                )
                .frame(width: 200, height: 200)
                .cornerRadius(8)
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding()

            // Bottom leading: Speedometer
            VStack {
                Spacer()
                HStack {
                    SpeedometerView(
                        linearVelocity: linearVelocity,
                        angularVelocity: angularVelocity
                    )
                    .frame(width: 240)
                    Spacer()
                }
            }
            .padding()

            // Bottom trailing: Info panel
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    infoPanel
                }
            }
            .padding()

            // Center: Horizon cue
            HorizonCue(pitch: pitch, verticalFOV: verticalFOV)
                .allowsHitTesting(false)
        }
    }

    private var heading: Angle {
        let forward = SIMD4<Float>(0, 0, -1, 0)
        let worldForward = transform * forward
        let headingRadians = atan2(Double(worldForward.x), Double(-worldForward.z))
        let normalizedHeading = headingRadians < 0 ? headingRadians + 2 * .pi : headingRadians
        return Angle(radians: normalizedHeading)
    }

    private var infoPanel: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("Heading: \(heading.degrees, format: .number.precision(.fractionLength(1)))°")
            Text("Position: (\(transform.columns.3.x, format: .number.precision(.fractionLength(1))), \(transform.columns.3.y, format: .number.precision(.fractionLength(1))), \(transform.columns.3.z, format: .number.precision(.fractionLength(1))))")
            Text("Speed: \(speed, format: .number.precision(.fractionLength(1))) m/s")
        }
        .font(.caption)
        .foregroundStyle(.white)
        .padding(12)
        .background(Color.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
