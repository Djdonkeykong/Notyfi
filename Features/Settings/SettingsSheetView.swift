import SwiftUI

struct SettingsSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: SettingsViewModel
    @State private var isClearLogConfirmationPresented = false

    var body: some View {
        ZStack {
            NotyfiBackgroundView()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    HStack(alignment: .top) {
                        Text("Settings".notyfiLocalized)
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
                                        .fill(.clear)
                                        .glassCircle(diameter: 38)
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
                            SettingsValueRow(icon: "envelope", title: "Email", value: "notyfi@icloud.com")
                        }
                    }

                    SectionHeader(title: "Preferences")
                    SettingsCard {
                        VStack(spacing: 0) {
                            SettingsValueRow(
                                icon: "banknote",
                                title: "Currency",
                                value: viewModel.automaticCurrency
                                    ? String(format: "Auto currency format".notyfiLocalized, viewModel.currencyCode)
                                    : viewModel.currencyCode
                            )
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
                            SettingsValueRow(
                                icon: "wand.and.stars",
                                title: "AI Parsing",
                                value: "Always on".notyfiLocalized
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
                            SettingsValueRow(
                                icon: "server.rack",
                                title: "Connection",
                                value: viewModel.syncEnabled
                                    ? "Supabase placeholder".notyfiLocalized
                                    : "Local only".notyfiLocalized
                            )
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

                    Text("Version 1.0".notyfiLocalized)
                        .font(.notyfi(.footnote))
                        .foregroundStyle(NotyfiTheme.tertiaryText)
                        .padding(.bottom, 8)
                }
                .padding(.horizontal, 20)
                .safeAreaPadding(.top, 14)
                .padding(.bottom, 28)
            }
        }
        .confirmationDialog(
            "Clear your entire log?".notyfiLocalized,
            isPresented: $isClearLogConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Clear Log".notyfiLocalized, role: .destructive) {
                viewModel.clearLog()
                dismiss()
            }

            Button("Cancel".notyfiLocalized, role: .cancel) {}
        } message: {
            Text("This removes every saved entry from Notyfi.".notyfiLocalized)
        }
    }
}

private struct SettingsCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .glassPanel(cornerRadius: 26, tintOpacity: 1)
    }
}

private struct SettingsValueRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundStyle(NotyfiTheme.secondaryText)
                .frame(width: 18)

            Text(title.notyfiLocalized)
                .font(.notyfi(.body))
                .foregroundStyle(.primary.opacity(0.82))

            Spacer()

            Text(value)
                .font(.notyfi(.subheadline))
                .foregroundStyle(NotyfiTheme.secondaryText)
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
                .foregroundStyle(NotyfiTheme.secondaryText)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 4) {
                Text(title.notyfiLocalized)
                    .font(.notyfi(.body))
                    .foregroundStyle(.primary.opacity(0.82))

                Text(subtitle.notyfiLocalized)
                    .font(.notyfi(.caption))
                    .foregroundStyle(NotyfiTheme.secondaryText)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(NotyfiTheme.brandBlue)
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
                .foregroundStyle(NotyfiTheme.secondaryText)
                .frame(width: 18)

            Text(title.notyfiLocalized)
                .font(.notyfi(.body))
                .foregroundStyle(.primary.opacity(0.82))

            Spacer()

            Picker(title.notyfiLocalized, selection: $selection) {
                ForEach(SettingsViewModel.AppearanceMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .tint(NotyfiTheme.brandBlue)
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
                    .foregroundStyle(isDestructive ? .red.opacity(0.75) : NotyfiTheme.brandBlue.opacity(0.9))
                    .frame(width: 18)

                Text(title.notyfiLocalized)
                    .font(.notyfi(.body))
                    .foregroundStyle(isDestructive ? .red.opacity(0.78) : .primary.opacity(0.82))

                Spacer()

                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(NotyfiTheme.tertiaryText)
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
