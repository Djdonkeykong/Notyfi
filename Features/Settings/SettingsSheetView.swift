import SwiftUI

struct SettingsSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: SettingsViewModel
    @State private var isClearLogConfirmationPresented = false

    var body: some View {
        ZStack {
            NotelyTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    HStack(alignment: .top) {
                        Text("Settings")
                            .font(.notely(.title3, weight: .semibold))
                            .foregroundStyle(.primary.opacity(0.84))

                        Spacer()

                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(NotelyTheme.secondaryText)
                                .frame(width: 38, height: 38)
                                .background {
                                    Circle()
                                        .fill(NotelyTheme.elevatedSurface)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 22)

                    SectionHeader(title: "Profile")
                    SettingsCard {
                        VStack(spacing: 0) {
                            SettingsValueRow(icon: "person.crop.circle", title: "Name", value: "Ole Christian Michelsen")
                            Divider()
                            SettingsValueRow(icon: "envelope", title: "Email", value: "notely@icloud.com")
                        }
                    }

                    SectionHeader(title: "Preferences")
                    SettingsCard {
                        VStack(spacing: 0) {
                            SettingsValueRow(icon: "banknote", title: "Currency", value: viewModel.automaticCurrency ? "Auto (NOK)" : viewModel.currencyCode)
                            Divider()
                            SettingsToggleRow(
                                icon: "bell.badge",
                                title: "Notifications",
                                subtitle: "Quiet reminders when you want them",
                                isOn: $viewModel.notificationsEnabled
                            )
                            Divider()
                            SettingsPickerRow(
                                icon: "circle.lefthalf.filled",
                                title: "Appearance",
                                selection: $viewModel.appearanceMode
                            )
                        }
                    }

                    SectionHeader(title: "AI Parsing")
                    SettingsCard {
                        VStack(spacing: 0) {
                            SettingsToggleRow(
                                icon: "wand.and.stars",
                                title: "AI Parsing",
                                subtitle: "Interpret natural notes quietly in the background",
                                isOn: $viewModel.aiParsingEnabled
                            )
                            Divider()
                            SettingsToggleRow(
                                icon: "checklist",
                                title: "Gentle Review Mode",
                                subtitle: "Keep uncertain entries easy to confirm later",
                                isOn: $viewModel.gentleReviewMode
                            )
                        }
                    }

                    SectionHeader(title: "Sync / Supabase")
                    SettingsCard {
                        VStack(spacing: 0) {
                            SettingsToggleRow(
                                icon: "arrow.triangle.2.circlepath",
                                title: "Sync",
                                subtitle: "Stay local for now, with cloud sync ready later",
                                isOn: $viewModel.syncEnabled
                            )
                            Divider()
                            SettingsValueRow(icon: "server.rack", title: "Connection", value: viewModel.syncEnabled ? "Supabase placeholder" : "Local only")
                        }
                    }

                    SectionHeader(title: "Support & Data")
                    SettingsCard {
                        VStack(spacing: 0) {
                            SettingsActionRow(icon: "square.and.arrow.up", title: "Export Data")
                            Divider()
                            SettingsActionRow(
                                icon: "trash",
                                title: "Clear Log",
                                isDestructive: true,
                                showsChevron: false,
                                action: {
                                    isClearLogConfirmationPresented = true
                                }
                            )
                            Divider()
                            SettingsActionRow(icon: "lock.shield", title: "Privacy")
                            Divider()
                            SettingsActionRow(icon: "bubble.left.and.text.bubble.right", title: "Contact Support")
                            Divider()
                            SettingsActionRow(icon: "rectangle.portrait.and.arrow.right", title: "Sign Out", isDestructive: true)
                        }
                    }

                    Text("Version 1.0")
                        .font(.notely(.footnote))
                        .foregroundStyle(NotelyTheme.tertiaryText)
                        .padding(.bottom, 8)
                }
                .padding(.horizontal, 20)
                .safeAreaPadding(.top, 14)
                .padding(.bottom, 28)
            }
        }
        .confirmationDialog(
            "Clear your entire log?",
            isPresented: $isClearLogConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Clear Log", role: .destructive) {
                viewModel.clearLog()
                dismiss()
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes every saved entry from Notely.")
        }
    }
}

private struct SettingsCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .background {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(NotelyTheme.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(NotelyTheme.surfaceBorder, lineWidth: 1)
                    }
                    .shadow(color: NotelyTheme.shadow, radius: 16, x: 0, y: 8)
            }
    }
}

private struct SettingsValueRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundStyle(NotelyTheme.secondaryText)
                .frame(width: 18)

            Text(title)
                .font(.notely(.body))
                .foregroundStyle(.primary.opacity(0.82))

            Spacer()

            Text(value)
                .font(.notely(.subheadline))
                .foregroundStyle(NotelyTheme.secondaryText)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
    }
}

private struct SettingsToggleRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: icon)
                .foregroundStyle(NotelyTheme.secondaryText)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.notely(.body))
                    .foregroundStyle(.primary.opacity(0.82))

                Text(subtitle)
                    .font(.notely(.caption))
                    .foregroundStyle(NotelyTheme.secondaryText)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(NotelyTheme.reviewTint)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
    }
}

private struct SettingsPickerRow: View {
    let icon: String
    let title: String
    @Binding var selection: SettingsViewModel.AppearanceMode

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundStyle(NotelyTheme.secondaryText)
                .frame(width: 18)

            Text(title)
                .font(.notely(.body))
                .foregroundStyle(.primary.opacity(0.82))

            Spacer()

            Picker(title, selection: $selection) {
                ForEach(SettingsViewModel.AppearanceMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .tint(NotelyTheme.secondaryText)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
    }
}

private struct SettingsActionRow: View {
    let icon: String
    let title: String
    var isDestructive = false
    var showsChevron = true
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .foregroundStyle(isDestructive ? .red.opacity(0.75) : .blue.opacity(0.72))
                    .frame(width: 18)

                Text(title)
                    .font(.notely(.body))
                    .foregroundStyle(isDestructive ? .red.opacity(0.78) : .primary.opacity(0.82))

                Spacer()

                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(NotelyTheme.tertiaryText)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SettingsSheetView(viewModel: SettingsViewModel(store: ExpenseJournalStore(previewMode: true)))
}
