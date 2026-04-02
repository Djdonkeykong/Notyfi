# Notely

Notely is a personal finance journal that feels like Apple Notes, styled with Amy's calm native SwiftUI aesthetic.

## Setup

This workspace uses `XcodeGen` to keep the project file lightweight.

1. Install XcodeGen on your Mac.
2. Run `xcodegen generate` from the repo root.
3. Open `Notely.xcodeproj` in Xcode.

## Structure

- `App`: app entry and root view
- `DesignSystem`: shared colors, typography, and soft surface styles
- `Models`: expense entry and finance journal models
- `Services`: local journal store and placeholder parsing service
- `ViewModels`: home, entry detail, and settings view models
- `Features/Home`: home screen, date sheet, entry list, and composer
- `Features/EntryDetail`: note-like expense detail editing
- `Features/Settings`: Amy-inspired settings sheet

## Next Files To Edit

- `Features/Home/HomeView.swift`
- `Features/Home/ExpensePreviewRow.swift`
- `Features/Home/QuickCaptureComposer.swift`
- `Features/Settings/SettingsSheetView.swift`
- `Services/ExpenseParsingService.swift`

## Extension Points

- AI parsing should replace `PlaceholderExpenseParsingService` behind the `ExpenseParsingServicing` protocol.
- Cloud sync should sit beside `ExpenseJournalStore` and mirror entries to Supabase without changing the views.
