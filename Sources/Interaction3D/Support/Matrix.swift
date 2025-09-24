import simd

public protocol Matrix {
    associatedtype Scalar

    var width: Int { get }
    var height: Int { get }

    subscript(row: Int, column: Int) -> Scalar { get set }
}

// MARK: -

extension float4x4: Matrix {
    public var width: Int { 4 }
    public var height: Int { 4 }

    public subscript(row: Int, column: Int) -> Float {
        get {
            // simd matrices are column-major: self[column][row]
            self[column][row]
        }
        set {
            // simd matrices are column-major: self[column][row]
            self[column][row] = newValue
        }
    }
}
