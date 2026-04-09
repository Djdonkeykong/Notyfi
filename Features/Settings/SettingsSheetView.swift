import SwiftUI

struct SettingsSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject var authManager: AuthManager
    @State private var isClearLogConfirmationPresented = false
    @State private var isSignOutConfirmationPresented = false
    @State private var isDeleteAccountConfirmationPresented = false

    var body: some View {
        ZStack {
            NotyfiTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    header

                    SectionHeader(title: "Preferences")
                    SettingsCard {
                        VStack(spacing: 0) {
                            SettingsValueRow(
                                icon: "globe",
                                title: "Language",
                                value: "Follow system".notyfiLocalized
                            )

                            Divider()

                            CurrencyMenuRow(
                                icon: "banknote",
                                title: "Currency",
                                selection: $viewModel.currencyPreference,
                                onSelect: viewModel.setCurrencyPreference
                            )

                            Divider()

                            AppearanceMenuRow(
                                icon: "circle.lefthalf.filled",
                                title: "Appearance",
                                selection: $viewModel.appearanceMode,
                                onSelect: viewModel.setAppearanceMode
                            )

                            Divider()

                            SettingsToggleRow(
                                icon: "bell.badge",
                                title: "Daily reminder",
                                subtitle: viewModel.reminderSubtitle,
                                isOn: $viewModel.remindersEnabled,
                                onChange: { isOn in
                                    await viewModel.setRemindersEnabled(isOn)
                                }
                            )

                            if viewModel.remindersEnabled {
                                Divider()

                                ReminderTimeRow(
                                    icon: "clock",
                                    title: "Reminder time",
                                    selection: $viewModel.reminderTime,
                                    onChange: { nextDate in
                                        await viewModel.setReminderTime(nextDate)
                                    }
                                )
                            }
                        }
                    }

                    SectionHeader(title: "Data")
                    SettingsCard {
                        VStack(spacing: 0) {
                            SettingsValueRow(
                                icon: "wand.and.stars",
                                title: "AI parsing",
                                value: "Enabled".notyfiLocalized
                            )

                            Divider()

                            SettingsValueRow(
                                icon: "iphone.and.arrow.forward",
                                title: "Storage",
                                value: "This device".notyfiLocalized
                            )

                            Divider()

                            SettingsValueRow(
                                icon: "square.grid.2x2",
                                title: "Home widgets",
                                value: "Available".notyfiLocalized
                            )

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
                        }
                    }

                    SectionHeader(title: "Coming later")
                    SettingsCard {
                        VStack(spacing: 0) {
                            ComingSoonRow(
                                icon: "arrow.triangle.2.circlepath",
                                title: "Cloud sync",
                                detail: "Planned".notyfiLocalized
                            )

                            Divider()

                            ComingSoonRow(
                                icon: "bell.badge",
                                title: "Reminders",
                                detail: "Planned".notyfiLocalized
                            )

                            Divider()

                            ComingSoonRow(
                                icon: "lock.shield",
                                title: "Privacy lock",
                                detail: "Planned".notyfiLocalized
                            )

                            Divider()

                            ComingSoonRow(
                                icon: "square.and.arrow.up",
                                title: "Export data",
                                detail: "Planned".notyfiLocalized
                            )
                        }
                    }

                    SectionHeader(title: "Account")
                    SettingsCard {
                        VStack(spacing: 0) {
                            SettingsActionRow(
                                icon: "rectangle.portrait.and.arrow.right",
                                title: "Sign Out",
                                isDestructive: false,
                                showsChevron: false,
                                action: { isSignOutConfirmationPresented = true }
                            )

                            Divider()

                            SettingsActionRow(
                                icon: "person.crop.circle.badge.minus",
                                title: "Delete Account",
                                isDestructive: true,
                                showsChevron: false,
                                action: { isDeleteAccountConfirmationPresented = true }
                            )
                        }
                    }

                    SectionHeader(title: "About")
                    SettingsCard {
                        VStack(spacing: 0) {
                            SettingsValueRow(
                                icon: "shippingbox",
                                title: "Version",
                                value: viewModel.versionText
                            )

                            Divider()

                            SettingsValueRow(
                                icon: "checkmark.shield",
                                title: "Build",
                                value: "Journal-first".notyfiLocalized
                            )
                        }
                    }
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
        .confirmationDialog(
            "Sign out of Notyfi?".notyfiLocalized,
            isPresented: $isSignOutConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Sign Out".notyfiLocalized, role: .destructive) {
                authManager.signOut()
                dismiss()
            }
            Button("Cancel".notyfiLocalized, role: .cancel) {}
        }
        .confirmationDialog(
            "Delete your account?".notyfiLocalized,
            isPresented: $isDeleteAccountConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Delete Account".notyfiLocalized, role: .destructive) {
                Task {
                    await authManager.deleteAccount()
                    dismiss()
                }
            }
            Button("Cancel".notyfiLocalized, role: .cancel) {}
        } message: {
            Text("This permanently deletes your account and all data. This cannot be undone.".notyfiLocalized)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Settings".notyfiLocalized)
                    .font(.notyfi(.title3, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.84))

                Text("Keep things simple for now. More controls will arrive as the app grows.".notyfiLocalized)
                    .font(.notyfi(.footnote))
                    .foregroundStyle(NotyfiTheme.secondaryText)
            }

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
}

private struct AppearanceMenuRow: View {
    let icon: String
    let title: String
    @Binding var selection: NotyfiAppearanceMode
    let onSelect: (NotyfiAppearanceMode) -> Void

    var body: some View {
        Menu {
            ForEach(NotyfiAppearanceMode.allCases) { mode in
                Button {
                    onSelect(mode)
                } label: {
                    if mode == selection {
                        Label(mode.title, systemImage: "checkmark")
                    } else {
                        Text(mode.title)
                    }
                }
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .foregroundStyle(NotyfiTheme.secondaryText)
                    .frame(width: 18)

                Text(title.notyfiLocalized)
                    .font(.notyfi(.body))
                    .foregroundStyle(.primary.opacity(0.82))

                Spacer()

                Text(selection.title)
                    .font(.notyfi(.subheadline))
                    .foregroundStyle(NotyfiTheme.secondaryText)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(NotyfiTheme.tertiaryText)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct CurrencyMenuRow: View {
    let icon: String
    let title: String
    @Binding var selection: NotyfiCurrencyPreference
    let onSelect: (NotyfiCurrencyPreference) -> Void

    var body: some View {
        Menu {
            ForEach(NotyfiCurrencyPreference.allCases) { preference in
                Button {
                    onSelect(preference)
                } label: {
                    if preference == selection {
                        Label(preference.title, systemImage: "checkmark")
                    } else {
                        Text(preference.title)
                    }
                }
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .foregroundStyle(NotyfiTheme.secondaryText)
                    .frame(width: 18)

                Text(title.notyfiLocalized)
                    .font(.notyfi(.body))
                    .foregroundStyle(.primary.opacity(0.82))

                Spacer()

                Text(selection.title)
                    .font(.notyfi(.subheadline))
                    .foregroundStyle(NotyfiTheme.secondaryText)
                    .multilineTextAlignment(.trailing)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(NotyfiTheme.tertiaryText)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
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
}

private struct SettingsToggleRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    var onChange: ((Bool) async -> Void)? = nil

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
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(NotyfiTheme.brandBlue)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .onChange(of: isOn) { _, newValue in
            guard let onChange else {
                return
            }

            Task {
                await onChange(newValue)
            }
        }
    }
}

private struct ReminderTimeRow: View {
    let icon: String
    let title: String
    @Binding var selection: Date
    var onChange: ((Date) async -> Void)? = nil

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundStyle(NotyfiTheme.secondaryText)
                .frame(width: 18)

            Text(title.notyfiLocalized)
                .font(.notyfi(.body))
                .foregroundStyle(.primary.opacity(0.82))

            Spacer()

            DatePicker(
                title.notyfiLocalized,
                selection: $selection,
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.compact)
            .labelsHidden()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .onChange(of: selection) { _, newValue in
            guard let onChange else {
                return
            }

            Task {
                await onChange(newValue)
            }
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

private struct ComingSoonRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundStyle(NotyfiTheme.brandBlue.opacity(0.9))
                .frame(width: 18)

            Text(title.notyfiLocalized)
                .font(.notyfi(.body))
                .foregroundStyle(.primary.opacity(0.82))

            Spacer()

            Text(detail)
                .font(.notyfi(.caption, weight: .semibold))
                .foregroundStyle(NotyfiTheme.tertiaryText)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background {
                    Capsule()
                        .fill(NotyfiTheme.elevatedSurface)
                }
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
    SettingsSheetView(viewModel: SettingsViewModel(store: ExpenseJournalStore(previewMode: true)), authManager: AuthManager())
}
