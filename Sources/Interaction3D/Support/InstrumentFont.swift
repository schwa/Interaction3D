import SwiftUI

extension Font {
    // Instrument text is drawn at fixed positions inside dials, so it follows Dynamic Type only up to
    // maximumInstrumentTextScale; larger sizes would overlap the dial graphics. Smaller sizes are not reduced.
    static let maximumInstrumentTextScale: CGFloat = 1.4

    static func instrument(scale: CGFloat, size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        .system(size: size * min(max(scale, 1), maximumInstrumentTextScale), weight: weight, design: design)
    }
}
