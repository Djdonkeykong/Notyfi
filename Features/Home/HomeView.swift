import SwiftUI

struct HomeView: View {
    @ObservedObject private var store: ExpenseJournalStore
    @StateObject private var viewModel: HomeViewModel

    init(store: ExpenseJournalStore) {
        self.store = store
        _viewModel = StateObject(wrappedValue: HomeViewModel(store: store))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                NotelyTheme.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        HomeTopBar(
                            selectedDate: viewModel.selectedDate,
                            onDateTap: { viewModel.isDatePickerPresented = true },
                            onSettingsTap: { viewModel.isSettingsPresented = true }
                        )

                        SoftSurface(cornerRadius: 34, padding: 22) {
                            VStack(alignment: .leading, spacing: 18) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(viewModel.selectedDate.notelySectionTitle())
                                        .font(.notely(.title3, weight: .semibold))
                                        .foregroundStyle(.primary.opacity(0.84))

                                    Spacer()

                                    if viewModel.hasEntries {
                                        Text(viewModel.entryCountText)
                                            .font(.notely(.footnote, weight: .medium))
                                            .foregroundStyle(NotelyTheme.secondaryText)
                                    }
                                }

                                if viewModel.hasEntries {
                                    InsightsCard(
                                        insight: viewModel.insight,
                                        currencyCode: viewModel.currencyCode
                                    )

                                    VStack(spacing: 12) {
                                        ForEach(viewModel.displayedEntries) { entry in
                                            NavigationLink {
                                                EntryDetailView(entry: entry, store: store)
                                            } label: {
                                                ExpensePreviewRow(entry: entry)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                } else {
                                    EmptyJournalStateView(selectedDate: viewModel.selectedDate)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 140)
                }
            }
            .safeAreaInset(edge: .bottom) {
                QuickCaptureComposer(text: $viewModel.composerText) {
                    viewModel.addEntry()
                }
                .background(.clear)
            }
            .sheet(isPresented: $viewModel.isDatePickerPresented) {
                DatePickerSheetView(selection: $viewModel.selectedDate)
                    .presentationDetents([.height(430)])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(34)
            }
            .sheet(isPresented: $viewModel.isSettingsPresented) {
                SettingsSheetView(viewModel: SettingsViewModel())
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(34)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

#Preview {
    HomeView(store: ExpenseJournalStore(previewMode: true))
}
