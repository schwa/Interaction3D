import AsyncAlgorithms
import simd
import SwiftUI

// A camera looking down at a point on the XZ ground plane.
public struct RTSCameraPose: Equatable, Sendable {
    public var target: SIMD3<Float>
    public var yaw: Float
    // Angle down from the horizon.
    public var pitch: Float
    public var distance: Float

    public init(target: SIMD3<Float> = .zero, yaw: Float = 0, pitch: Float = .pi / 4, distance: Float = 10) {
        self.target = target
        self.yaw = yaw
        self.pitch = pitch
        self.distance = distance
    }

    public var cameraMatrix: simd_float4x4 {
        let yawRotation = simd_quatf(angle: yaw, axis: [0, 1, 0])
        let pitchRotation = simd_quatf(angle: -pitch, axis: [1, 0, 0])
        var translation = matrix_identity_float4x4
        translation.columns.3 = SIMD4<Float>(target, 1)
        var pullBack = matrix_identity_float4x4
        pullBack.columns.3 = [0, 0, distance, 1]
        return translation * simd_float4x4(yawRotation * pitchRotation) * pullBack
    }

    // Moves the target along the ground. pan.x is right, pan.y is forward, in multiples of distance.
    public func panned(by pan: SIMD2<Float>) -> Self {
        var pose = self
        let forward = SIMD3<Float>(-sin(yaw), 0, -cos(yaw))
        let right = SIMD3<Float>(cos(yaw), 0, -sin(yaw))
        pose.target += (right * pan.x + forward * pan.y) * distance
        return pose
    }

    // Drags the ground with a touch. translation is in fractions of the view height, +Y down.
    public func grabbed(translation: CGSize) -> Self {
        panned(by: SIMD2<Float>(-Float(translation.width), Float(translation.height)))
    }

    // Orbits around the target. translation is in fractions of the view height, +Y down.
    // Dragging down raises the camera.
    public func orbited(translation: CGSize, speed: Float, pitchRange: ClosedRange<Float>) -> Self {
        var pose = self
        pose.yaw -= Float(translation.width) * speed
        pose.pitch = min(max(pitch + Float(translation.height) * speed, pitchRange.lowerBound), pitchRange.upperBound)
        return pose
    }
}

public struct RTSMovementSettings: Equatable, Sendable {
    // Pan speed in view heights per second, so panning feels the same at any zoom.
    public var panSpeed: Float
    public var fastSpeedMultiplier: Float
    public var rotateSpeed: Float
    // Keyboard zoom, as a distance multiplier per second.
    public var zoomSpeed: Float
    // Distance multiplier per scroll step.
    public var zoomStepFactor: Float
    public var distanceRange: ClosedRange<Float>
    public var edgePanMargin: CGFloat
    // Radians per view height of drag.
    public var orbitSpeed: Float
    public var pitchRange: ClosedRange<Float>

    public init(
        panSpeed: Float = 1,
        fastSpeedMultiplier: Float = 3,
        rotateSpeed: Float = .pi / 2,
        zoomSpeed: Float = 2,
        zoomStepFactor: Float = 1.1,
        distanceRange: ClosedRange<Float> = 2...100,
        edgePanMargin: CGFloat = 0.02,
        orbitSpeed: Float = .pi,
        pitchRange: ClosedRange<Float> = 0.1...(.pi / 2 - 0.01)
    ) {
        self.orbitSpeed = orbitSpeed
        self.pitchRange = pitchRange
        self.panSpeed = panSpeed
        self.fastSpeedMultiplier = fastSpeedMultiplier
        self.rotateSpeed = rotateSpeed
        self.zoomSpeed = zoomSpeed
        self.zoomStepFactor = zoomStepFactor
        self.distanceRange = distanceRange
        self.edgePanMargin = edgePanMargin
    }
}

public struct RTSMovementModifier: ViewModifier {
    let navigator: RTSNavigator
    let updatesAutomatically: Bool

    @Environment(\.interactionScrollFilter)
    private var scrollFilter

    @State
    private var gestures = GestureState()

    // Last cumulative values reported by the shared gestures, to turn them into deltas.
    private struct GestureState {
        var panTranslation: CGSize = .zero
        var orbitTranslation: CGSize = .zero
        var magnification: Double = 1
        var rotation: Angle = .zero
    }

    // updatesAutomatically: false means the app calls navigator.update(deltaTime:) from its own frame loop.
    public init(navigator: RTSNavigator, updatesAutomatically: Bool = true) {
        self.navigator = navigator
        self.updatesAutomatically = updatesAutomatically
    }

    public func body(content: Content) -> some View {
        GeometryReader { proxy in
            content
                .frame(width: proxy.size.width, height: proxy.size.height)
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let location):
                        navigator.pointerLocation = CGPoint(x: location.x / proxy.size.width, y: location.y / proxy.size.height)
                        navigator.isScrollAllowed = scrollFilter?.accepts(location) ?? true
                    case .ended:
                        navigator.pointerLocation = nil
                    }
                }
                .contentShape(Rectangle())
                .modifier(gestureModifiers(viewHeight: proxy.size.height))
        }
        .movementInputFocus(claiming: .rtsMovementKeys) { isFocused in
            navigator.isKeyboardEnabled = isFocused
        }
        .task { await navigator.runInput() }
        .task(id: updatesAutomatically) {
            if updatesAutomatically {
                await navigator.runUpdates()
            }
        }
    }

    // Drag pans; Option-drag (macOS) or two-finger drag (iOS) orbits; pinch zooms; twist rotates. All coast on release.
    private func gestureModifiers(viewHeight: CGFloat) -> some ViewModifier {
        RTSGestures(
            onPan: { translation in
                navigator.setGesture(.pan, isActive: true)
                navigator.grab(Self.viewFraction(translation, since: gestures.panTranslation, viewHeight: viewHeight))
                gestures.panTranslation = translation
            },
            onPanEnded: {
                gestures.panTranslation = .zero
                navigator.setGesture(.pan, isActive: false)
            },
            onOrbit: { translation in
                navigator.setGesture(.orbit, isActive: true)
                navigator.orbit(Self.viewFraction(translation, since: gestures.orbitTranslation, viewHeight: viewHeight))
                gestures.orbitTranslation = translation
            },
            onOrbitEnded: {
                gestures.orbitTranslation = .zero
                navigator.setGesture(.orbit, isActive: false)
            },
            onMagnify: { magnification in
                navigator.setGesture(.magnify, isActive: true)
                navigator.magnify(by: magnification / gestures.magnification)
                gestures.magnification = magnification
            },
            onMagnifyEnded: {
                gestures.magnification = 1
                navigator.setGesture(.magnify, isActive: false)
            },
            onRotate: { rotation in
                navigator.setGesture(.rotate, isActive: true)
                navigator.rotate(by: Float((rotation - gestures.rotation).radians))
                gestures.rotation = rotation
            },
            onRotateEnded: {
                gestures.rotation = .zero
                navigator.setGesture(.rotate, isActive: false)
            }
        )
    }

    private static func viewFraction(_ translation: CGSize, since previous: CGSize, viewHeight: CGFloat) -> CGSize {
        guard viewHeight > 0 else {
            return .zero
        }
        return CGSize(width: (translation.width - previous.width) / viewHeight, height: (translation.height - previous.height) / viewHeight)
    }
}

// RTS movement for a pose binding, with a navigator it owns.
public struct RTSPoseModifier: ViewModifier {
    @Binding
    var pose: RTSCameraPose

    let settings: RTSMovementSettings

    @State
    private var navigator = RTSNavigator()

    @State
    private var hasSeededHome = false

    public init(pose: Binding<RTSCameraPose>, settings: RTSMovementSettings = .init()) {
        self._pose = pose
        self.settings = settings
    }

    public func body(content: Content) -> some View {
        content
            .modifier(RTSMovementModifier(navigator: navigator))
            .onChange(of: settings, initial: true) {
                navigator.settings = settings
            }
            .onChange(of: pose, initial: true) {
                if !hasSeededHome {
                    navigator.homePose = pose
                    hasSeededHome = true
                }
                if pose != navigator.pose {
                    navigator.pose = pose
                }
            }
            .onChange(of: navigator.pose) {
                pose = navigator.pose
            }
    }
}

private struct RTSGestures: ViewModifier {
    let onPan: (CGSize) -> Void
    let onPanEnded: () -> Void
    let onOrbit: (CGSize) -> Void
    let onOrbitEnded: () -> Void
    let onMagnify: (Double) -> Void
    let onMagnifyEnded: () -> Void
    let onRotate: (Angle) -> Void
    let onRotateEnded: () -> Void

    func body(content: Content) -> some View {
        content
            .modifier(CoreDragModifier(modifiers: [], momentum: true, touchCount: 1, onChanged: onPan, onEnded: onPanEnded))
            .modifier(CoreDragModifier(modifiers: .option, momentum: true, touchCount: 2, onChanged: onOrbit, onEnded: onOrbitEnded))
            .modifier(CoreMagnifyModifier(momentum: true, onChanged: onMagnify, onEnded: onMagnifyEnded))
            .modifier(CoreRotateModifier(momentum: true, onChanged: onRotate, onEnded: onRotateEnded))
    }
}

public extension View {
    // Settings, input and pose live on the navigator.
    func rtsMovement(_ navigator: RTSNavigator, updatesAutomatically: Bool = true) -> some View {
        modifier(RTSMovementModifier(navigator: navigator, updatesAutomatically: updatesAutomatically))
    }

    func rtsMovement(pose: Binding<RTSCameraPose>, settings: RTSMovementSettings = .init()) -> some View {
        modifier(RTSPoseModifier(pose: pose, settings: settings))
    }
}
