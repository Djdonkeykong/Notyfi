import SwiftUI

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title.notyfiLocalized)
            .font(.notyfi(.footnote, weight: .medium))
            .foregroundStyle(NotyfiTheme.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
    }
}
