import SwiftUI

struct DetailMetricCard: View {
    let label: String
    let value: String?
    let systemImage: String
    let prominent: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(label.uppercased(), systemImage: systemImage)
                .font(ReelFont.metadata(.caption2, weight: .bold))
                .foregroundStyle(prominent ? ReelTheme.accentHighlight : ReelTheme.secondaryText)
            Text(value ?? "Not recorded")
                .reelDisplayFont(value == nil ? 15 : 25, weight: .heavy)
                .foregroundStyle(value == nil ? ReelTheme.tertiaryText : textColor)
                .minimumScaleFactor(0.72)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .padding(16)
        .background(prominent ? ReelTheme.accent.opacity(0.13) : ReelTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(prominent ? ReelTheme.accent.opacity(0.25) : ReelTheme.border)
        }
    }

    private var textColor: Color {
        prominent ? .white : ReelTheme.primaryText
    }
}

struct DetailTile: View {
    let label: String
    let value: String?
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(label, systemImage: systemImage)
                .font(ReelFont.body(.caption, weight: .semibold))
                .foregroundStyle(ReelTheme.tertiaryText)
            Text(value ?? "Not recorded")
                .font(ReelFont.body(.subheadline, weight: .semibold))
                .foregroundStyle(value == nil ? ReelTheme.tertiaryText : ReelTheme.primaryText)
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .topLeading)
        .padding(13)
        .background(ReelTheme.surface, in: RoundedRectangle(cornerRadius: 15))
    }
}

struct DetailSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .reelDisplayFont(17)
                .foregroundStyle(ReelTheme.primaryText)
            content
        }
        .padding(.horizontal, 20)
    }
}
