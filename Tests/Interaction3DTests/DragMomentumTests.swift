import CoreGraphics
@testable import Interaction3D
import Testing

@Test func axisLockKeepsDominantAxis() {
    #expect(axisLocked(CGSize(width: 30, height: 10)) == CGSize(width: 30, height: 0))
    #expect(axisLocked(CGSize(width: -5, height: 20)) == CGSize(width: 0, height: 20))
}

@Test func coastsOnlyAfterRecentMovementPastThreshold() {
    let moving = CGSize(width: 100, height: 0)
    let flick = CGSize(width: 160, height: 0)
    #expect(shouldCoast(translation: moving, predicted: flick, idle: .milliseconds(50), maxDelay: .milliseconds(200)))
    // Held still before release.
    #expect(!shouldCoast(translation: moving, predicted: flick, idle: .milliseconds(300), maxDelay: .milliseconds(200)))
    // No delay limit.
    #expect(shouldCoast(translation: moving, predicted: flick, idle: .seconds(5), maxDelay: nil))
    // Predicted end too close.
    #expect(!shouldCoast(translation: moving, predicted: CGSize(width: 105, height: 0), idle: .zero, maxDelay: nil))
}
