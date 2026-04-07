import SwiftUI

struct SettingsSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: SettingsViewModel
    @State private var isClearLogConfirmationPresented = false

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

                            SettingsValueRow(
                                icon: "banknote",
                                title: "Currency",
                                value: viewModel.currencyDisplayName
                            )

                            Divider()

                            SettingsValueRow(
                                icon: "circle.lefthalf.filled",
                                title: "Appearance",
                                value: viewModel.appearanceMode.title
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
    SettingsSheetView(viewModel: SettingsViewModel(store: ExpenseJournalStore(previewMode: true)))
}
