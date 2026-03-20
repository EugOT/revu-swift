# Revu

Revu is a local-first macOS study app for decks, cards, exams, study guides, and FSRS-based review sessions. This public repository contains only the macOS application and its tests.

## What’s Included

- Deck and card management with nested folders
- FSRS-based study sessions with review history and forecasting
- Local course, exam, and study-guide workflows
- Import support for Anki, Revu JSON, CSV/TSV, and Markdown blocks
- Export support for Revu JSON backups
- A SwiftUI design system used across the macOS app

## What’s Not Included

- Website code
- Hosted backend infrastructure
- Authentication, billing, subscriptions, or account sync
- AI generation, AI tutoring, external tool integrations, or provider configuration
- Internal planning files and private repo history

## Screenshots

Screenshots are not bundled in this initial open-source extraction. Capture fresh images from the current app build so they match the public feature set rather than the private product history.

## Requirements

- macOS 14 or later
- Xcode 16 or later

## Build

Open `Revu.xcodeproj` in Xcode and run the `Revu` scheme.

CLI build:

```bash
xcodebuild -project Revu.xcodeproj -scheme Revu -destination 'platform=macOS' build
```

CLI tests:

```bash
xcodebuild test -project Revu.xcodeproj -scheme RevuTests -destination 'platform=macOS'
```

## App Data Location

By default Revu stores data in:

```text
~/Library/Application Support/revu/v1/
```

Key paths inside that directory:

- `revu.sqlite3`: local database
- `attachments/`: imported media and study-guide attachments
- `backups/`: local backup/export staging

## Repo Layout

- `Revu/`: macOS app target resources and source tree
- `RevuTests/`: Swift Testing suite
- `docs/architecture.md`: module and storage overview
- `docs/import-export.md`: supported formats and merge behavior
- `docs/ui-design-system.md`: canonical UI rules and tokens

## Development Notes

- The app is local-first. It should build and run without environment variables.
- Public-safe bundle identifiers and URL handling are already stripped of private auth flows.
- If you add new UI, use the design tokens in `Revu/Revu/Support/DesignSystem.swift`.

## License

The code in this directory is licensed under `GPL-3.0-only`. See `LICENSE`.

The Revu name, logo, and other brand assets are not licensed for reuse as
trademarks. GPL covers copyright licensing; it does not grant trademark
rights.
