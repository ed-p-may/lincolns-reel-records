import SwiftUI

struct PrimaryButton: View {
    let title: String
    var systemImage: String?
    var isWorking = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isWorking {
                    ProgressView()
                        .tint(ReelTheme.accentInk)
                } else if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(ReelFont.display(17, weight: .heavy))
            .foregroundStyle(ReelTheme.accentInk)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(ReelTheme.accent, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: ReelTheme.accent.opacity(0.3), radius: 18, y: 8)
        }
        .buttonStyle(.plain)
        .disabled(isWorking)
        .accessibilityValue(isWorking ? "Working" : "")
    }
}
