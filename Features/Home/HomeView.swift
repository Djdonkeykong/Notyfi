import SwiftUI

struct HomeView: View {
    @ObservedObject private var store: ExpenseJournalStore
    @StateObject private var viewModel: HomeViewModel
    @State private var pageSelection = 0
    @State private var isSummaryExpanded = false
    @FocusState private var isComposerFocused: Bool

    init(store: ExpenseJournalStore) {
        self.store = store
        _viewModel = StateObject(wrappedValue: HomeViewModel(store: store))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                NotelyTheme.background.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 22) {
                    HomeTopBar(
                        selectedDate: viewModel.selectedDate,
                        entryCount: viewModel.displayedEntries.count,
                        onDateTap: { viewModel.isDatePickerPresented = true },
                        onSettingsTap: { viewModel.isSettingsPresented = true }
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 4)

                    TabView(selection: $pageSelection) {
                        ForEach([-1, 0, 1], id: \.self) { offset in
                            DayJournalPage(
                                entries: viewModel.entries(for: viewModel.date(forDayOffset: offset)),
                                composerText: $viewModel.composerText,
                                isComposerFocused: $isComposerFocused,
                                feedback: offset == 0 ? viewModel.draftFeedback : nil,
                                onTextChange: { viewModel.handleComposerChange() },
                                store: store
                            )
                            .tag(offset)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .onChange(of: pageSelection) { _, newValue in
                        guard newValue != 0 else {
                            return
                        }

                        Haptics.mediumImpact()
                        isSummaryExpanded = false
                        viewModel.moveSelection(by: newValue)

                        DispatchQueue.main.async {
                            pageSelection = 0
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !isComposerFocused {
                    VStack(spacing: 10) {
                        if isSummaryExpanded {
                            HomeSnapshotCard(
                                insight: viewModel.insight,
                                entryCount: viewModel.displayedEntries.count,
                                averageSpend: averageSpend,
                                currencyCode: viewModel.currencyCode
                            )
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }

                        HomeSummaryBar(
                            insight: viewModel.insight,
                            entryCount: viewModel.displayedEntries.count,
                            currencyCode: viewModel.currencyCode,
                            onTap: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                    isSummaryExpanded.toggle()
                                }
                            }
                        )
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.9), value: isSummaryExpanded)
                }
            }
            .sheet(isPresented: $viewModel.isDatePickerPresented) {
                DatePickerSheetView(selection: $viewModel.selectedDate)
                    .presentationDetents([.height(398)])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(.clear)
                    .presentationCornerRadius(34)
            }
            .sheet(isPresented: $viewModel.isSettingsPresented) {
                SettingsSheetView(viewModel: SettingsViewModel())
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(NotelyTheme.background.opacity(0.98))
                    .presentationCornerRadius(34)
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    if isComposerFocused {
                        KeyboardAccessoryBar(
                            totalText: viewModel.insight.dayTotal.formattedCurrency(code: viewModel.currencyCode),
                            onDismissKeyboard: { isComposerFocused = false }
                        )
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private extension HomeView {
    var averageSpend: Double {
        let count = max(viewModel.displayedEntries.count, 1)
        return viewModel.insight.dayTotal / Double(count)
    }
}

private struct DayJournalPage: View {
    let entries: [ExpenseEntry]
    @Binding var composerText: String
    var isComposerFocused: FocusState<Bool>.Binding
    let feedback: DraftComposerFeedback?
    let onTextChange: () -> Void
    let store: ExpenseJournalStore

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(entries) { entry in
                    NavigationLink {
                        EntryDetailView(entry: entry, store: store)
                    } label: {
                        ExpensePreviewRow(entry: entry)
                    }
                    .buttonStyle(.plain)
                }

                QuickCaptureComposer(
                    text: $composerText,
                    isFocused: isComposerFocused,
                    showsPlaceholder: entries.isEmpty,
                    feedback: feedback,
                    onTextChange: onTextChange
                )

                Color.clear
                    .frame(height: 140)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 140)
        }
    }
}

private struct KeyboardAccessoryBar: View {
    let totalText: String
    let onDismissKeyboard: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            SoftCapsule(horizontalPadding: 18, verticalPadding: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6, weight: .bold))
                        .foregroundStyle(NotelyTheme.reviewTint)

                    Text(totalText)
                        .font(.notely(.footnote, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.84))
                        .monospacedDigit()
                }
            }

            KeyboardCircleButton(systemImage: "mic.fill")
            KeyboardCircleButton(systemImage: "camera.fill")
            KeyboardCircleButton(systemImage: "plus")
            KeyboardCircleButton(
                systemImage: "keyboard.chevron.compact.down",
                action: onDismissKeyboard
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct KeyboardCircleButton: View {
    let systemImage: String
    var action: () -> Void = {}

    var body: some View {
        Button(action: {
            Haptics.mediumImpact()
            action()
        }) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.78))
                .frame(width: 38, height: 38)
                .background {
                    Circle()
                        .fill(NotelyTheme.surface)
                        .overlay {
                            Circle()
                                .stroke(NotelyTheme.surfaceBorder, lineWidth: 1)
                        }
                }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HomeView(store: ExpenseJournalStore(previewMode: true))
}
