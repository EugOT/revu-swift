# Architecture

## Overview

Revu is a SwiftUI macOS application organized around MVVM, a local SQLite-backed store, and deterministic study logic. The app is designed to remain fully usable offline.

## Top-Level Structure

- `Revu/Revu/App/`: app entry, commands, and workspace bootstrap
- `Revu/Revu/Views/`: SwiftUI screens and reusable UI components
- `Revu/Revu/ViewModels/`: view-facing state and orchestration
- `Revu/Revu/Services/`: business logic, forecasting, attachments, import coordination
- `Revu/Revu/SRS/`: scheduler and review math
- `Revu/Revu/Store/`: local persistence, DTOs, repositories, and events
- `Revu/Revu/Import/`: import parsers and preview pipeline
- `Revu/Revu/Export/`: export and backup generation
- `RevuTests/`: unit and integration-style tests using Swift Testing

## Runtime Flow

### Bootstrap

`DataController` creates the shared local store and publishes store events to the UI layer. `RevuApp` wires environment state for the workspace without any backend, auth, or billing dependencies.

### Views and View Models

Views stay focused on presentation and interaction. View models coordinate user actions, load data from storage-backed services, and keep UI mutations on the main actor.

### Services

Services handle higher-level operations such as:

- study plan forecasting
- study session progression
- import/export coordination
- attachment management
- deck and course workflows

Where possible, the code keeps scheduler and transformation logic deterministic so it is easy to test.

## Storage

### Local-First Persistence

Revu persists application data under:

```text
~/Library/Application Support/revu/v1/
```

The store is implemented in two layers:

- `SQLiteStorage`: repository-facing async API plus store event notifications
- `SQLiteStore`: actor-isolated SQLite implementation and schema management

The database file is `revu.sqlite3`. Attachments and imported media live alongside it in `attachments/`.

### Data Domains

The local store covers:

- decks and nested folders
- cards and SRS state
- review logs and study events
- settings
- exams
- study guides and attachments
- courses, topics, lessons, and study-plan summaries

## Scheduler Boundaries

FSRS and related study planning logic are separate from SwiftUI. Core scheduling inputs are card state, review history, and user settings. UI components ask services for summaries and next actions rather than embedding scheduling decisions directly in views.

## Import and Export Pipeline

Imports normalize source formats into a shared `ImportedDocument` model before persistence. Export produces a stable Revu JSON document for full-fidelity backups. Merge behavior is centralized so format-specific parsers only need to handle parsing and validation.

## Design System

The UI system is defined by:

- `Revu/Revu/Support/DesignSystem.swift`
- `Revu/Revu/Views/Common/NotionStyleComponents.swift`
- `docs/ui-design-system.md`

Use the tokens and component patterns there instead of introducing arbitrary spacing, colors, or surface styles.
