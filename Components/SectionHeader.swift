import SwiftUI

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title.notelyLocalized)
            .font(.notely(.footnote, weight: .medium))
            .foregroundStyle(NotelyTheme.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
    }
}
