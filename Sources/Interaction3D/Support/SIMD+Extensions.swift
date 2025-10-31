import simd
import SwiftUI

public extension Float {
    var double: Double {
        get {
            Double(self)
        }
        set {
            self = Float(newValue)
        }
    }
}
