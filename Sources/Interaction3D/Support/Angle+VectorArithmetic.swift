import SwiftUI

extension Angle: @retroactive VectorArithmetic {
    public static var zero: Angle {
        .radians(0)
    }

    public static func + (lhs: Angle, rhs: Angle) -> Angle {
        .radians(lhs.radians + rhs.radians)
    }

    public static func - (lhs: Angle, rhs: Angle) -> Angle {
        .radians(lhs.radians - rhs.radians)
    }

    public static func += (lhs: inout Angle, rhs: Angle) {
        lhs = lhs + rhs
    }

    public static func -= (lhs: inout Angle, rhs: Angle) {
        lhs = lhs - rhs
    }

    public mutating func scale(by rhs: Double) {
        self = .radians(radians * rhs)
    }

    public var magnitudeSquared: Double {
        radians * radians
    }
}
