import GeometryLite3D
import simd
import SwiftUI
import SwiftFormats

@MainActor
public struct PitchYawDragViewModifier: ViewModifier {
    @Binding
    var pitch: Angle

    @Binding
    var yaw: Angle

    @State
    private var rawTranslation: CGSize = .zero

    @State
    private var initialPitch: Angle?

    @State
    private var initialYaw: Angle?

    var pitchTransform: (Angle) -> Angle
    var yawTransform: (Angle) -> Angle

    public init(pitch: Binding<Angle>, yaw: Binding<Angle>, pitchTransform: @escaping (Angle) -> Angle = { $0 }, yawTransform: @escaping (Angle) -> Angle = { $0 }) {
        self._pitch = pitch
        self._yaw = yaw
        self.pitchTransform = pitchTransform
        self.yawTransform = yawTransform
    }

    public func body(content: Content) -> some View {
        let clampedTranslation = Binding<CGSize>(
            get: { rawTranslation },
            set: { newValue in
                // Calculate what the angles would be with this translation
                let newPitch = Angle(degrees: (initialPitch?.degrees ?? 0) + newValue.height)
                let newYaw = Angle(degrees: (initialYaw?.degrees ?? 0) + newValue.width)

                // Apply transforms to see what the clamped angles are
                let transformedPitch = pitchTransform(newPitch)
                let transformedYaw = yawTransform(newYaw)

                // Back-calculate the clamped translation
                rawTranslation = CGSize(
                    width: transformedYaw.degrees - (initialYaw?.degrees ?? 0),
                    height: transformedPitch.degrees - (initialPitch?.degrees ?? 0)
                )
            }
        )

        content
            .modifier(DragGestureModifier(
                translation: clampedTranslation
            ))
            .onChange(of: rawTranslation) { oldValue, newValue in
                if initialPitch == nil {
                    initialPitch = pitch
                    initialYaw = yaw
                }

                // Calculate absolute angles and apply transforms
                let newPitch = Angle(degrees: (initialPitch?.degrees ?? 0) + newValue.height)
                let newYaw = Angle(degrees: (initialYaw?.degrees ?? 0) + newValue.width)

                let transformedPitch = pitchTransform(newPitch)
                let transformedYaw = yawTransform(newYaw)

                pitch = transformedPitch
                yaw = transformedYaw
            }
            .onChange(of: rawTranslation == .zero) { _, isZero in
                if isZero {
                    initialPitch = nil
                    initialYaw = nil
                }
            }
            .overlay(alignment: .topLeading) {
                if ProcessInfo.processInfo.debugUI {
                    Form {
                        LabeledContent("Pitch") {
                            Text(pitch, format: .angle)
                        }
                        LabeledContent("Yaw") {
                            Text(yaw, format: .angle)
                        }
                        LabeledContent("Raw Translation") {
                            Text(rawTranslation, format: .size)
                        }
                        LabeledContent("Initial Pitch") {
                            Text(initialPitch ?? .zero, format: .angle)
                        }
                        LabeledContent("Initial Yaw") {
                            Text(initialYaw ?? .zero, format: .angle)
                        }
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .padding()
                }
            }
    }
}

public extension PitchYawDragViewModifier {
    init(rotation: Binding<simd_quatf>, pitchTransform: @escaping (Angle) -> Angle = { $0 }, yawTransform: @escaping (Angle) -> Angle = { $0 }) {

        let pitch = Binding<Angle>(
            get: {
                // Extract pitch from quaternion using Euler angle conversion
                let q = rotation.wrappedValue
                let sinp = 2.0 * (q.vector.w * q.vector.x - q.vector.y * q.vector.z)
                let pitch = asin(min(max(sinp, -1.0), 1.0))
                return Angle(radians: Double(pitch))
            },
            set: { newPitch in
                // Extract current yaw from quaternion
                let q = rotation.wrappedValue
                let siny = 2.0 * (q.vector.w * q.vector.y + q.vector.x * q.vector.z)
                let cosy = 1.0 - 2.0 * (q.vector.x * q.vector.x + q.vector.y * q.vector.y)
                let currentYaw = atan2(siny, cosy)

                // Create new quaternion from yaw and new pitch
                let yawQuat = simd_quatf(angle: Float(currentYaw), axis: SIMD3<Float>(0, 1, 0))
                let pitchQuat = simd_quatf(angle: Float(newPitch.radians), axis: SIMD3<Float>(1, 0, 0))
                rotation.wrappedValue = yawQuat * pitchQuat
            }
        )
        let yaw = Binding<Angle>(
            get: {
                // Extract yaw from quaternion using Euler angle conversion
                let q = rotation.wrappedValue
                let siny = 2.0 * (q.vector.w * q.vector.y + q.vector.x * q.vector.z)
                let cosy = 1.0 - 2.0 * (q.vector.x * q.vector.x + q.vector.y * q.vector.y)
                let yaw = atan2(siny, cosy)
                return Angle(radians: Double(yaw))
            },
            set: { newYaw in
                // Extract current pitch from quaternion
                let q = rotation.wrappedValue
                let sinp = 2.0 * (q.vector.w * q.vector.x - q.vector.y * q.vector.z)
                let currentPitch = asin(min(max(sinp, -1.0), 1.0))

                // Create new quaternion from new yaw and pitch
                let yawQuat = simd_quatf(angle: Float(newYaw.radians), axis: SIMD3<Float>(0, 1, 0))
                let pitchQuat = simd_quatf(angle: Float(currentPitch), axis: SIMD3<Float>(1, 0, 0))
                rotation.wrappedValue = yawQuat * pitchQuat
            }
        )
        self.init(pitch: pitch, yaw: yaw, pitchTransform: pitchTransform, yawTransform: yawTransform)

    }
}
