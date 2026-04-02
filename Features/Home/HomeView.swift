import SwiftUI

struct HomeView: View {
    @ObservedObject private var store: ExpenseJournalStore
    @StateObject private var viewModel: HomeViewModel
    @State private var isSummaryExpanded = false
    @State private var selectedEntry: ExpenseEntry?
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

                    DayJournalPager(
                        previousEntries: viewModel.entries(for: viewModel.date(forDayOffset: -1)),
                        currentEntries: viewModel.displayedEntries,
                        nextEntries: viewModel.entries(for: viewModel.date(forDayOffset: 1)),
                        composerText: $viewModel.composerText,
                        isComposerFocused: $isComposerFocused,
                        feedback: viewModel.draftFeedback,
                        onTextChange: { viewModel.handleComposerChange() },
                        onEmptyBackspace: { viewModel.handleComposerBackspaceOnEmpty() },
                        onEntryTap: { entry in
                            selectedEntry = entry
                        },
                        onMoveSelection: { dayOffset in
                            Haptics.mediumImpact()
                            isSummaryExpanded = false
                            viewModel.moveSelection(by: dayOffset)
                        }
                    )
                }
            }
            .safeAreaInset(edge: .bottom) {
                if isComposerFocused {
                    KeyboardAccessoryBar(
                        totalText: viewModel.insight.dayTotal.formattedCurrency(code: viewModel.currencyCode),
                        onDismissKeyboard: { isComposerFocused = false }
                    )
                    .padding(.horizontal, 8)
                    .padding(.top, 10)
                    .padding(.bottom, 14)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
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
                DatePickerSheetView(selection: selectedDateBinding)
                    .presentationDetents([.height(640)])
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
            .sheet(item: $selectedEntry) { entry in
                EntryDetailView(entry: entry, store: store)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(NotelyTheme.background.opacity(0.98))
                    .presentationCornerRadius(34)
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

    var selectedDateBinding: Binding<Date> {
        Binding(
            get: { viewModel.selectedDate },
            set: { viewModel.setSelectedDate($0) }
        )
    }
}

private struct DayJournalPager: View {
    let previousEntries: [ExpenseEntry]
    let currentEntries: [ExpenseEntry]
    let nextEntries: [ExpenseEntry]
    @Binding var composerText: String
    var isComposerFocused: FocusState<Bool>.Binding
    let feedback: DraftComposerFeedback?
    let onTextChange: () -> Void
    let onEmptyBackspace: () -> Void
    let onEntryTap: (ExpenseEntry) -> Void
    let onMoveSelection: (Int) -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var isTransitioning = false

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .top, spacing: 0) {
                page(entries: previousEntries, feedback: nil)
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
                page(entries: currentEntries, feedback: feedback)
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
                page(entries: nextEntries, feedback: nil)
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
            }
            .frame(width: geometry.size.width * 3, height: geometry.size.height, alignment: .topLeading)
            .offset(x: -geometry.size.width + dragOffset)
            .contentShape(Rectangle())
            .clipped()
            .simultaneousGesture(dragGesture(pageWidth: geometry.size.width))
        }
    }

    private func page(entries: [ExpenseEntry], feedback: DraftComposerFeedback?) -> some View {
        DayJournalPage(
            entries: entries,
            composerText: $composerText,
            isComposerFocused: isComposerFocused,
            feedback: feedback,
            onTextChange: onTextChange,
            onEmptyBackspace: onEmptyBackspace,
            onEntryTap: onEntryTap
        )
    }

    private func dragGesture(pageWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .local)
            .onChanged { value in
                guard !isTransitioning else {
                    return
                }

                guard abs(value.translation.width) > abs(value.translation.height) else {
                    return
                }

                dragOffset = clampedDragOffset(for: value.translation.width, pageWidth: pageWidth)
            }
            .onEnded { value in
                guard !isTransitioning else {
                    return
                }

                guard abs(value.translation.width) > abs(value.translation.height) else {
                    settlePageTurn(dayOffset: 0, pageWidth: pageWidth)
                    return
                }

                let dayOffset = targetDayOffset(for: value, pageWidth: pageWidth)
                settlePageTurn(dayOffset: dayOffset, pageWidth: pageWidth)
            }
    }

    private func clampedDragOffset(for translation: CGFloat, pageWidth: CGFloat) -> CGFloat {
        let limit = pageWidth * 0.9
        return min(max(translation, -limit), limit)
    }

    private func targetDayOffset(for value: DragGesture.Value, pageWidth: CGFloat) -> Int {
        let translation = value.translation.width
        let predictedTranslation = value.predictedEndTranslation.width
        let distanceThreshold = pageWidth * 0.2
        let velocityThreshold = pageWidth * 0.45

        if translation <= -distanceThreshold || predictedTranslation <= -velocityThreshold {
            return 1
        }

        if translation >= distanceThreshold || predictedTranslation >= velocityThreshold {
            return -1
        }

        return 0
    }

    private func settlePageTurn(dayOffset: Int, pageWidth: CGFloat) {
        let animation = Animation.interactiveSpring(response: 0.28, dampingFraction: 0.88, blendDuration: 0.16)

        guard dayOffset != 0 else {
            withAnimation(animation) {
                dragOffset = 0
            }
            return
        }

        isTransitioning = true

        withAnimation(animation) {
            dragOffset = dayOffset > 0 ? -pageWidth : pageWidth
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            onMoveSelection(dayOffset)

            var transaction = Transaction()
            transaction.animation = nil

            withTransaction(transaction) {
                dragOffset = 0
            }

            isTransitioning = false
        }
    }
}

private struct DayJournalPage: View {
    let entries: [ExpenseEntry]
    @Binding var composerText: String
    var isComposerFocused: FocusState<Bool>.Binding
    let feedback: DraftComposerFeedback?
    let onTextChange: () -> Void
    let onEmptyBackspace: () -> Void
    let onEntryTap: (ExpenseEntry) -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(entries) { entry in
                    Button(action: {
                        Haptics.mediumImpact()
                        onEntryTap(entry)
                    }) {
                        ExpensePreviewRow(entry: entry)
                    }
                    .buttonStyle(.plain)
                }

                QuickCaptureComposer(
                    text: $composerText,
                    isFocused: isComposerFocused,
                    showsPlaceholder: entries.isEmpty,
                    feedback: feedback,
                    onTextChange: onTextChange,
                    onEmptyBackspace: onEmptyBackspace
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    isComposerFocused.wrappedValue = true
                }

                Color.clear
                    .frame(maxWidth: .infinity)
                    .frame(height: 240)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isComposerFocused.wrappedValue = true
                    }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 140)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private struct KeyboardAccessoryBar: View {
    let totalText: String
    let onDismissKeyboard: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            KeyboardTotalPill(totalText: totalText)
            KeyboardCircleButton(systemImage: "mic.fill", tint: Color(red: 0.03, green: 0.51, blue: 0.98))
            KeyboardCircleButton(systemImage: "camera.fill", tint: Color(red: 0.76, green: 0.17, blue: 0.87))
            KeyboardCircleButton(systemImage: "plus", tint: Color(red: 0.98, green: 0.54, blue: 0.13))
            KeyboardCircleButton(
                systemImage: "keyboard.chevron.compact.down",
                tint: .primary.opacity(0.92),
                action: onDismissKeyboard
            )
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct KeyboardTotalPill: View {
    let totalText: String

    var body: some View {
        Button(action: {
            Haptics.mediumImpact()
        }) {
            HStack(spacing: 10) {
                Text("\u{1F525}")
                    .font(.system(size: 17))

                Text(totalText)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.96))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 20)
            .frame(minHeight: 46)
            .background {
                Capsule()
                    .fill(NotelyTheme.surface)
                    .overlay {
                        Capsule()
                            .stroke(NotelyTheme.surfaceBorder, lineWidth: 1)
                    }
                    .shadow(color: NotelyTheme.shadow, radius: 18, x: 0, y: 10)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct KeyboardCircleButton: View {
    let systemImage: String
    let tint: Color
    var action: () -> Void = {}

    var body: some View {
        Button(action: {
            Haptics.mediumImpact()
            action()
        }) {
            Image(systemName: systemImage)
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 46, height: 46)
                .background {
                    Circle()
                        .fill(NotelyTheme.surface)
                        .overlay {
                            Circle()
                                .stroke(NotelyTheme.surfaceBorder, lineWidth: 1)
                        }
                        .shadow(color: NotelyTheme.shadow, radius: 18, x: 0, y: 10)
                }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HomeView(store: ExpenseJournalStore(previewMode: true))
}
