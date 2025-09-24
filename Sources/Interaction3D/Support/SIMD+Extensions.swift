import simd
import SwiftUI

internal extension Float {
    var double: Double {
        get { Double(self) }
        set { self = Float(newValue) }
    }
}
