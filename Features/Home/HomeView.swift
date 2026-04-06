import SwiftUI
import UIKit

struct HomeView: View {
    @ObservedObject private var store: ExpenseJournalStore
    @StateObject private var viewModel: HomeViewModel
    @State private var isSummaryExpanded = false
    @State private var selectedEntry: ExpenseEntry?
    @State private var focusedEditor: JournalEditorTarget?
    @State private var editorFocusRequest: JournalEditorFocusRequest?
    @State private var journalCursorLineIndex = 0
    @State private var journalLineFramesByDate: [Date: [JournalTextLineFrame]] = [:]
    @State private var focusRequestGeneration = 0
    @State private var presentationRequestGeneration = 0

    init(store: ExpenseJournalStore) {
        self.store = store
        _viewModel = StateObject(wrappedValue: HomeViewModel(store: store))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                NotyfiTheme.background.ignoresSafeArea()

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
                        previousJournalText: viewModel.journalDraft(for: viewModel.date(forDayOffset: -1)),
                        journalText: $viewModel.journalText,
                        nextJournalText: viewModel.journalDraft(for: viewModel.date(forDayOffset: 1)),
                        focusedEditor: $focusedEditor,
                        editorFocusRequest: $editorFocusRequest,
                        journalCursorLineIndex: $journalCursorLineIndex,
                        lineFramesByDate: $journalLineFramesByDate,
                        feedback: viewModel.draftFeedback,
                        onJournalTextChange: { rawText in
                            var transaction = Transaction()
                            transaction.animation = nil

                            withTransaction(transaction) {
                                viewModel.updateJournalText(rawText)
                            }
                        },
                        onReturnKey: { lineEdit in
                            applyFocusRequest {
                                viewModel.handleReturn(
                                    at: lineEdit.lineIndex,
                                    leadingText: lineEdit.leadingText,
                                    trailingText: lineEdit.trailingText
                                )
                            }
                        },
                        onBackspaceAtLineStart: { lineIndex in
                            applyFocusRequest {
                                viewModel.handleBackspaceAtLineStart(at: lineIndex)
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
                            .transition(.opacity)
                        }

                        HomeSummaryBar(
                            insight: viewModel.insight,
                            entryCount: viewModel.displayedEntries.count,
                            currencyCode: viewModel.currencyCode,
                            isExpanded: isSummaryExpanded,
                            onTap: {
                                withAnimation(.easeInOut(duration: 0.22)) {
                                    isSummaryExpanded.toggle()
                                }
                            }
                        )
                    }
                    .animation(.easeInOut(duration: 0.22), value: isSummaryExpanded)
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
                    .presentationBackground(NotyfiTheme.background.opacity(0.98))
                    .presentationCornerRadius(34)
            }
            .sheet(item: $selectedEntry) { entry in
                EntryDetailView(entry: entry, store: store)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(NotyfiTheme.background.opacity(0.98))
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
            if journalCursorLineIndex < viewModel.displayedEntries.count,
               journalCursorLineIndex >= 0 {
                let editedEntry = viewModel.displayedEntries[journalCursorLineIndex]
                store.reparseEntryImmediately(id: editedEntry.id)
            }

            if viewModel.hasPendingComposerDraft {
                viewModel.addEntry()
            }
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
        EditableJournalTextView.resignActiveEditor()

        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )

        DispatchQueue.main.async {
            EditableJournalTextView.resignActiveEditor()

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
    let previousJournalText: String
    @Binding var journalText: String
    let nextJournalText: String
    @Binding var focusedEditor: JournalEditorTarget?
    @Binding var editorFocusRequest: JournalEditorFocusRequest?
    @Binding var journalCursorLineIndex: Int
    @Binding var lineFramesByDate: [Date: [JournalTextLineFrame]]
    let feedback: DraftComposerFeedback?
    let onJournalTextChange: (String) -> Void
    let onReturnKey: (JournalLogLineEdit) -> Void
    let onBackspaceAtLineStart: (Int) -> Void
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
                    journalText: previousJournalText,
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
                    journalText: nextJournalText,
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
            journalText: $journalText,
            focusedEditor: $focusedEditor,
            editorFocusRequest: $editorFocusRequest,
            journalCursorLineIndex: $journalCursorLineIndex,
            lineFramesByDate: $lineFramesByDate,
            feedback: feedback,
            onJournalTextChange: onJournalTextChange,
            onReturnKey: onReturnKey,
            onBackspaceAtLineStart: onBackspaceAtLineStart,
            onEntryTap: onEntryTap,
            onBlankSpaceTap: onBlankSpaceTap,
            scrollDisabled: scrollDisabled
        )
        .id(date)
    }

    private func sidePage(
        date: Date,
        entries: [ExpenseEntry],
        journalText: String,
        scrollDisabled: Bool
    ) -> some View {
        DayJournalPage(
            date: date,
            entries: entries,
            isEditable: false,
            journalText: .constant(journalText),
            focusedEditor: .constant(nil),
            editorFocusRequest: .constant(nil),
            journalCursorLineIndex: .constant(0),
            lineFramesByDate: $lineFramesByDate,
            feedback: nil,
            onJournalTextChange: { _ in },
            onReturnKey: { _ in },
            onBackspaceAtLineStart: { _ in },
            onEntryTap: onEntryTap,
            onBlankSpaceTap: {},
            scrollDisabled: scrollDisabled
        )
        .id(date)
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
    @Binding var journalText: String
    @Binding var focusedEditor: JournalEditorTarget?
    @Binding var editorFocusRequest: JournalEditorFocusRequest?
    @Binding var journalCursorLineIndex: Int
    @Binding var lineFramesByDate: [Date: [JournalTextLineFrame]]
    let feedback: DraftComposerFeedback?
    let onJournalTextChange: (String) -> Void
    let onReturnKey: (JournalLogLineEdit) -> Void
    let onBackspaceAtLineStart: (Int) -> Void
    let onEntryTap: (ExpenseEntry) -> Void
    let onBlankSpaceTap: () -> Void
    let scrollDisabled: Bool

    @State private var contentHeight: CGFloat
    @State private var lineFrames: [JournalTextLineFrame]

    private let trailingColumnWidth: CGFloat = 114
    private let trailingGap: CGFloat = 14

    init(
        date: Date,
        entries: [ExpenseEntry],
        isEditable: Bool,
        journalText: Binding<String>,
        focusedEditor: Binding<JournalEditorTarget?>,
        editorFocusRequest: Binding<JournalEditorFocusRequest?>,
        journalCursorLineIndex: Binding<Int>,
        lineFramesByDate: Binding<[Date: [JournalTextLineFrame]]>,
        feedback: DraftComposerFeedback?,
        onJournalTextChange: @escaping (String) -> Void,
        onReturnKey: @escaping (JournalLogLineEdit) -> Void,
        onBackspaceAtLineStart: @escaping (Int) -> Void,
        onEntryTap: @escaping (ExpenseEntry) -> Void,
        onBlankSpaceTap: @escaping () -> Void,
        scrollDisabled: Bool
    ) {
        self.date = date
        self.entries = entries
        self.isEditable = isEditable
        _journalText = journalText
        _focusedEditor = focusedEditor
        _editorFocusRequest = editorFocusRequest
        _journalCursorLineIndex = journalCursorLineIndex
        _lineFramesByDate = lineFramesByDate
        self.feedback = feedback
        self.onJournalTextChange = onJournalTextChange
        self.onReturnKey = onReturnKey
        self.onBackspaceAtLineStart = onBackspaceAtLineStart
        self.onEntryTap = onEntryTap
        self.onBlankSpaceTap = onBlankSpaceTap
        self.scrollDisabled = scrollDisabled

        let dayKey = Calendar.autoupdatingCurrent.startOfDay(for: date)
        let resolvedFrames = lineFramesByDate.wrappedValue[dayKey]
            ?? Self.estimatedLineFrames(for: journalText.wrappedValue)
        _lineFrames = State(initialValue: resolvedFrames)
        _contentHeight = State(
            initialValue: resolvedFrames.last.map { $0.minY + $0.height } ?? 34
        )
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView(showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    JournalLogTextView(
                        text: $journalText,
                        focusedEditor: $focusedEditor,
                        focusRequest: $editorFocusRequest,
                        cursorLineIndex: $journalCursorLineIndex,
                        editorTarget: .composer(Calendar.current.startOfDay(for: date)),
                        minHeight: max(geometry.size.height - 140, 240),
                        isEditable: isEditable,
                        trailingInset: trailingColumnWidth + trailingGap,
                        onTextChange: onJournalTextChange,
                        onReturnKey: onReturnKey,
                        onBackspaceAtLineStart: onBackspaceAtLineStart,
                        onLineFramesChange: { frames in
                            lineFrames = frames
                            lineFramesByDate[dayKey] = frames
                            contentHeight = max(
                                frames.last.map { $0.minY + $0.height } ?? 0,
                                max(geometry.size.height - 140, 240)
                            )
                        }
                    )
                    .allowsHitTesting(isEditable)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if journalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Start typing your money notes...".notyfiLocalized)
                            .font(.notyfi(.body))
                            .foregroundStyle(NotyfiTheme.tertiaryText)
                            .padding(.leading, 1)
                            .allowsHitTesting(false)
                    }

                    journalAccessoryOverlay(isAccessoryTapEnabled: !scrollDisabled)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 140)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .contentShape(Rectangle())
                .onTapGesture {
                    guard isEditable, !scrollDisabled else {
                        return
                    }

                    onBlankSpaceTap()
                }
            }
            .scrollDisabled(scrollDisabled || contentHeight <= geometry.size.height + 1)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private func journalAccessoryOverlay(isAccessoryTapEnabled: Bool) -> some View {
        ZStack(alignment: .topTrailing) {
            ForEach(accessoryRows) { row in
                Button {
                    guard isAccessoryTapEnabled, let entry = row.entry else {
                        return
                    }

                    Haptics.mediumImpact()
                    onEntryTap(entry)
                } label: {
                    JournalLineAccessoryView(
                        entry: row.entry,
                        composerText: row.composerText,
                        feedback: row.feedback
                    )
                }
                .buttonStyle(.plain)
                .allowsHitTesting(row.entry != nil && isAccessoryTapEnabled)
                .frame(width: trailingColumnWidth, alignment: .topTrailing)
                .offset(y: row.frame.minY + 1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }

    private var accessoryRows: [JournalAccessoryRow] {
        let lines = journalText.components(separatedBy: "\n")

        return lineFrames.map { frame in
            let entry = frame.lineIndex < entries.count ? entries[frame.lineIndex] : nil
            let composerText = frame.lineIndex == lines.count - 1 ? lines.last ?? "" : nil
            let isComposerLine = frame.lineIndex == lines.count - 1

            return JournalAccessoryRow(
                id: frame.lineIndex,
                frame: frame,
                entry: entry,
                composerText: isComposerLine ? composerText : nil,
                feedback: isComposerLine ? feedback : nil
            )
        }
    }

    private var dayKey: Date {
        Calendar.autoupdatingCurrent.startOfDay(for: date)
    }

    private static func estimatedLineFrames(for text: String) -> [JournalTextLineFrame] {
        let lines = text.components(separatedBy: "\n")
        let lineHeight = JournalLogTextView.estimatedLineHeight
        let rowHeight = lineHeight + JournalLogTextView.paragraphSpacing

        var frames: [JournalTextLineFrame] = []
        var currentY: CGFloat = 0

        for lineIndex in lines.indices {
            frames.append(
                JournalTextLineFrame(
                    lineIndex: lineIndex,
                    minY: currentY,
                    height: lineHeight
                )
            )
            currentY += rowHeight
        }

        return frames.isEmpty
            ? [JournalTextLineFrame(lineIndex: 0, minY: 0, height: lineHeight)]
            : frames
    }
}

private struct JournalAccessoryRow: Identifiable {
    let id: Int
    let frame: JournalTextLineFrame
    let entry: ExpenseEntry?
    let composerText: String?
    let feedback: DraftComposerFeedback?
}

private struct JournalLineAccessoryView: View {
    let entry: ExpenseEntry?
    let composerText: String?
    let feedback: DraftComposerFeedback?

    private let trailingSecondaryHeight: CGFloat = 16

    private var composerTrimmedText: String {
        composerText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var primaryFeedbackColor: Color {
        switch feedback?.primaryColorName {
        case .accent:
            return Color(red: 0.26, green: 0.56, blue: 0.96)
        case .income:
            return Color(red: 0.28, green: 0.71, blue: 0.45)
        case .expense:
            return Color(red: 0.90, green: 0.36, blue: 0.34)
        case .neutral, .none:
            return NotyfiTheme.secondaryText
        }
    }

    private var trailingPrimary: String {
        guard let entry else {
            return ""
        }

        if entry.rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ""
        }

        if entry.amount == 0 {
            return entry.confidence == .review
                ? "Review".notyfiLocalized
                : "Thinking".notyfiLocalized
        }

        if entry.isAmountEstimated {
            return signedAmountText(for: entry)
        }

        if entry.confidence.needsReview {
            return "Review".notyfiLocalized
        }

        return signedAmountText(for: entry)
    }

    private var trailingSecondary: String? {
        guard let entry else {
            return nil
        }

        if entry.rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return nil
        }

        if entry.category != .uncategorized {
            return entry.category.title
        }

        if entry.transactionKind == .income {
            return TransactionKind.income.title
        }

        return entry.merchant
    }

    private var trailingPrimaryColor: Color {
        guard let entry else {
            return primaryFeedbackColor
        }

        if entry.amount == 0 {
            return NotyfiTheme.secondaryText
        }

        if entry.confidence.needsReview, !entry.isAmountEstimated {
            return NotyfiTheme.secondaryText
        }

        return entry.transactionKind == .income
            ? Color(red: 0.28, green: 0.71, blue: 0.45)
            : Color(red: 0.90, green: 0.36, blue: 0.34)
    }

    private var isProcessingEntry: Bool {
        guard let entry else {
            return false
        }

        return !entry.rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && entry.amount == 0
            && entry.confidence != .review
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 3) {
            if isProcessingEntry, let entry {
                JournalProcessingStatusText(
                    activityText: entry.rawText,
                    showsTypingDots: false
                )
                    .font(.notyfi(.body, weight: .semibold))
                    .foregroundStyle(trailingPrimaryColor)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(1)
            } else if let entry {
                Text(trailingPrimary)
                    .font(.notyfi(.body, weight: .semibold))
                    .foregroundStyle(trailingPrimaryColor)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(1)

                Text(trailingSecondary ?? " ")
                    .font(.system(size: 10.5, weight: .regular, design: .rounded))
                    .foregroundStyle(NotyfiTheme.tertiaryText)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(height: trailingSecondaryHeight, alignment: .top)
                    .opacity(trailingSecondary == nil ? 0 : 1)
            } else if let feedback, !composerTrimmedText.isEmpty {
                if feedback.primaryColorName == .neutral {
                    JournalProcessingStatusText(activityText: composerTrimmedText)
                        .font(.notyfi(.body, weight: .semibold))
                        .foregroundStyle(primaryFeedbackColor)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(1)
                } else {
                    Text(feedback.primaryText)
                        .font(.notyfi(.body, weight: .semibold))
                        .foregroundStyle(primaryFeedbackColor)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(1)
                }

                Text(feedback.secondaryText ?? " ")
                    .font(.system(size: 10.5, weight: .regular, design: .rounded))
                    .foregroundStyle(NotyfiTheme.tertiaryText)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(height: trailingSecondaryHeight, alignment: .top)
                    .opacity(feedback.secondaryText == nil ? 0 : 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topTrailing)
        .padding(.top, 1)
    }

    private func signedAmountText(for entry: ExpenseEntry) -> String {
        let formattedAmount = entry.amount.formattedCurrency(code: entry.currencyCode)
        let signedAmount = entry.transactionKind == .income
            ? "+\(formattedAmount)"
            : "-\(formattedAmount)"
        return entry.isAmountEstimated ? "\(signedAmount)*" : signedAmount
    }
}


private enum PagerDragAxisLock {
    case horizontal
    case vertical
}

private struct KeyboardAccessoryBar: View {
    let onDismissKeyboard: () -> Void

    var body: some View {
        HStack(spacing: 12) {
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
                        .fill(NotyfiTheme.surface)
                        .overlay {
                            Circle()
                                .stroke(NotyfiTheme.surfaceBorder, lineWidth: 1)
                        }
                        .shadow(color: NotyfiTheme.shadow, radius: 18, x: 0, y: 10)
                }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HomeView(store: ExpenseJournalStore(previewMode: true))
}
