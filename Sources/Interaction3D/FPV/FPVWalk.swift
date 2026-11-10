import simd

// Walk mode for FPVMovementController. Off when FPVMovementSettings.walk is nil.
public struct FPVWalkSettings: Equatable, Sendable {
    // Downward acceleration. Zero turns gravity off: the camera then follows the ground and can't jump.
    public var gravity: Float
    // Eye height above the ground from FPVMovementHooks.groundHeight.
    public var eyeHeight: Float
    // Upward speed at the start of a jump.
    public var jumpSpeed: Float
    // How fast the eye eases up to higher ground, per second. Lower ground is reached by falling (or easing, without gravity).
    public var groundFollowRate: Float
    // Steps up higher than this are blocked while on the ground. nil allows any step.
    public var maxStepUp: Float?
    // Double-tap jump toggles flying (Minecraft-style). Needs gravity.
    public var isFlightToggleEnabled: Bool
    public var doubleTapInterval: Float

    public init(
        gravity: Float = 9.8,
        eyeHeight: Float = 1.6,
        jumpSpeed: Float = 5,
        groundFollowRate: Float = 8,
        maxStepUp: Float? = nil,
        isFlightToggleEnabled: Bool = false,
        doubleTapInterval: Float = 0.3
    ) {
        self.gravity = gravity
        self.eyeHeight = eyeHeight
        self.jumpSpeed = jumpSpeed
        self.groundFollowRate = groundFollowRate
        self.maxStepUp = maxStepUp
        self.isFlightToggleEnabled = isFlightToggleEnabled
        self.doubleTapInterval = doubleTapInterval
    }
}

public struct FPVMotionState: Equatable, Sendable {
    public var isOnGround = false
    public var isFlying = false
    public var verticalVelocity: Float = 0
    // Total horizontal distance moved on the ground. Useful for head bob and footsteps.
    public var distanceWalked: Float = 0

    public init() {
        // Defaults only.
    }
}

// App-supplied callbacks that shape FPV movement. All are optional.
public struct FPVMovementHooks {
    // Ground height under the eye position, or nil for no ground. Used only in walk mode.
    public var groundHeight: (@MainActor (SIMD3<Float>) -> Float?)?
    // Returns false to block a move of the eye. Blocked moves slide along the obstacle when possible.
    public var canMove: (@MainActor (_ from: SIMD3<Float>, _ to: SIMD3<Float>) -> Bool)?
    // Last change to the camera matrix, for example head bob.
    public var adjustCamera: (@MainActor (simd_float4x4, FPVMotionState) -> simd_float4x4)?

    public init(
        groundHeight: (@MainActor (SIMD3<Float>) -> Float?)? = nil,
        canMove: (@MainActor (_ from: SIMD3<Float>, _ to: SIMD3<Float>) -> Bool)? = nil,
        adjustCamera: (@MainActor (simd_float4x4, FPVMotionState) -> simd_float4x4)? = nil
    ) {
        self.groundHeight = groundHeight
        self.canMove = canMove
        self.adjustCamera = adjustCamera
    }
}

// The full step first, then with axes dropped, so blocked moves slide along walls.
func slideCandidates(for delta: SIMD3<Float>) -> [SIMD3<Float>] {
    let masks: [SIMD3<Float>] = [[1, 1, 1], [1, 1, 0], [0, 1, 1], [1, 0, 1], [1, 0, 0], [0, 0, 1], [0, 1, 0]]
    var result: [SIMD3<Float>] = []
    for mask in masks {
        let candidate = delta * mask
        if candidate != .zero, !result.contains(candidate) {
            result.append(candidate)
        }
    }
    return result
}
