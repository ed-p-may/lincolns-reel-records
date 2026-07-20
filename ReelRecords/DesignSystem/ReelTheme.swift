import SwiftUI

enum ReelTheme {
    static let page = Color(red: 6 / 255, green: 7 / 255, blue: 6 / 255)
    static let background = Color(red: 10 / 255, green: 12 / 255, blue: 11 / 255)
    static let surface = Color(red: 18 / 255, green: 21 / 255, blue: 18 / 255)
    static let raisedSurface = Color(red: 24 / 255, green: 28 / 255, blue: 24 / 255)
    static let accent = Color(red: 55 / 255, green: 226 / 255, blue: 123 / 255)
    static let accentHighlight = Color(red: 95 / 255, green: 242 / 255, blue: 155 / 255)
    static let accentInk = Color(red: 4 / 255, green: 34 / 255, blue: 15 / 255)
    static let primaryText = Color(red: 241 / 255, green: 244 / 255, blue: 240 / 255)
    static let secondaryText = Color(red: 154 / 255, green: 163 / 255, blue: 156 / 255)
    static let tertiaryText = Color(red: 128 / 255, green: 136 / 255, blue: 129 / 255)
    static let danger = Color(red: 1, green: 138 / 255, blue: 138 / 255)
    static let border = Color.white.opacity(0.07)
    static let strongBorder = Color.white.opacity(0.13)
}

enum ReelFont {
    static func body(_ style: Font.TextStyle = .body, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .rounded, weight: weight)
    }

    static func metadata(_ style: Font.TextStyle = .caption, weight: Font.Weight = .semibold) -> Font {
        .system(style, design: .monospaced, weight: weight)
    }
}

private struct ReelDisplayFontModifier: ViewModifier {
    @ScaledMetric private var scaledSize: CGFloat
    private let weight: Font.Weight

    init(size: CGFloat, weight: Font.Weight) {
        let relativeStyle: Font.TextStyle = if size >= 32 {
            .largeTitle
        } else if size >= 24 {
            .title
        } else if size >= 20 {
            .title2
        } else {
            .headline
        }
        _scaledSize = ScaledMetric(wrappedValue: size, relativeTo: relativeStyle)
        self.weight = weight
    }

    func body(content: Content) -> some View {
        content.font(.system(size: scaledSize, weight: weight, design: .rounded))
    }
}

extension View {
    func reelDisplayFont(_ size: CGFloat, weight: Font.Weight = .bold) -> some View {
        modifier(ReelDisplayFontModifier(size: size, weight: weight))
    }
}
