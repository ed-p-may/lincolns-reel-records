import SwiftUI

struct SelectionChip: View {
    enum Sizing {
        case compact
        case regular
        case fillWidth
    }

    let title: String
    let isSelected: Bool
    var sizing: Sizing = .regular
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(font)
                .lineLimit(1)
                .padding(.horizontal, horizontalPadding)
                .frame(maxWidth: sizing == .fillWidth ? .infinity : nil, minHeight: minHeight)
                .background(isSelected ? ReelTheme.accent : ReelTheme.raisedSurface, in: Capsule())
                .foregroundStyle(isSelected ? ReelTheme.accentInk : ReelTheme.secondaryText)
                .overlay {
                    Capsule().stroke(isSelected ? ReelTheme.accent : ReelTheme.border, lineWidth: 1)
                }
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    private var font: Font {
        sizing == .fillWidth
            ? ReelFont.body(.subheadline, weight: .semibold)
            : ReelFont.body(.caption, weight: .bold)
    }

    private var horizontalPadding: CGFloat {
        switch sizing {
        case .compact: 11
        case .regular: 14
        case .fillWidth: 12
        }
    }

    private var minHeight: CGFloat {
        switch sizing {
        case .compact: 34
        case .regular: 38
        case .fillWidth: 44
        }
    }
}
