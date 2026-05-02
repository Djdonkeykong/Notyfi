import SwiftUI

struct CustomCategoryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private let existing: CustomCategoryDefinition?
    private let onSave: (CustomCategoryDefinition) -> Void

    @State private var title: String
    @State private var selectedSymbol: String
    @State private var selectedTintR: Double
    @State private var selectedTintG: Double
    @State private var selectedTintB: Double

    init(
        existing: CustomCategoryDefinition? = nil,
        onSave: @escaping (CustomCategoryDefinition) -> Void
    ) {
        self.existing = existing
        self.onSave = onSave
        _title = State(initialValue: existing?.title ?? "")
        _selectedSymbol = State(initialValue: existing?.symbol ?? Self.curatedSymbols[0])
        _selectedTintR = State(initialValue: existing?.tintR ?? Self.presetColors[0].r)
        _selectedTintG = State(initialValue: existing?.tintG ?? Self.presetColors[0].g)
        _selectedTintB = State(initialValue: existing?.tintB ?? Self.presetColors[0].b)
    }

    private var isEditing: Bool { existing != nil }
    private var canSave: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }
    private var previewTint: Color { Color(red: selectedTintR, green: selectedTintG, blue: selectedTintB) }

    var body: some View {
        ZStack {
            NotyfiTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    header
                    previewSection
                    nameSection
                    colorSection
                    symbolSection
                }
                .padding(.horizontal, 20)
                .safeAreaPadding(.top, 14)
                .padding(.bottom, 120)
                .frame(maxWidth: horizontalSizeClass == .regular ? 720 : .infinity)
                .frame(maxWidth: .infinity)
            }
        }
        .safeAreaInset(edge: .bottom) { saveButton }
    }

    // MARK: - Sections

    private var header: some View {
        HStack {
            Text(isEditing ? "Edit Category".notyfiLocalized : "New Category".notyfiLocalized)
                .font(.notyfi(.title3, weight: .bold))
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(NotyfiTheme.tertiaryText)
            }
            .buttonStyle(.plain)
        }
    }

    private var previewSection: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: selectedSymbol)
                    .font(.system(size: 14, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white)
                Text(title.isEmpty ? "Preview".notyfiLocalized : title)
                    .font(.notyfi(.subheadline, weight: .medium))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(previewTint)
            }
            Spacer()
        }
        .animation(.easeInOut(duration: 0.15), value: selectedSymbol)
        .animation(.easeInOut(duration: 0.15), value: title)
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Name")
            editorCard {
                TextField("Category name".notyfiLocalized, text: $title)
                    .font(.notyfi(.body))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
            }
        }
    }

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Color")
            editorCard {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Self.presetColors, id: \.label) { preset in
                            let isSelected = abs(selectedTintR - preset.r) < 0.01
                                && abs(selectedTintG - preset.g) < 0.01
                                && abs(selectedTintB - preset.b) < 0.01
                            Button {
                                selectedTintR = preset.r
                                selectedTintG = preset.g
                                selectedTintB = preset.b
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                Circle()
                                    .fill(Color(red: preset.r, green: preset.g, blue: preset.b))
                                    .frame(width: 34, height: 34)
                                    .overlay {
                                        if isSelected {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .scaleEffect(isSelected ? 1.12 : 1.0)
                                    .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isSelected)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
        }
    }

    private var symbolSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Icon")
            editorCard {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 6),
                    spacing: 0
                ) {
                    ForEach(Self.curatedSymbols, id: \.self) { symbol in
                        Button {
                            selectedSymbol = symbol
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Image(systemName: symbol)
                                .font(.system(size: 22))
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(symbol == selectedSymbol ? previewTint : NotyfiTheme.secondaryText)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background {
                                    if symbol == selectedSymbol {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(previewTint.opacity(0.12))
                                            .padding(4)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .animation(.easeInOut(duration: 0.1), value: selectedSymbol)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
        }
    }

    private var saveButton: some View {
        Button(action: save) {
            Text(isEditing ? "Save Changes".notyfiLocalized : "Create Category".notyfiLocalized)
                .font(.notyfi(.body, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(canSave ? NotyfiTheme.brandBlue : NotyfiTheme.brandBlue.opacity(0.38))
                }
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 16)
        .background {
            LinearGradient(
                colors: [NotyfiTheme.background.opacity(0), NotyfiTheme.background],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.4)
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func editorCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(NotyfiTheme.elevatedSurface)
                    .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
            }
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        if let existing {
            onSave(CustomCategoryDefinition(
                rawValue: existing.rawValue,
                title: trimmed,
                symbol: selectedSymbol,
                tintR: selectedTintR,
                tintG: selectedTintG,
                tintB: selectedTintB
            ))
        } else {
            onSave(CustomCategoryDefinition.makeNew(
                title: trimmed,
                symbol: selectedSymbol,
                tintR: selectedTintR,
                tintG: selectedTintG,
                tintB: selectedTintB
            ))
        }
        dismiss()
    }

    // MARK: - Curated data

    private static let curatedSymbols: [String] = [
        // Food & Drink
        "cup.and.saucer.fill", "wineglass.fill", "birthday.cake.fill",
        "takeoutbag.and.cup.and.straw.fill", "fork.knife.circle.fill", "popcorn.fill",
        // Transport
        "bicycle", "scooter", "tram.fill", "ferry.fill",
        "fuelpump.fill", "parkingsign.circle.fill",
        // Health & Sport
        "dumbbell.fill", "figure.run", "pills.fill",
        "stethoscope", "heart.fill", "bandage.fill",
        // Leisure & Hobbies
        "gamecontroller.fill", "book.fill", "music.note",
        "camera.fill", "theatermasks.fill", "paintbrush.fill",
        // Home & Life
        "sofa.fill", "washer.fill", "lightbulb.fill",
        "hammer.fill", "bed.double.fill", "shower.fill",
        // Tech
        "desktopcomputer", "headphones", "wifi",
        "printer.fill", "externaldrive.fill", "iphone",
        // Finance & Shopping
        "creditcard.fill", "gift.fill", "cart.fill",
        "handbag.fill", "ticket.fill", "rosette",
        // Nature & Other
        "pawprint.fill", "leaf.fill", "umbrella.fill",
        "bolt.fill", "star.fill", "flag.fill",
    ]

    struct PresetColor {
        let label: String
        let r: Double
        let g: Double
        let b: Double
    }

    static let presetColors: [PresetColor] = [
        PresetColor(label: "orange",  r: 1.00, g: 0.44, b: 0.16),
        PresetColor(label: "emerald", r: 0.16, g: 0.76, b: 0.38),
        PresetColor(label: "blue",    r: 0.20, g: 0.48, b: 0.98),
        PresetColor(label: "violet",  r: 0.60, g: 0.36, b: 0.96),
        PresetColor(label: "cyan",    r: 0.06, g: 0.74, b: 0.84),
        PresetColor(label: "pink",    r: 0.98, g: 0.24, b: 0.58),
        PresetColor(label: "amber",   r: 0.96, g: 0.68, b: 0.08),
        PresetColor(label: "red",     r: 0.96, g: 0.18, b: 0.26),
        PresetColor(label: "saffron", r: 0.98, g: 0.55, b: 0.08),
        PresetColor(label: "indigo",  r: 0.40, g: 0.22, b: 0.96),
        PresetColor(label: "teal",    r: 0.10, g: 0.70, b: 0.56),
        PresetColor(label: "rose",    r: 0.95, g: 0.30, b: 0.46),
    ]
}

#Preview {
    CustomCategoryEditorView { _ in }
}
