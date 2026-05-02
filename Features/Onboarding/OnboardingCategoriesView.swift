import SwiftUI

struct OnboardingCategoriesView: View {
    @Binding var selectedCategories: Set<ExpenseCategory>
    @ObservedObject var store: ExpenseJournalStore

    @State private var isNewCategoryPresented = false
    @State private var editingCategory: CustomCategoryDefinition? = nil
    @State private var categoryToDelete: CustomCategoryDefinition? = nil

    private struct CategoryGroup {
        let title: String
        let color: Color
        let categories: [ExpenseCategory]
    }

    private let groups: [CategoryGroup] = [
        CategoryGroup(
            title: "Essentials",
            color: Color(red: 0.93, green: 0.45, blue: 0.28),
            categories: [.housing, .bills]
        ),
        CategoryGroup(
            title: "Food & Drink",
            color: Color(red: 0.25, green: 0.70, blue: 0.42),
            categories: [.food, .groceries]
        ),
        CategoryGroup(
            title: "Transport",
            color: Color(red: 0.28, green: 0.52, blue: 0.92),
            categories: [.transport, .travel]
        ),
        CategoryGroup(
            title: "Lifestyle",
            color: Color(red: 0.52, green: 0.38, blue: 0.92),
            categories: [.shopping, .social, .entertainment, .health]
        ),
    ]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Text("What do you spend on?".notyfiLocalized)
                    .font(.notyfi(.title2, weight: .bold))
                    .padding(.bottom, 10)

                Text("Pick the categories that apply to you. You can always add or edit these later.".notyfiLocalized)
                    .font(.notyfi(.body))
                    .foregroundStyle(NotyfiTheme.secondaryText)
                    .lineSpacing(3)
                    .padding(.bottom, 28)

                VStack(alignment: .leading, spacing: 28) {
                    ForEach(groups, id: \.title) { group in
                        groupSection(group)
                    }

                    if !store.customCategories.isEmpty {
                        customSection
                    }

                    addCategoryButton
                }
            }
            .padding(.horizontal, 24)
        }
        .contentMargins(.top, 72, for: .scrollContent)
        .contentMargins(.bottom, 160, for: .scrollContent)
        .scrollBounceBehavior(.always)
        .scrollIndicators(.hidden)
        .background(NotyfiTheme.brandLight)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $isNewCategoryPresented) {
            CustomCategoryEditorView { newDef in
                store.addCustomCategory(newDef)
                selectedCategories.insert(newDef.asExpenseCategory)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $editingCategory) { def in
            CustomCategoryEditorView(existing: def) { updated in
                store.updateCustomCategory(updated)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .confirmationDialog(
            "Delete \"\(categoryToDelete?.title ?? "")\"?",
            isPresented: Binding(
                get: { categoryToDelete != nil },
                set: { if !$0 { categoryToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete".notyfiLocalized, role: .destructive) {
                if let def = categoryToDelete {
                    selectedCategories.remove(def.asExpenseCategory)
                    store.deleteCustomCategory(rawValue: def.rawValue)
                }
                categoryToDelete = nil
            }
            Button("Cancel".notyfiLocalized, role: .cancel) { categoryToDelete = nil }
        }
    }

    private func groupSection(_ group: CategoryGroup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(group.title.notyfiLocalized)
                .font(.notyfi(.subheadline, weight: .bold))
                .foregroundStyle(group.color)

            FlowLayout(spacing: 10) {
                ForEach(group.categories) { category in
                    CategoryPill(
                        category: category,
                        isSelected: selectedCategories.contains(category)
                    ) {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        if selectedCategories.contains(category) {
                            selectedCategories.remove(category)
                        } else {
                            selectedCategories.insert(category)
                        }
                    }
                }
            }
        }
    }

    private var customSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("My Categories".notyfiLocalized)
                .font(.notyfi(.subheadline, weight: .bold))
                .foregroundStyle(NotyfiTheme.secondaryText)

            FlowLayout(spacing: 10) {
                ForEach(store.customCategories) { def in
                    let cat = def.asExpenseCategory
                    CategoryPill(
                        category: cat,
                        isSelected: selectedCategories.contains(cat)
                    ) {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        if selectedCategories.contains(cat) {
                            selectedCategories.remove(cat)
                        } else {
                            selectedCategories.insert(cat)
                        }
                    }
                    .contextMenu {
                        Button {
                            editingCategory = def
                        } label: {
                            Label("Edit".notyfiLocalized, systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            categoryToDelete = def
                        } label: {
                            Label("Delete".notyfiLocalized, systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    private var addCategoryButton: some View {
        Button {
            isNewCategoryPresented = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(NotyfiTheme.secondaryText)
                Text("Add Custom Category".notyfiLocalized)
                    .font(.notyfi(.subheadline, weight: .medium))
                    .foregroundStyle(NotyfiTheme.secondaryText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(NotyfiTheme.elevatedSurface)
                    )
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Category Pill

private struct CategoryPill: View {
    let category: ExpenseCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: category.symbol)
                    .font(.system(size: 14, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isSelected ? .white : category.tint)

                Text(category.title)
                    .font(.notyfi(.subheadline, weight: .medium))
                    .foregroundStyle(isSelected ? .white : .primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? category.tint : NotyfiTheme.elevatedSurface)
                    .shadow(color: .black.opacity(isSelected ? 0.0 : 0.05), radius: 4, x: 0, y: 2)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isSelected ? Color.clear : Color.primary.opacity(0.10),
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Flow Layout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var height: CGFloat = 0
        var rowX: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowX + size.width > maxWidth, rowX > 0 {
                height += rowHeight + spacing
                rowX = 0
                rowHeight = 0
            }
            rowX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        height += rowHeight
        return CGSize(width: maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var rowX = bounds.minX
        var rowY = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowX + size.width > bounds.maxX, rowX > bounds.minX {
                rowY += rowHeight + spacing
                rowX = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: rowX, y: rowY), proposal: ProposedViewSize(size))
            rowX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    OnboardingCategoriesView(
        selectedCategories: .constant(Set(ExpenseCategory.allCases)),
        store: ExpenseJournalStore(previewMode: true)
    )
}
