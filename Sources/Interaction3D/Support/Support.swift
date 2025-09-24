import simd

internal extension SIMD {
    var scalars: [Scalar] {
        get {
            (0..<scalarCount).map { self[$0] }
        }
        set {
            assert(newValue.count <= scalarCount, "New value has too many scalars")
            for i in 0..<Swift.min(scalarCount, newValue.count) {
                self[i] = newValue[i]
            }
        }
    }
}
