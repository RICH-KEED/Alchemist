---
name: UI UX Planning
description: Turn a PRD into the app's UX blueprint — information architecture, navigation model, screen inventory, user flows, and low-fi wireframes. Use after Product_Planning (stage 02) when you have docs/PRD.md and need to decide what screens exist, how users move between them, and which Material 3 navigation pattern fits — before any design or code. Produces docs/UX.md.
when_to_use: Trigger on "plan the UX", "what screens do we need", "map the user flows", "information architecture", "navigation structure", "wireframes", or when the orchestrator advances stage 03. Requires docs/PRD.md. If the user only wants visual styling/theming, send them to stage 04 instead.
---

# UI/UX Planning (Stage 03)

Take `docs/PRD.md` and turn it into the **UX blueprint** the rest of the pipeline builds against: information architecture (IA), a navigation model, a screen inventory, user flows, and low-fidelity wireframes. House style lives in [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md); the pipeline map is in [`../../references/PIPELINE.md`](../../references/PIPELINE.md).

You are designing **structure and behavior**, not pixels. No colors, no final spacing — that is stage 04 (Design System). Your job is: *what screens exist, what each is for, how users reach them, and what every screen does in all of its states.*

**Output artifact:** `docs/UX.md` (use [`templates/UX.md`](templates/UX.md)).
**Exit gate:** every MVP user story maps to at least one screen **and** a user flow. The coverage matrix at the bottom of `docs/UX.md` proves it — no story left unmapped.

`docs/UX.md` is consumed by: **04** (component specs per screen), **06** (feature folders mirror the IA), **07** (go_router routes come straight from the screen inventory's `Route` column).

---

## Inputs you need

1. `docs/PRD.md` — read it fully. Pull out: personas, the MVP user-story list, MVP scope boundary (what's explicitly out), and success metrics.
2. If `docs/PRD.md` is missing, stop and ask for it (or back up to stage 02). Do not invent product scope here.

---

## The method (run in order)

### 1. Derive the screen inventory from user stories

Go story by story. Each "As a <persona>, I want to <action>…" implies a place where that action happens. Group related actions onto one screen; split when a screen would carry two unrelated jobs.

- Name screens by **job**, not widget: `ItemListScreen`, `ItemDetailScreen`, `AddItemScreen` — not "the list page".
- Assign each screen a **route** now (`/`, `/items`, `/items/:id`, `/items/new`, `/settings`). These become go_router paths in stage 07, so use real path syntax including `:params`.
- Note **key components** per screen at a coarse level (list, FAB, search bar, form, bottom sheet) — enough for stage 04 to spec, not a full design.
- Mark each screen's **entry points** (which other screens or system events lead here — deep link, notification, nav tab).

Fill the **Screen Inventory** table in the template: `Screen | Purpose | Route | Key components | States | Stories covered`.

### 2. Design the information architecture & navigation model

Decide how screens relate hierarchically (top-level destinations vs. detail/nested vs. modal), then pick the Android Material 3 navigation pattern. Choose deliberately:

| Pattern | Use when | Material 3 component |
|---|---|---|
| **Bottom navigation bar** | 3–5 top-level, equally important destinations, frequent switching | `NavigationBar` |
| **Navigation drawer** | 5+ destinations, or secondary/infrequent ones (settings, help, account) | `NavigationDrawer` (modal on phone) |
| **Tabs** | sibling views *within* one destination (e.g. "Active / Done") | `TabBar` under an `AppBar` |
| **Nested / push** | detail screens, drill-down, multi-step flows | pushed routes, `Back` returns |
| **Modal** | focused, interruptive tasks (create/edit, confirm, pick) | full-screen dialog or bottom sheet |

Material 3 / Android norms to honor:
- **2–5 destinations → `NavigationBar`.** Fewer than 2 doesn't need a bar; more than 5 → drawer or rethink the IA.
- The **back button** (system + predictive back) must always do the obvious thing; never trap the user. Top-level destinations are *not* on the back stack of each other.
- Don't mix a bottom bar **and** a drawer for the same level of navigation — pick one primary model.
- A **FAB** is for the screen's single most important constructive action (usually "create"); at most one per screen.
- Keep navigation **flat where possible** — deep hierarchies are hard to reach on a phone.

Produce the **Navigation map** in the template: list top-level destinations, what hangs off each (nested routes), and where modals/sheets attach. This is the source of truth for stage 07's router tree.

### 3. Write user flows

For each MVP story (or a small set of related ones), write the path from entry to outcome **including the unhappy paths**. Use the arrow notation:

```
Home → Tap FAB → AddItem → fill form → Save
  → success: Home (list updated, snackbar "Added")
  → validation error: stay on AddItem (inline field errors)
  → network error: stay on AddItem (retry banner, draft preserved)
```

Every flow must state: the **entry point**, the **happy path**, and the **success + error/empty/offline branches**. Flows that touch the network must say what happens when it fails — this feeds stages 14 (resilience) and 15 (error handling).

### 4. Design the UX states up front (don't bolt them on later)

For **every screen that loads or submits data**, decide all four async states now, in the inventory's `States` column. This is a house rule (CONVENTIONS §4) and the contract stage 16 implements:

- **Loading** — skeleton/shimmer, not a bare spinner where a list will appear.
- **Data** — the normal, populated view.
- **Empty** — first-run / no-results: explain what's missing and offer the primary action (e.g. "No items yet — tap + to add one").
- **Error** — human message + a **Retry**; never a raw exception.
- Plus **offline** where relevant (cached data + a banner) — feeds stage 14.

Designing these here means stage 16 has nothing to invent and no screen ships with a "TODO: empty state".

### 5. Map every MVP story → screen(s) → flow (the gate)

Fill the **Story → Screen coverage matrix**. One row per MVP story; columns: `Story | Screen(s) | Flow | Notes`. **The gate passes only when every MVP story has a screen and a flow.** If a story has no home, you're missing a screen — add it. If a screen serves no story, question whether it's MVP (move to "later" or cut).

---

## Low-fidelity wireframe guidance

Wireframes here are **grayscale boxes**: layout regions, content priority, and reach — no real visuals. For each key screen, sketch (in text, ASCII, or Pencil):

- **Layout regions** top→bottom: `AppBar` / scrollable content / bottom nav or actions. State what's fixed vs. scrolls.
- **Content priority** — most important content/action highest and largest; secondary actions in overflow.
- **Thumb reach** — primary action in the bottom/center "easy reach" zone (FAB, bottom sheet confirm), not top corners. Top app bar is for navigation/overflow, not the main action.
- **Touch targets** — every interactive element ≥ **48dp**; adequate spacing so neighbors aren't mis-tapped.
- **One primary action per screen.** Everything else is visually subordinate.
- Show the **empty and error** variants as their own mini-wireframes, not just the happy "data" view.

Run each screen through [`templates/wireframe_checklist.md`](templates/wireframe_checklist.md) before calling it done.

### Optional: wireframe in Pencil

**If the Pencil MCP is connected**, you may produce low-fi wireframes as a `.pen` file instead of ASCII:

1. `get_editor_state(include_schema: true)` to load the schema.
2. Create one frame per screen at a phone size (e.g. 360×800), using **grayscale fills only** — this is lo-fi; real color/type is stage 04's job.
3. Lay out regions as plain rectangles + text labels; add the empty/error variants as sibling frames.
4. `get_screenshot` to eyeball, then reference the `.pen` path from `docs/UX.md`.

Pencil is **optional** — ASCII/markdown wireframes in `docs/UX.md` fully satisfy this stage. Don't block on it.

---

## Writing docs/UX.md

Use [`templates/UX.md`](templates/UX.md) and fill every section: IA overview, Navigation map, Screen Inventory table, User Flows, and the Story→Screen coverage matrix. Keep it skimmable — tables and arrow-notation flows beat prose. Reference any Pencil wireframe by path.

## Exit gate checklist

Before handing off to stage 04, confirm:

- [ ] Every MVP story appears in the coverage matrix with a screen **and** a flow.
- [ ] Every screen has a route (real path syntax) and a defined set of states.
- [ ] One navigation model chosen and justified; destination count fits Material 3 norms (2–5 for a bottom bar).
- [ ] Each data screen lists loading / data / empty / error (+ offline where relevant).
- [ ] Each flow shows entry + happy path + error/empty branches.
- [ ] No orphan screens (every screen serves ≥ 1 story) and no orphan stories.

When green, hand `docs/UX.md` to stages **04, 06, 07** and tell the orchestrator the gate passed.
