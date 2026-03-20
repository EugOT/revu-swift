# UI Design System

This document is the public UI source of truth for Revu. When adding or changing SwiftUI screens, use the design tokens and patterns already defined in `Revu/Revu/Support/DesignSystem.swift`.

## Design Goals

- calm over flashy
- fast over ornamental
- consistent over bespoke
- focused over noisy

The interface should feel productive and lightweight for long study sessions.

## Surface Hierarchy

Revu uses four main surface tiers:

### Canvas

Primary workspace background for content-heavy views.

- token: `DesignSystem.Colors.canvasBackground`
- usage: dashboard, folder canvas, list surfaces, editors

### Sidebar

Recessed navigation and framing surface.

- token: `DesignSystem.Colors.sidebarBackground`
- usage: left navigation, secondary chrome, persistent side panels

### Window / Card

Elevated content containers.

- token: `DesignSystem.Colors.window`
- usage: cards, tiles, modal panels, floating surfaces

### Inspector

Deeper contextual utility surface.

- token: `DesignSystem.Colors.inspectorBackground`
- usage: inspectors, metadata panels, settings sections

Rules:

- avoid nesting the same surface tier inside itself
- use separators instead of inventing extra nested cards
- keep elevated surfaces purposeful

## Spacing

Use the 4-point token scale only.

| Token | Value |
| --- | --- |
| `xxs` | 4 |
| `xs` | 8 |
| `sm` | 12 |
| `md` | 16 |
| `lg` | 24 |
| `xl` | 32 |
| `xxl` | 48 |
| `xxxl` | 64 |

Do not introduce arbitrary values like `18` or `22` unless there is a strong reason and an existing pattern to match.

## Radius

Prefer the shared continuous-corner tokens:

- `xs`
- `sm`
- `md`
- `lg`
- `xl`
- `xxl`
- `card`

## Typography

Use semantic roles instead of ad hoc font sizes:

- `hero`
- `title`
- `heading`
- `subheading`
- `body`
- `bodyMedium`
- `caption`
- `captionMedium`
- `small`
- `smallMedium`
- `mono`

Favor readable hierarchy and avoid oversized decorative type in core study flows.

## Color

Key color roles:

- `primaryText`
- `secondaryText`
- `tertiaryText`
- `separator`
- `hoverBackground`
- `pressedBackground`
- `selectedBackground`
- `studyAccent*`
- semantic feedback colors for success, warning, error, and info

Use `.foregroundStyle(...)` in SwiftUI instead of `.foregroundColor(...)` where possible.

## Components

Before creating a new reusable UI element, check:

- `Revu/Revu/Views/Common/NotionStyleComponents.swift`
- existing app-level components under `Views/Common/`

Prefer composition over one-off styling.

## Interaction Rules

- hover, pressed, focus, and disabled states must be visible
- state changes should not cause layout shift
- use motion sparingly and only when it improves orientation
- SF Symbols are the default icon set

## Accessibility

- keep contrast high enough to preserve readability in both light and dark appearance
- rely on semantic typography so Dynamic Type remains coherent where supported
- avoid encoding meaning with color alone

## Practical Rule

If a new screen needs custom spacing, surface styling, or typography that does not map cleanly to the current tokens, update the design system first instead of scattering local exceptions.
