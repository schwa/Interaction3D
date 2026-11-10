import simd
import SwiftUI

extension Float {
    var double: Double {
        get {
            Double(self)
        }
        set {
            self = Float(newValue)
        }
    }
}
