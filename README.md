# Notyfi

Notyfi is a personal finance journal that feels like Apple Notes, styled with Amy's calm native SwiftUI aesthetic.

## Setup

This workspace uses `XcodeGen` to keep the project file lightweight.

1. Install XcodeGen on your Mac.
2. Run `xcodegen generate` from the repo root.
3. Open `Notyfi.xcodeproj` in Xcode.
4. Configure Supabase auth providers and use a signed-in test account for cloud-backed features.

Run `python3 scripts/check_localizations.py` before committing UI text changes. Codemagic runs the same check and will fail the build if:

- English is missing a key referenced from Swift
- another locale is missing a key that exists in English
- a locale has extra keys not present in English
- a `Localizable.strings` file contains duplicate keys

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

## AI Parsing

AI parsing now runs through the Supabase Edge Function `parse-expense`.

Set the `OPENAI_API_KEY` secret in Supabase Edge Functions settings before testing parsing. The iOS app no longer embeds or reads an OpenAI key directly.

## Extension Points

- Cloud sync should sit beside `ExpenseJournalStore` and mirror entries to Supabase without changing the views.
