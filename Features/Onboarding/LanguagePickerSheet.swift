import SwiftUI

struct LanguagePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var languageManager: LanguageManager

    var body: some View {
        ZStack {
            NotyfiTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    header

                    languageCard
                }
                .padding(.horizontal, 20)
                .safeAreaPadding(.top, 14)
                .padding(.bottom, 28)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            Text("Language".notyfiLocalized)
                .font(.notyfi(.title3, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.84))

            Spacer()

            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(NotyfiTheme.secondaryText)
                    .frame(width: 38, height: 38)
                    .background {
                        Circle()
                            .fill(NotyfiTheme.elevatedSurface)
                    }
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 22)
    }

    private var languageCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(NotyfiLanguage.allCases.enumerated()), id: \.element.id) { index, language in
                if index > 0 {
                    Divider()
                }
                languageRow(language)
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(NotyfiTheme.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(NotyfiTheme.surfaceBorder, lineWidth: 1)
                }
                .shadow(color: NotyfiTheme.shadow, radius: 16, x: 0, y: 8)
        }
    }

    private func languageRow(_ language: NotyfiLanguage) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            languageManager.set(language)
            dismiss()
        } label: {
            HStack(spacing: 14) {
                if language == .system {
                    Image(systemName: "globe")
                        .foregroundStyle(NotyfiTheme.secondaryText)
                        .frame(width: 26)
                } else {
                    Text(language.flag)
                        .font(.system(size: 22))
                        .frame(width: 26)
                }

                Text(language.displayName)
                    .font(.notyfi(.body))
                    .foregroundStyle(.primary.opacity(0.82))

                Spacer()

                if language == languageManager.current {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(NotyfiTheme.brandBlue)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    LanguagePickerSheet()
        .environmentObject(LanguageManager())
}
