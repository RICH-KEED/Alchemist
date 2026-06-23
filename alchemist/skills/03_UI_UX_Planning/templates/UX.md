# UX Blueprint — <app name>

> Stage 03 artifact. Derived from `docs/PRD.md`. Consumed by stages 04 (design system), 06 (architecture), 07 (navigation/go_router).
> Conventions: [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md). Status: draft | gate-passed.

## 1. Information Architecture (IA) overview

One paragraph: how the app is organized at the top level and why. List the **top-level destinations** and what conceptually lives under each.

- **Top-level destinations:** <e.g. Home, Browse, Profile>
- **Navigation model chosen:** <NavigationBar | NavigationDrawer | Tabs | hybrid> — _because_ <justification: # of destinations, frequency, Material 3 norm>.
- **Modals / sheets:** <which focused tasks open as full-screen dialog or bottom sheet>

```
App
├── Home            (/)              [top-level]
├── Items           (/items)        [top-level]
│   ├── Detail      (/items/:id)    [nested / push]
│   └── Add         (/items/new)    [modal]
└── Settings        (/settings)     [top-level | drawer]
```

## 2. Navigation map

The source of truth for stage 07's `go_router` tree.

| Destination | Route | Reached from | Type | Notes |
|---|---|---|---|---|
| Home | `/` | app launch, bottom nav | top-level | start destination |
| Item list | `/items` | bottom nav | top-level | |
| Item detail | `/items/:id` | tap list item, deep link | nested (push) | back → list |
| Add item | `/items/new` | FAB on `/items` | modal (full-screen dialog) | back → list, discard confirm |
| Settings | `/settings` | bottom nav / drawer | top-level | |

- **Primary nav component:** <NavigationBar with N destinations>
- **Back behavior:** <how system/predictive back resolves at each level>
- **Deep links / App Links:** <which routes must resolve from a URL/notification — feeds stage 07>

## 3. Screen inventory

| Screen | Purpose | Route | Key components | States | Stories covered |
|---|---|---|---|---|---|
| HomeScreen | <one-line job> | `/` | <list, FAB, search> | loading · data · empty · error | S1, S2 |
| ItemListScreen | <…> | `/items` | <NavigationBar, list, FAB> | loading · data · empty · error · offline | S3, S4 |
| ItemDetailScreen | <…> | `/items/:id` | <header, actions, content> | loading · data · error | S5 |
| AddItemScreen | <…> | `/items/new` | <form, save, validation> | idle · submitting · success · error | S6 |
| SettingsScreen | <…> | `/settings` | <list, toggles> | data | S7 |

> `States` lists the async/UX states the screen must implement (CONVENTIONS §4). Stage 16 implements these — anything not listed here won't get built.

## 4. User flows

Notation: `Screen → action → Screen`, with `→ branch:` lines for success/error/empty/offline outcomes.

### Flow: Add an item (S6)
```
Items → Tap FAB → AddItem → fill form → Save (submitting)
  → success: Items (list updated, snackbar "Added")
  → validation error: stay on AddItem (inline field errors, no submit)
  → network error: stay on AddItem (retry banner, draft preserved)
```

### Flow: View item detail (S5)
```
Items → Tap row → ItemDetail (loading → data)
  → not found / deleted: ItemDetail (error state, "Back to list")
  → offline: ItemDetail (cached data + offline banner)
```

### Flow: First run / empty (S3)
```
App launch → Items (loading → empty)
  → empty: "No items yet — tap + to add one" + FAB highlighted
```

_Add one flow per MVP story or related story cluster. Every flow names its entry point, happy path, and error/empty/offline branches._

## 5. Story → Screen coverage matrix (the exit gate)

Every MVP story from `docs/PRD.md` must appear here with a screen **and** a flow. No blanks.

| Story | Description | Screen(s) | Flow | Notes |
|---|---|---|---|---|
| S1 | <As a user, I want …> | HomeScreen | "View home" | |
| S2 | <…> | HomeScreen, ItemListScreen | "Browse items" | |
| S3 | <…> | ItemListScreen | "First run / empty" | |
| S4 | <…> | ItemListScreen | "Refresh / offline" | |
| S5 | <…> | ItemDetailScreen | "View item detail" | |
| S6 | <…> | AddItemScreen | "Add an item" | |
| S7 | <…> | SettingsScreen | "Change settings" | |

**Gate:** ✅ every MVP story above has a screen + flow · no orphan screens · all data screens declare loading/data/empty/error.

## 6. Wireframes

Low-fi wireframes (ASCII below, or `.pen` reference). Each key screen run through `templates/wireframe_checklist.md`.

- Pencil wireframe file (optional): `<path/to/wireframes.pen>`

```
ItemListScreen (data)            ItemListScreen (empty)
┌─────────────────────┐          ┌─────────────────────┐
│ ≡  Items        🔍  │ AppBar   │ ≡  Items        🔍  │
├─────────────────────┤          ├─────────────────────┤
│ ▢ Item one          │          │                     │
│ ▢ Item two          │          │     (illustration)  │
│ ▢ Item three        │          │  No items yet —     │
│ ...                 │          │  tap + to add one   │
│                     │          │                     │
│                ( + )│ FAB      │                ( + )│
├─────────────────────┤          ├─────────────────────┤
│ [Home][Items][Me]   │ NavBar   │ [Home][Items][Me]   │
└─────────────────────┘          └─────────────────────┘
```
