import SwiftUI
import UIKit

struct HomeView: View {
    @ObservedObject private var store: ExpenseJournalStore
    @StateObject private var viewModel: HomeViewModel
    @State private var isSummaryExpanded = false
    @State private var selectedEntry: ExpenseEntry?
    @State private var focusedEditor: JournalEditorTarget?
    @State private var editorFocusRequest: JournalEditorFocusRequest?
    @State private var focusRequestGeneration = 0
    @State private var presentationRequestGeneration = 0

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
                        onDateTap: { presentDatePicker() },
                        onSettingsTap: { presentSettings() }
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 4)

                    DayJournalPager(
                        previousDate: viewModel.date(forDayOffset: -1),
                        currentDate: viewModel.selectedDate,
                        nextDate: viewModel.date(forDayOffset: 1),
                        previousEntries: viewModel.entries(for: viewModel.date(forDayOffset: -1)),
                        currentEntries: viewModel.displayedEntries,
                        nextEntries: viewModel.entries(for: viewModel.date(forDayOffset: 1)),
                        previousComposerText: viewModel.composerDraft(for: viewModel.date(forDayOffset: -1)),
                        composerText: $viewModel.composerText,
                        nextComposerText: viewModel.composerDraft(for: viewModel.date(forDayOffset: 1)),
                        focusedEditor: $focusedEditor,
                        editorFocusRequest: $editorFocusRequest,
                        feedback: viewModel.draftFeedback,
                        onComposerTextChange: { rawText in
                            var transaction = Transaction()
                            transaction.animation = nil

                            withTransaction(transaction) {
                                viewModel.updateComposerText(rawText)
                            }
                        },
                        onComposerSplit: { leadingText, trailingText in
                            applyFocusRequest {
                                viewModel.splitComposerText(
                                    leadingText: leadingText,
                                    trailingText: trailingText
                                )
                            }
                        },
                        onComposerMergeBackward: {
                            applyFocusRequest {
                                viewModel.mergeComposerBackward()
                            }
                        },
                        onEntryTextChange: { entry, rawText in
                            var transaction = Transaction()
                            transaction.animation = nil

                            withTransaction(transaction) {
                                viewModel.updateEntryText(entry, rawText: rawText)
                            }
                        },
                        onEntrySplit: { entry, leadingText, trailingText in
                            applyFocusRequest {
                                viewModel.splitEntryText(
                                    entry,
                                    leadingText: leadingText,
                                    trailingText: trailingText
                                )
                            }
                        },
                        onEntryMergeBackward: { entry in
                            applyFocusRequest {
                                viewModel.mergeEntryBackward(entry)
                            }
                        },
                        onEntryTap: { entry in
                            presentEntryDetail(entry)
                        },
                        onBlankSpaceTap: {
                            applyFocusRequest {
                                viewModel.focusComposer()
                            }
                        },
                        onMoveSelection: { dayOffset in
                            clearEditorFocus()
                            isSummaryExpanded = false
                            viewModel.moveSelection(by: dayOffset)
                        }
                    )
                }
            }
            .safeAreaInset(edge: .bottom) {
                if focusedEditor != nil {
                    KeyboardAccessoryBar(
                        totalText: viewModel.insight.dayExpenseTotal.formattedCurrency(code: viewModel.currencyCode),
                        onDismissKeyboard: { clearEditorFocus() }
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
                DatePickerSheetView(
                    selection: selectedDateBinding,
                    entryDates: store.entries.map(\.date)
                )
                    .presentationDetents([.height(430)])
                    .presentationDragIndicator(.hidden)
                    .presentationBackground(.clear)
                    .presentationBackgroundInteraction(.enabled(upThrough: .height(430)))
                    .presentationCornerRadius(34)
            }
            .sheet(isPresented: $viewModel.isSettingsPresented) {
                SettingsSheetView(viewModel: SettingsViewModel(store: store))
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
    var isPresentingModalSurface: Bool {
        viewModel.isDatePickerPresented || viewModel.isSettingsPresented || selectedEntry != nil
    }

    var selectedDateBinding: Binding<Date> {
        Binding(
            get: { viewModel.selectedDate },
            set: { viewModel.setSelectedDate($0) }
        )
    }

    func presentDatePicker() {
        presentAfterEditorSettles {
            viewModel.isDatePickerPresented = true
        }
    }

    func presentSettings() {
        presentAfterEditorSettles {
            viewModel.isSettingsPresented = true
        }
    }

    func presentEntryDetail(_ entry: ExpenseEntry) {
        presentAfterEditorSettles {
            selectedEntry = entry
        }
    }

    func presentAfterEditorSettles(_ action: @escaping () -> Void) {
        guard !isPresentingModalSurface else {
            return
        }

        let hadFocusedEditor = focusedEditor != nil
        presentationRequestGeneration += 1
        let requestGeneration = presentationRequestGeneration

        clearEditorFocus(cancelsPendingPresentation: false)

        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
            isSummaryExpanded = false
        }

        let presentationDelay: TimeInterval = hadFocusedEditor ? 0.18 : 0.01

        DispatchQueue.main.asyncAfter(deadline: .now() + presentationDelay) {
            guard
                requestGeneration == presentationRequestGeneration,
                !isPresentingModalSurface
            else {
                return
            }

            action()
        }
    }

    func applyFocusRequest(
        _ action: () -> JournalEditorFocusRequest?
    ) {
        var transaction = Transaction()
        transaction.animation = nil

        let request = withTransaction(transaction) {
            action()
        }

        if let request {
            focusRequestGeneration += 1

            var focusTransaction = Transaction()
            focusTransaction.animation = nil

            withTransaction(focusTransaction) {
                focusedEditor = request.target
                editorFocusRequest = request
            }
        }
    }

    func clearEditorFocus(cancelsPendingPresentation: Bool = true) {
        let activeEditor = focusedEditor

        if case .composer = activeEditor {
            viewModel.addEntry()
        } else if case .entry(let entryID) = activeEditor {
            store.reparseEntryImmediately(id: entryID)
        }

        if cancelsPendingPresentation {
            presentationRequestGeneration += 1
        }

        focusRequestGeneration += 1
        let requestGeneration = focusRequestGeneration
        editorFocusRequest = nil
        forceResignKeyboard()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            guard requestGeneration == focusRequestGeneration else {
                return
            }

            focusedEditor = nil
        }
    }

    func forceResignKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )

        DispatchQueue.main.async {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil,
                from: nil,
                for: nil
            )
        }
    }
}

private struct DayJournalPager: View {
    let previousDate: Date
    let currentDate: Date
    let nextDate: Date
    let previousEntries: [ExpenseEntry]
    let currentEntries: [ExpenseEntry]
    let nextEntries: [ExpenseEntry]
    let previousComposerText: String
    @Binding var composerText: String
    let nextComposerText: String
    @Binding var focusedEditor: JournalEditorTarget?
    @Binding var editorFocusRequest: JournalEditorFocusRequest?
    let feedback: DraftComposerFeedback?
    let onComposerTextChange: (String) -> Void
    let onComposerSplit: (String, String) -> Void
    let onComposerMergeBackward: () -> Void
    let onEntryTextChange: (ExpenseEntry, String) -> Void
    let onEntrySplit: (ExpenseEntry, String, String) -> Void
    let onEntryMergeBackward: (ExpenseEntry) -> Void
    let onEntryTap: (ExpenseEntry) -> Void
    let onBlankSpaceTap: () -> Void
    let onMoveSelection: (Int) -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var isHorizontalDragging = false
    @State private var isTransitioning = false
    @State private var dragAxisLock: PagerDragAxisLock?

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .top, spacing: 0) {
                sidePage(
                    date: previousDate,
                    entries: previousEntries,
                    composerText: previousComposerText,
                    scrollDisabled: pageScrollDisabled
                )
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
                activePage(
                    date: currentDate,
                    entries: currentEntries,
                    feedback: feedback,
                    scrollDisabled: pageScrollDisabled
                )
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
                sidePage(
                    date: nextDate,
                    entries: nextEntries,
                    composerText: nextComposerText,
                    scrollDisabled: pageScrollDisabled
                )
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
            }
            .frame(width: geometry.size.width * 3, height: geometry.size.height, alignment: .topLeading)
            .offset(x: -geometry.size.width + dragOffset)
            .contentShape(Rectangle())
            .clipped()
            .simultaneousGesture(dragGesture(pageWidth: geometry.size.width))
        }
    }

    private var pageScrollDisabled: Bool {
        isHorizontalDragging || isTransitioning
    }

    private func activePage(
        date: Date,
        entries: [ExpenseEntry],
        feedback: DraftComposerFeedback?,
        scrollDisabled: Bool
    ) -> some View {
        DayJournalPage(
            date: date,
            entries: entries,
            isEditable: true,
            composerText: $composerText,
            focusedEditor: $focusedEditor,
            editorFocusRequest: $editorFocusRequest,
            feedback: feedback,
            onComposerTextChange: onComposerTextChange,
            onComposerSplit: onComposerSplit,
            onComposerMergeBackward: onComposerMergeBackward,
            onEntryTextChange: onEntryTextChange,
            onEntrySplit: onEntrySplit,
            onEntryMergeBackward: onEntryMergeBackward,
            onEntryTap: onEntryTap,
            onBlankSpaceTap: onBlankSpaceTap,
            scrollDisabled: scrollDisabled
        )
    }

    private func sidePage(
        date: Date,
        entries: [ExpenseEntry],
        composerText: String,
        scrollDisabled: Bool
    ) -> some View {
        DayJournalPage(
            date: date,
            entries: entries,
            isEditable: false,
            composerText: .constant(composerText),
            focusedEditor: .constant(nil),
            editorFocusRequest: .constant(nil),
            feedback: nil,
            onComposerTextChange: { _ in },
            onComposerSplit: { _, _ in },
            onComposerMergeBackward: {},
            onEntryTextChange: { _, _ in },
            onEntrySplit: { _, _, _ in },
            onEntryMergeBackward: { _ in },
            onEntryTap: onEntryTap,
            onBlankSpaceTap: {},
            scrollDisabled: scrollDisabled
        )
    }

    private func dragGesture(pageWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .local)
            .onChanged { value in
                guard !isTransitioning else {
                    return
                }

                let horizontal = abs(value.translation.width)
                let vertical = abs(value.translation.height)

                if dragAxisLock == nil {
                    guard max(horizontal, vertical) > 6 else {
                        return
                    }

                    dragAxisLock = horizontal > vertical ? .horizontal : .vertical

                    if dragAxisLock == .horizontal {
                        Haptics.mediumImpact()
                    }
                }

                guard dragAxisLock == .horizontal else {
                    return
                }

                isHorizontalDragging = true
                dragOffset = clampedDragOffset(for: value.translation.width, pageWidth: pageWidth)
            }
            .onEnded { value in
                guard !isTransitioning else {
                    resetDragTracking()
                    return
                }

                guard dragAxisLock == .horizontal else {
                    resetDragTracking()
                    return
                }

                let horizontal = abs(value.translation.width)
                let vertical = abs(value.translation.height)

                guard horizontal > vertical else {
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                resetDragTracking()
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
            resetDragTracking()
        }
    }

    private func resetDragTracking() {
        isHorizontalDragging = false
        dragAxisLock = nil
    }
}

private struct DayJournalPage: View {
    let date: Date
    let entries: [ExpenseEntry]
    let isEditable: Bool
    @Binding var composerText: String
    @Binding var focusedEditor: JournalEditorTarget?
    @Binding var editorFocusRequest: JournalEditorFocusRequest?
    let feedback: DraftComposerFeedback?
    let onComposerTextChange: (String) -> Void
    let onComposerSplit: (String, String) -> Void
    let onComposerMergeBackward: () -> Void
    let onEntryTextChange: (ExpenseEntry, String) -> Void
    let onEntrySplit: (ExpenseEntry, String, String) -> Void
    let onEntryMergeBackward: (ExpenseEntry) -> Void
    let onEntryTap: (ExpenseEntry) -> Void
    let onBlankSpaceTap: () -> Void
    let scrollDisabled: Bool

    @State private var contentHeight: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(entries) { entry in
                        ExpensePreviewRow(
                            entry: entry,
                            focusedEditor: $focusedEditor,
                            focusRequest: $editorFocusRequest,
                            isEditable: isEditable,
                            isAccessoryTapEnabled: !scrollDisabled,
                            onTextChange: { rawText in
                                onEntryTextChange(entry, rawText)
                            },
                            onSplitText: { leadingText, trailingText in
                                onEntrySplit(entry, leadingText, trailingText)
                            },
                            onMergeBackward: {
                                onEntryMergeBackward(entry)
                            },
                            onAccessoryTap: {
                                Haptics.mediumImpact()
                                onEntryTap(entry)
                            }
                        )
                    }

                    QuickCaptureComposer(
                        text: $composerText,
                        focusedEditor: $focusedEditor,
                        focusRequest: $editorFocusRequest,
                        editorTarget: .composer(Calendar.current.startOfDay(for: date)),
                        isEditable: isEditable,
                        showsPlaceholder: entries.isEmpty,
                        feedback: feedback,
                        onTextChange: onComposerTextChange,
                        onSplitText: onComposerSplit,
                        onMergeBackward: onComposerMergeBackward
                    )

                    Color.clear
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard isEditable, !scrollDisabled else {
                                return
                            }

                            onBlankSpaceTap()
                        }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 140)
                .background {
                    GeometryReader { contentGeometry in
                        Color.clear
                            .onAppear {
                                contentHeight = contentGeometry.size.height
                            }
                            .onChange(of: contentGeometry.size.height) { _, newHeight in
                                contentHeight = newHeight
                            }
                    }
                }
            }
            .scrollDisabled(scrollDisabled || contentHeight <= geometry.size.height + 1)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}


private enum PagerDragAxisLock {
    case horizontal
    case vertical
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
