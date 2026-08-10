import SwiftUI

struct CatchDateEditor: View {
    @Binding var caughtAt: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AddCatchFieldLabel("Caught")
            DatePicker(
                "Date and time",
                selection: $caughtAt,
                displayedComponents: [.date, .hourAndMinute]
            )
            .tint(ReelTheme.accent)
            .padding(14)
            .background(ReelTheme.surface, in: RoundedRectangle(cornerRadius: 18))
            .accessibilityIdentifier("add.caught-at")
        }
    }
}

struct CatchDetailsEditor: View {
    @Binding var rodReel: String
    @Binding var notes: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AddCatchFieldLabel("Details")
            TextField("Rod and reel", text: $rodReel)
                .fieldInputStyle()
                .accessibilityIdentifier("add.rod-reel")
            TextField("Field notes", text: $notes, axis: .vertical)
                .lineLimit(4 ... 8)
                .fieldInputStyle()
                .accessibilityIdentifier("add.notes")
        }
    }
}

struct CatchDispositionEditor: View {
    @Binding var released: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AddCatchFieldLabel("Disposition")
            Picker("Disposition", selection: $released) {
                Text("Released").tag(true)
                Text("Kept").tag(false)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("add.released")
        }
    }
}

struct AddCatchFieldLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text.uppercased())
            .font(ReelFont.metadata(.caption2, weight: .bold))
            .tracking(1)
            .foregroundStyle(ReelTheme.tertiaryText)
    }
}
