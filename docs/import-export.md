# Import and Export

## Overview

Revu supports local import and export workflows so study material can move in and out of the app without any cloud dependency.

## Supported Imports

### Anki

Supported sources:

- Anki profile folders
- `.apkg` exports
- `.colpkg` exports

The importer preserves as much local data as possible, including:

- deck hierarchy
- card content
- tags
- scheduling state
- suspended state
- referenced media

Re-importing uses stable identifiers where available so repeated imports update existing content instead of duplicating it.

### Revu JSON

Revu’s native JSON backup format is the highest-fidelity portable format.

Document header:

```json
{
  "schema": "revu.flashcards",
  "version": 4
}
```

Current expectations:

- `schema` must be `revu.flashcards`
- supported versions are `1...4`
- documents include `exportedAt` and a `decks` array

Decks can include:

- `id`
- `parentId`
- `name`
- `note`
- `dueDate`
- `isArchived`
- `cards`

Cards can include:

- `id`
- `kind`
- `front`
- `back`
- `clozeSource`
- `choices`
- `correctChoiceIndex`
- `tags`
- `media`
- `createdAt`
- `updatedAt`

### CSV / TSV

Tabular imports are intended for spreadsheets and generated content.

Required fields:

- `deck`
- card content appropriate for the chosen kind

Common optional fields:

- `kind`
- `front` or `prompt`
- `back` or `answer`
- `cloze`
- `choices`
- `correct`
- `tags`
- `id`
- `createdAt`
- `updatedAt`
- `dueDate`
- `archived`

Notes:

- the importer auto-detects comma vs tab delimiters
- multiple-choice `choices` can be separated by `|`, `;`, or newlines
- `correct` can be a 1-based index or the matching answer text
- nested deck paths use `::`

### Markdown Blocks

Markdown block imports are designed for hand-authored text and LLM-friendly generation.

Rules:

- blocks are separated by a line containing `---`
- every block must include `deck:`
- `kind` defaults to `basic`
- multiline values are indented on following lines
- nested deck paths use `::`

Minimal example:

```text
deck: Biology::Cells
kind: basic
front: What is the powerhouse of the cell?
back: Mitochondria
---
deck: Biology::Cells
kind: cloze
cloze: ATP is produced in the {{c1::mitochondria}}.
```

## Merge Behavior

All import formats normalize into the same internal document model before writing to storage.

Key rules:

- decks and cards are matched by stable IDs when present
- if an existing card has a newer `updatedAt`, the incoming card is skipped
- if the incoming card is newer, it replaces the stored content
- missing IDs are generated during import
- deck study plans can be rebuilt after import

## Export

Revu exports decks as Revu JSON using:

- pretty-printed output
- ISO-8601 dates
- stable deck and card identifiers
- sorted card order by `createdAt`

Use JSON export for:

- backups
- moving data between Revu installations
- generating study sets in external tooling

## Compatibility Expectations

- the JSON schema is intended to be backward-compatible within the supported version window
- imports are local-only and should not require network access
- merge behavior is intentionally conservative to avoid overwriting newer local edits with older source data
