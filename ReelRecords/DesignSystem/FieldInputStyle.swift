import SwiftUI

struct FieldInputStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(ReelFont.body())
            .foregroundStyle(ReelTheme.primaryText)
            .padding(.horizontal, 16)
            .frame(minHeight: 54)
            .background(ReelTheme.raisedSurface, in: RoundedRectangle(cornerRadius: 15))
            .overlay {
                RoundedRectangle(cornerRadius: 15)
                    .stroke(ReelTheme.border)
            }
    }
}

extension View {
    func fieldInputStyle() -> some View {
        modifier(FieldInputStyle())
    }
}
