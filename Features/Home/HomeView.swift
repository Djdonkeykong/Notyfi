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
                    VStack(alignment: .leading, spacing: 28) {
                        HomeTopBar(
                            selectedDate: viewModel.selectedDate,
                            entryCount: viewModel.displayedEntries.count,
                            onDateTap: { viewModel.isDatePickerPresented = true },
                            onSettingsTap: { viewModel.isSettingsPresented = true }
                        )

                        VStack(alignment: .leading, spacing: 20) {
                            QuickCaptureComposer(text: $viewModel.composerText) {
                                viewModel.addEntry()
                            }

                            VStack(alignment: .leading, spacing: 18) {
                                if viewModel.hasEntries {
                                    ForEach(viewModel.displayedEntries) { entry in
                                        NavigationLink {
                                            EntryDetailView(entry: entry, store: store)
                                        } label: {
                                            ExpensePreviewRow(entry: entry)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                } else {
                                    Text("Nothing for \(viewModel.selectedDate.notelySectionTitle().lowercased()) yet.")
                                        .font(.notely(.body))
                                        .foregroundStyle(NotelyTheme.tertiaryText)

                                    Text("Write something simple like \"Coffee 49 kr\" and Notely will quietly structure it in the background.")
                                        .font(.notely(.body))
                                        .foregroundStyle(NotelyTheme.secondaryText)
                                        .lineSpacing(4)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }

                        Color.clear
                            .frame(height: 140)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 140)
                }
            }
            .safeAreaInset(edge: .bottom) {
                HomeSummaryBar(
                    insight: viewModel.insight,
                    entryCount: viewModel.displayedEntries.count,
                    currencyCode: viewModel.currencyCode
                )
            }
            .sheet(isPresented: $viewModel.isDatePickerPresented) {
                DatePickerSheetView(selection: $viewModel.selectedDate)
                    .presentationDetents([.height(430)])
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
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

#Preview {
    HomeView(store: ExpenseJournalStore(previewMode: true))
}
