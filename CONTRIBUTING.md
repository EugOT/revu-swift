# Contributing

## Scope

This repository is the public macOS app only. Please keep contributions focused on:

- local-first study workflows
- app stability and performance
- import/export reliability
- FSRS and study-planning correctness
- SwiftUI usability and accessibility

Do not reintroduce private infrastructure, hosted auth, billing, or AI-provider integrations in general-purpose changes.

## Development Setup

1. Open `Revu.xcodeproj`.
2. Build the `Revu` scheme.
3. Run tests with the `RevuTests` scheme or `xcodebuild test`.

## Design and Code Expectations

- Prefer small, focused pull requests.
- Follow the existing MVVM split between views, view models, services, and store code.
- Reuse `DesignSystem` tokens rather than adding arbitrary spacing or colors.
- Keep storage and scheduler logic deterministic where possible.
- Add or update tests for behavior changes outside purely visual UI tweaks.

## Before Opening a PR

- build the app
- run the test suite
- check for accidental private strings or endpoints in changed files
- update public docs if behavior or workflows changed

## Reporting Bugs

Include:

- macOS version
- Xcode version if relevant
- reproduction steps
- expected behavior
- actual behavior
- sample import file or deck data when the bug involves parsing or migration
