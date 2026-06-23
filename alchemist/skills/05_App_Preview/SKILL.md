---
name: App Preview
description: Produce a visual preview/prototype of the app before building it, so look & feel can be approved early. Use after the design system exists (stage 04) to create .pen mockups, a runnable Flutter widget gallery, and device screenshots for stakeholder sign-off. Trigger on "show me what it'll look like", "make a prototype/mockup", "preview the app", or "get the design approved".
when_to_use: Stage 05 of the pipeline — right after the design system (04) and before writing any feature code (06+). Use it to de-risk the build by getting eyes on the real look & feel first. Skip it only for throwaway spikes; for anything shipping, the look-and-feel sign-off here is a hard gate.
---

# App Preview

You turn the **UX map (03)** and the **design system (04)** into something a human can *look at and approve* — before a single feature is built. Approving look & feel here is far cheaper than discovering it's wrong after stage 17.

Stay consistent with the house style in [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md). Everything you preview must use the **theme + `AppTokens` from stage 04** — no ad-hoc colors or spacing. If stage 04's `lib/app/theme/*` isn't in place yet, stop and get it first; you cannot preview a design system that doesn't exist.

**Inputs:** `docs/UX.md` (screen inventory, flows), `.pen` design kit + `lib/app/theme/*` (tokens, color schemes, typography).
**Output:** everything lands in `previews/` at the project root.
**Exit gate:** stakeholder sign-off on look & feel (use [`templates/preview_signoff.md`](templates/preview_signoff.md)).

---

## Three preview modes — pick what fits the moment

| Mode | What it is | Best for | Fidelity | Cost |
|---|---|---|---|---|
| **(a) `.pen` mockups** | Static screens designed in Pencil (+ Stitch if connected) | Earliest look, exploring layouts, async stakeholder review | High visual, zero interaction | Low |
| **(b) Widget gallery** | A runnable Flutter app (storybook-style) rendering *real* components/screens against the real theme | Proving the design *actually works in Flutter*, light/dark, real type rendering | Real pixels, tappable | Medium |
| **(c) Device screenshots** | PNGs captured from the gallery/app on a device or emulator | Sign-off artifacts, PRs, design tickets, the sign-off doc | Exact device output | Low once (b) exists |

Typical flow: sketch in **(a)** → confirm direction → build **(b)** to prove it in Flutter → capture **(c)** for the sign-off packet. For a fast approval you can sign off on (a) alone, but **prefer reaching (b)** before the gate — a mockup that never rendered in Flutter hides real problems (font metrics, overflow, dark mode, touch targets).

---

## Mode (a): `.pen` mockups via Pencil

Pencil MCP is connected now. `.pen` files are encrypted — only ever touch them through `mcp__pencil__*` tools, never Read/Grep.

1. **Get oriented.** Call `mcp__pencil__get_editor_state({ include_schema: true })` to load the schema (required before any other Pencil call) and see the active file/selection.
2. **Reuse the design kit.** Stage 04 produced a `.pen` design kit with components. List them with `mcp__pencil__batch_get({ patterns: [{ reusable: true }], readDepth: 2 })` and compose screens from those components so mockups match the real tokens — don't redraw primitives.
3. **Pull the real tokens.** `mcp__pencil__get_variables(...)` gives the design variables/themes; build screens bound to those variables so light/dark switch correctly.
4. **Build the key screens** named in `docs/UX.md` (one frame per screen) using `mcp__pencil__batch_design`. Cover the MVP flow end-to-end, not just a hero screen. If you don't have the `batch_design` schema, call `get_editor_state` first.
5. **Check structure** with `mcp__pencil__snapshot_layout({ problemsOnly: true })` to catch clipping/overflow before sharing.
6. **Share for review.** `mcp__pencil__get_screenshot` for a quick inline look (use sparingly — one per finished screen, not per edit); `mcp__pencil__export_nodes({ format: "png" })` to write image files into `previews/pen/` for the sign-off packet. Use `format: "pdf"` to bundle all screens into one multi-page review document.
7. **Iterate** against feedback — change the `.pen`, re-export, repeat until direction is approved.

## Mode (a, continued): Google Stitch (prompt → UI) — *if connected*

If a **Google Stitch MCP** is connected (it may be added later), you can generate first-draft screens from a text prompt to accelerate exploration:
- Prompt Stitch with the screen intent + the design language from stage 04 (seed color, type, vibe) so output is on-brand.
- Treat Stitch output as a **starting sketch**, not the source of truth: bring it back into `.pen` (mode a) or translate it into real widgets (mode b) so it's bound to the actual `AppTokens`.
- If Stitch is **not** connected, skip this entirely and design in Pencil. Never block on it.

---

## Mode (b): runnable widget gallery (storybook-style)

This is the highest-value preview because it renders **real Flutter widgets against the real theme** — what you approve is what you ship.

1. Copy [`templates/widget_gallery.dart`](templates/widget_gallery.dart) into the project (e.g. `previews/widget_gallery.dart`, or `lib/preview/` if you want it to live with the app).
2. It builds a `MaterialApp` wired to the project's **light & dark themes** (`appTheme()` / `appThemeDark()` from stage 04) with a dark-mode toggle, and renders a list of named **stories** (`label → builder`). Each story is a real widget on a real `Scaffold`.
3. Add a story per key screen from `docs/UX.md` and per notable component, reusing the real screen/widget classes as they get built. Early on, use the sample stories (button set, card, sample screen, token swatch sheet) as placeholders proving the theme.
4. Run it: `flutter run -t previews/widget_gallery.dart` (or set it as the temporary entrypoint). Flip the dark toggle and walk every story.
5. **Heavier alternative:** for a richer storybook (knobs, device frames, addons) use the **`widgetbook`** package. The template notes this in a comment. Start dependency-light; graduate to `widgetbook` only if the team wants the extra tooling.

The gallery depends on stage 04's `appTheme()`/`appThemeDark()` and `AppTokens`. If their names differ in this project, adjust the import and theme calls at the top of the template — keep everything else.

---

## Mode (c): device screenshots

Capture exact device output for the sign-off packet and design tickets. Two ways:

- **Quick / manual:** `flutter run -t previews/widget_gallery.dart` on an emulator or device, walk the stories in light **and** dark, and capture frames (`flutter screenshot --out=previews/shots/<name>.png`, or the IDE/emulator screenshot button).
- **Repeatable / golden-style:** add a widget test that pumps each story inside the real theme and uses `flutter_test`'s golden machinery (or `alchemist`) to write PNGs under `previews/golden/`. Run with `flutter test --update-goldens` to regenerate. This makes previews reproducible and doubles as a visual-regression baseline later (ties into stage 20 Testing).

Save shots into `previews/shots/` (manual) or `previews/golden/` (golden). Name them `<screen>_<light|dark>.png` so the sign-off doc can reference them.

---

## Suggested `previews/` layout

```
previews/
├── pen/                # exported .pen screens (PNG/PDF) from mode (a)
├── widget_gallery.dart # the runnable gallery (mode b)
├── shots/              # manual device screenshots (mode c)
├── golden/             # golden-style reproducible screenshots (mode c)
└── SIGNOFF.md          # filled-in copy of templates/preview_signoff.md
```

---

## Sign-off checklist (the exit gate)

Walk the stakeholder through a filled copy of [`templates/preview_signoff.md`](templates/preview_signoff.md). The gate is green only when every section is checked and the approver has signed/dated. In short, confirm: **brand** matches, **visual hierarchy** reads correctly, **spacing/rhythm** follows the token scale, **dark mode** is first-class (not an afterthought), **every key screen** from `docs/UX.md` is shown, the **motion feel** is described/acceptable, and **contrast/accessibility** passes. Record the sign-off (who + date) so the orchestrator can mark stage 05 done in `.flutter-pipeline/STATE.md`.

## How this de-risks later stages

- **06 Architecture / 17 Responsive:** real screens previewed in the gallery surface layout/overflow problems before they're baked into feature code.
- **04 Design System:** rendering real widgets validates the tokens actually produce the intended look — cheaper to fix tokens now than across 20 screens later.
- **16 Loading_States / 15 Error_Handling:** add loading/empty/error variants as stories to confirm all four async states look right *before* wiring data.
- **09 Animation:** the gallery is where motion feel gets a first gut-check.
- **20 Testing:** golden-style screenshots become the visual-regression baseline.

A signed-off look & feel means every downstream build stage is implementing an **approved** target, not guessing.

See the full stage map in [`../../references/PIPELINE.md`](../../references/PIPELINE.md) and the house style in [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md).
