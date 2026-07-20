import SwiftUI
import UIKit

struct UnitInput: View {
    let title: String
    let unit: String
    @Binding var text: String
    let keyboardType: UIKeyboardType
    let identifier: String

    init(
        _ title: String,
        unit: String,
        text: Binding<String>,
        keyboardType: UIKeyboardType,
        identifier: String
    ) {
        self.title = title
        self.unit = unit
        _text = text
        self.keyboardType = keyboardType
        self.identifier = identifier
    }

    var body: some View {
        HStack(spacing: 8) {
            TextField(title, text: $text)
                .keyboardType(keyboardType)
                .accessibilityIdentifier(identifier)
            Text(unit)
                .font(ReelFont.metadata(.caption))
                .foregroundStyle(ReelTheme.secondaryText)
        }
        .fieldInputStyle()
    }
}
