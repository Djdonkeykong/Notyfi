# Notely

Notely is a personal finance journal that feels like Apple Notes, styled with Amy's calm native SwiftUI aesthetic.

## Setup

This workspace uses `XcodeGen` to keep the project file lightweight.

1. Install XcodeGen on your Mac.
2. Run `xcodegen generate` from the repo root.
3. Open `Notely.xcodeproj` in Xcode.
4. Add `OPENAI_API_KEY` to your Xcode scheme environment variables to enable AI parsing during development.

## Codemagic

`codemagic.yaml` is included at the repo root for internal TestFlight uploads.

Before the workflow can publish, add these in Codemagic:

- Environment variable group `appstore_credentials`
- `APP_STORE_CONNECT_PRIVATE_KEY`
- `APP_STORE_CONNECT_KEY_IDENTIFIER`
- `APP_STORE_CONNECT_ISSUER_ID`
- An App Store distribution certificate and provisioning profile for `com.djdonkeykong.notely`

The workflow uses `testFlightInternalTestingOnly`, so the uploaded build is meant for internal TestFlight viewing rather than external beta review.

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

## AI Parsing

`OpenAIExpenseParsingService` reads `OPENAI_API_KEY` from the app process environment first, then falls back to `Info.plist` so Codemagic builds can temporarily receive the key from an environment variable.

This is a testing shortcut only. Before shipping, move parsing behind a small backend endpoint so the API key is not embedded in the client app.

## Extension Points

- Cloud sync should sit beside `ExpenseJournalStore` and mirror entries to Supabase without changing the views.
