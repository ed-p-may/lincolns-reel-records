import SwiftUI

struct ProfileAvatar: View {
    let url: URL?
    let size: CGFloat

    var body: some View {
        LocalPhotoImage(
            url: url,
            maximumPixelSize: Int(size * 3),
            contentMode: .fill,
            placeholder: placeholder
        )
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.28))
        .overlay {
            RoundedRectangle(cornerRadius: size * 0.28)
                .stroke(ReelTheme.accent, lineWidth: 2)
        }
        .accessibilityLabel(url == nil ? "Default profile avatar" : "Profile avatar")
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(
                colors: [ReelTheme.accent.opacity(0.30), ReelTheme.raisedSurface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "person.fill")
                .font(.system(size: size * 0.44, weight: .bold))
                .foregroundStyle(ReelTheme.accentHighlight)
        }
    }
}

struct ProfileStatTile: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 5) {
            Text(value)
                .font(ReelFont.display(21, weight: .heavy))
                .foregroundStyle(ReelTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Text(label)
                .font(ReelFont.metadata(.caption2, weight: .bold))
                .foregroundStyle(ReelTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 76)
        .padding(.horizontal, 8)
        .background(ReelTheme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).stroke(ReelTheme.border) }
    }
}

struct ProfileCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title.uppercased())
                .font(ReelFont.metadata(.caption2, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(ReelTheme.tertiaryText)
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ReelTheme.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(ReelTheme.border) }
    }
}

struct ProfileSpeciesBar: View {
    let stat: DashboardLabelStat
    let maximum: Int

    var body: some View {
        VStack(spacing: 7) {
            HStack {
                Text(stat.label)
                    .font(ReelFont.body(.subheadline, weight: .semibold))
                Spacer()
                Text(stat.count.formatted())
                    .font(ReelFont.metadata(.caption, weight: .bold))
                    .foregroundStyle(ReelTheme.secondaryText)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(ReelTheme.raisedSurface)
                    Capsule().fill(ReelTheme.accent)
                        .frame(width: proxy.size.width * CGFloat(stat.count) / CGFloat(max(maximum, 1)))
                }
            }
            .frame(height: 7)
        }
    }
}

struct ProfileRow: View {
    let icon: String
    let title: String
    let detail: String?
    let value: String?
    var showsChevron = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 30, height: 30)
                .foregroundStyle(ReelTheme.accentHighlight)
                .background(ReelTheme.raisedSurface, in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ReelFont.body(.body, weight: .semibold))
                    .foregroundStyle(ReelTheme.primaryText)
                    .lineLimit(2)
                if let detail {
                    Text(detail)
                        .font(ReelFont.body(.caption))
                        .foregroundStyle(ReelTheme.secondaryText)
                }
            }
            Spacer(minLength: 8)
            if let value {
                Text(value)
                    .font(ReelFont.metadata(.caption, weight: .bold))
                    .foregroundStyle(ReelTheme.secondaryText)
            }
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(ReelTheme.tertiaryText)
            }
        }
        .contentShape(Rectangle())
    }
}
