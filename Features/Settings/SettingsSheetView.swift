import SwiftUI
import WebKit

struct SettingsSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var languageManager: LanguageManager
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject var authManager: AuthManager
    @AppStorage("notyfi.onboarding.complete") private var hasCompletedOnboarding = false
    @State private var isFeedbackPresented = false
    @State private var isLanguagePickerPresented = false
    @State private var isClearLogConfirmationPresented = false
    @State private var isSignOutConfirmationPresented = false
    @State private var isDeleteAccountConfirmationPresented = false
    @State private var pendingAccountAction: PendingAccountAction? = nil

    private enum PendingAccountAction {
        case signOut
        case deleteAccount
    }

    private var resolvedLanguage: NotyfiLanguage {
        if languageManager.current != .system { return languageManager.current }
        let code = Locale.preferredLanguages.first
            .flatMap { Locale(identifier: $0).language.languageCode?.identifier } ?? "en"
        return NotyfiLanguage(rawValue: code) ?? .english
    }

    private var hasAccountInfo: Bool {
        let hasName = !(authManager.userDisplayName?.isEmpty ?? true)
        let hasEmail = !(authManager.userEmail?.isEmpty ?? true)
        return hasName || hasEmail
    }

    private var isPerformingAccountAction: Bool {
        pendingAccountAction != nil
    }

    var body: some View {
        ZStack {
            NotyfiTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    header

                    if hasAccountInfo {
                        SectionHeader(title: "Account")
                        SettingsCard {
                            VStack(spacing: 0) {
                                if let name = authManager.userDisplayName, !name.isEmpty {
                                    SettingsValueRow(
                                        icon: "person",
                                        title: "Name",
                                        value: name
                                    )
                                    if let email = authManager.userEmail, !email.isEmpty {
                                        Divider()
                                    }
                                }
                                if let email = authManager.userEmail, !email.isEmpty {
                                    SettingsValueRow(
                                        icon: "envelope",
                                        title: "Email",
                                        value: email
                                    )
                                }
                            }
                        }
                    }

                    SectionHeader(title: "Preferences")
                    SettingsCard {
                        VStack(spacing: 0) {
                            CurrencyMenuRow(
                                icon: "banknote",
                                title: "Currency",
                                selection: $viewModel.currencyPreference,
                                onSelect: viewModel.setCurrencyPreference
                            )

                            Divider()

                            LanguageActionRow(
                                icon: "globe",
                                title: "Language",
                                currentLanguage: resolvedLanguage,
                                action: { isLanguagePickerPresented = true }
                            )

                            Divider()

                            AppearanceMenuRow(
                                icon: "circle.lefthalf.filled",
                                title: "Appearance",
                                selection: $viewModel.appearanceMode,
                                onSelect: viewModel.setAppearanceMode
                            )

                            Divider()

                            DictationLanguageMenuRow(
                                icon: "mic.fill",
                                title: "Dictation language",
                                selection: $viewModel.dictationLanguage,
                                onSelect: viewModel.setDictationLanguage
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

                    SettingsCard {
                        VStack(spacing: 0) {
                            SettingsActionRow(
                                icon: "star.fill",
                                title: "Give Feedback",
                                action: { isFeedbackPresented = true }
                            )
                        }
                    }

                    SettingsCard {
                        VStack(spacing: 0) {
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

                    Text("Notyfi \(viewModel.versionText)")
                        .font(.notyfi(.caption))
                        .foregroundStyle(NotyfiTheme.tertiaryText)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .safeAreaPadding(.top, 14)
                .padding(.bottom, 28)
            }
            .disabled(isPerformingAccountAction)

            if isPerformingAccountAction {
                accountActionOverlay
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
                Task {
                    pendingAccountAction = .signOut
                    await authManager.signOut()
                    pendingAccountAction = nil
                    dismiss()
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    hasCompletedOnboarding = false
                }
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
                    pendingAccountAction = .deleteAccount
                    await authManager.deleteAccount()
                    pendingAccountAction = nil
                    dismiss()
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    hasCompletedOnboarding = false
                }
            }
            Button("Cancel".notyfiLocalized, role: .cancel) {}
        } message: {
            Text("This permanently deletes your account and all data. This cannot be undone.".notyfiLocalized)
        }
        .sheet(isPresented: $isFeedbackPresented) {
            FeedbackSheetView(url: URL(string: "https://snaplook.app/")!)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(NotyfiTheme.background.opacity(0.98))
                .presentationCornerRadius(34)
        }
        .sheet(isPresented: $isLanguagePickerPresented) {
            LanguagePickerSheet()
                .environmentObject(languageManager)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(NotyfiTheme.background.opacity(0.98))
                .presentationCornerRadius(34)
        }
        .id(viewModel.appearanceMode.id)
        .preferredColorScheme(viewModel.appearanceMode.colorScheme)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Settings".notyfiLocalized)
                    .font(.notyfi(.title3, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.84))
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
            .disabled(isPerformingAccountAction)
        }
        .padding(.top, 22)
    }

    private var accountActionOverlay: some View {
        ZStack {
            Color.black.opacity(0.08)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                ProgressView()
                    .controlSize(.large)
                    .tint(NotyfiTheme.brandBlue)

                Text(accountActionTitle)
                    .font(.notyfi(.subheadline, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.82))
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(NotyfiTheme.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(NotyfiTheme.surfaceBorder, lineWidth: 1)
                    }
                    .shadow(color: NotyfiTheme.shadow, radius: 16, x: 0, y: 8)
            }
            .padding(.horizontal, 40)
        }
        .transition(.opacity)
        .allowsHitTesting(true)
    }

    private var accountActionTitle: String {
        switch pendingAccountAction {
        case .signOut:
            return "Signing out".notyfiLocalized
        case .deleteAccount:
            return "Deleting account".notyfiLocalized
        case nil:
            return ""
        }
    }
}

private struct FeedbackSheetView: View {
    let url: URL

    var body: some View {
        FeedbackWebView(url: url)
            .ignoresSafeArea()
            .background(NotyfiTheme.background)
    }
}

private struct FeedbackWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard webView.url != url else {
            return
        }

        webView.load(URLRequest(url: url))
    }
}

private struct LanguageActionRow: View {
    let icon: String
    let title: String
    let currentLanguage: NotyfiLanguage
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .foregroundStyle(NotyfiTheme.secondaryText)
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 18)

                Text(title.notyfiLocalized)
                    .font(.notyfi(.body))
                    .foregroundStyle(.primary.opacity(0.82))

                Spacer()

                HStack(spacing: 5) {
                    Text(currentLanguage.flag)
                        .font(.system(size: 14))
                    Text(currentLanguage.shortLabel)
                        .font(.notyfi(.subheadline))
                        .foregroundStyle(NotyfiTheme.secondaryText)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(NotyfiTheme.tertiaryText)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
                    .font(.system(size: 17, weight: .semibold))
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
                    .font(.system(size: 17, weight: .semibold))
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

private struct DictationLanguageMenuRow: View {
    let icon: String
    let title: String
    @Binding var selection: NotyfiDictationLanguage
    let onSelect: (NotyfiDictationLanguage) -> Void

    var body: some View {
        Menu {
            dictationLanguageButton(for: .autoDetect)

            Divider()

            ForEach(NotyfiDictationLanguage.selectableLanguages) { language in
                dictationLanguageButton(for: language)
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .foregroundStyle(NotyfiTheme.secondaryText)
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 18)

                HStack(spacing: 6) {
                    Text(title.notyfiLocalized)
                        .font(.notyfi(.body))
                        .foregroundStyle(.primary.opacity(0.82))

                    Image(systemName: "info.circle")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(NotyfiTheme.tertiaryText)
                }

                Spacer()

                Text(selection.title.notyfiLocalized)
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

    @ViewBuilder
    private func dictationLanguageButton(for language: NotyfiDictationLanguage) -> some View {
        Button {
            onSelect(language)
        } label: {
            if language == selection {
                Label(language.title.notyfiLocalized, systemImage: "checkmark")
            } else {
                Text(language.title.notyfiLocalized)
            }
        }
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
                .font(.system(size: 17, weight: .semibold))
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
                .font(.system(size: 17, weight: .semibold))
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
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 18)

            Text(title.notyfiLocalized)
                .font(.notyfi(.body))
                .foregroundStyle(.primary.opacity(0.82))

            Spacer()

            Text(value)
                .font(.notyfi(.subheadline))
                .foregroundStyle(NotyfiTheme.secondaryText)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 180, alignment: .trailing)
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
                    .font(.system(size: 17, weight: .semibold))
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SettingsSheetView(viewModel: SettingsViewModel(store: ExpenseJournalStore(previewMode: true)), authManager: AuthManager())
}
