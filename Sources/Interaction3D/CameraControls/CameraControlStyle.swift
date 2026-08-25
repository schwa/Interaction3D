import SwiftUI

public struct CameraControlStyle: Sendable {
    public var fieldSpacing: CGFloat
    public var fieldCornerRadius: CGFloat
    public var labelWidth: CGFloat
    public var valueWidth: CGFloat

    public init(fieldSpacing: CGFloat = 8, fieldCornerRadius: CGFloat = 6, labelWidth: CGFloat = 18, valueWidth: CGFloat = 72) {
        self.fieldSpacing = fieldSpacing
        self.fieldCornerRadius = fieldCornerRadius
        self.labelWidth = labelWidth
        self.valueWidth = valueWidth
    }

    public static let standard = CameraControlStyle()
    public static let compact = CameraControlStyle(fieldSpacing: 4, fieldCornerRadius: 5, labelWidth: 14, valueWidth: 64)
}

public extension EnvironmentValues {
    @Entry var cameraControlStyle = CameraControlStyle.standard
}

public extension View {
    func cameraControlStyle(_ style: CameraControlStyle) -> some View {
        environment(\.cameraControlStyle, style)
    }
}
