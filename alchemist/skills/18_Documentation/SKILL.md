---
name: Documentation
description: Write the documentation that actually matters for a Flutter app — a strong README, Architecture Decision Records (ADRs), an architecture overview, a CONTRIBUTING guide, and dartdoc on public APIs. Use when a project needs onboarding docs, a record of why decisions were made, or generated API docs. Stage 18 of the pipeline.
when_to_use: Trigger on "write the README", "document this", "add an ADR", "record this decision", "set up dartdoc / dart doc", "write a contributing guide", or when stage 18 of the pipeline comes up. For repo hygiene (PR/issue templates, branching, commits) use skill 19_GitHub_Workflow instead.
---

# Documentation

You produce **docs people read once and trust forever**: a README that gets someone running the app in minutes, ADRs that capture *why*, an architecture overview tied to the layers in [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md), and dartdoc on every public API. House stack: Dart 3, `dart doc` (dartdoc).

Exit gate (PIPELINE stage 18): **public APIs documented; ADRs for key decisions.**

Documentation is not an afterthought — it is part of "done" (CONVENTIONS §7: *doc comment on every public API*). Docs live **next to the code** and change **in the same PR** as the code (ties to skill 19_GitHub_Workflow).

---

## What to produce (the docs that matter)

A Flutter app needs exactly these — no more:

| Doc | Lives at | Purpose |
|---|---|---|
| **README.md** | repo root | What it is, how to run/build it. The front door. |
| **docs/ARCHITECTURE.md** | `docs/` | The layer map (CONVENTIONS §2), data flow, key packages, where things go. |
| **docs/adr/NNNN-*.md** | `docs/adr/` | One significant decision per file. The *why*. |
| **CONTRIBUTING.md** | repo root | How to set up, branch, test, and open a PR (links skill 19/20). |
| **dartdoc `///`** | in source | Public API reference, generated with `dart doc`. |

Templates ship in this skill:
- [`templates/README.md`](templates/README.md) — app README skeleton.
- [`templates/adr/0001-record-architecture-decisions.md`](templates/adr/0001-record-architecture-decisions.md) — the first ADR.
- [`templates/adr/ADR_TEMPLATE.md`](templates/adr/ADR_TEMPLATE.md) — blank ADR.
- [`templates/dartdoc_guide.md`](templates/dartdoc_guide.md) — dartdoc conventions + good/bad examples.

---

## 1. The README

Copy `templates/README.md` to the repo root and fill it. A good Flutter README answers, in order:

1. **What & why** — one-paragraph description + a short feature list.
2. **Screenshots** — a slot near the top (phone light/dark). A picture sells the app.
3. **Getting started** — prerequisites, the **Flutter/Dart version** (pin it — match `pubspec.yaml` and `.tool-versions`/`fvm`), `flutter pub get`, `build_runner` if codegen is used, how to **run**, and how to run each **flavor** (`--flavor dev`, etc.).
4. **Project structure** — a short tree that mirrors CONVENTIONS §2, with a one-line gloss per top-level dir. Link to `docs/ARCHITECTURE.md` for depth — don't duplicate it.
5. **Testing** — `flutter test`, golden tests, coverage (points to skill 20_Testing).
6. **Build & release** — point to CI/CD and deployment (skills 21/22), don't inline secrets or signing keys.
7. **License** — name + link.

Keep the README skimmable. Anything longer than a screen of detail belongs in `docs/`.

---

## 2. Architecture overview (`docs/ARCHITECTURE.md`)

A single doc that lets a new contributor place any file. Tie it directly to CONVENTIONS, don't reinvent it:

- **The layers** — `presentation → application → domain ← data`, dependencies point inward (CONVENTIONS §2). State the rule: domain imports nothing; features don't import each other's internals.
- **Where things go** — a table: "a new screen → `features/<f>/presentation`", "a notifier → `application`", "an API call → `data` + a `domain` interface".
- **The contracts** — link the `Result`/`Failure` model (CONVENTIONS §5, owned by skill 15) and the Riverpod state contract (§6). Show one end-to-end slice (widget → notifier → repository → dio → mapper → domain) as the canonical example.
- **Key packages & why** — a short version of the stack table (CONVENTIONS §1): Riverpod, freezed, go_router, dio. Link CONVENTIONS as the source of truth rather than copying the whole table.
- **A diagram** — a simple ASCII or Mermaid diagram of the layers/data flow beats prose.

Rule of thumb: ARCHITECTURE.md explains *the system*; ADRs explain *a single decision*; dartdoc explains *a single API*.

---

## 3. Architecture Decision Records (ADRs)

An ADR captures a **significant, hard-to-reverse decision** and the reasoning behind it, so the team doesn't relitigate it in six months.

**When to write one:** choosing the backend (Supabase vs custom), state management, a routing strategy, an offline/sync approach, dropping a platform, a notable trade-off. *Don't* ADR trivial or easily-reversed choices (a lint rule, a variable name).

**Practice:**
- **One decision per file**, in `docs/adr/`, numbered `NNNN-kebab-title.md` (`0001-…`, `0002-…`). Numbers are immutable.
- Start with [`templates/adr/0001-record-architecture-decisions.md`](templates/adr/0001-record-architecture-decisions.md) — the meta-ADR that says "we use ADRs". Then copy [`templates/adr/ADR_TEMPLATE.md`](templates/adr/ADR_TEMPLATE.md) for each new one.
- **Format:** Status · Context · Decision · Consequences.
- **Status lifecycle:** `proposed → accepted` (or `rejected`). A later decision can mark an old one `superseded by ADR-00NN` — never edit the old ADR's decision; add a new ADR and link both ways. `deprecated` for decisions no longer relevant.
- ADRs are **append-only history**: accepted ADRs are immutable except their Status line. The record of a wrong-in-hindsight choice is *valuable* — keep it.
- Log the decision in the orchestrator's `.flutter-pipeline/STATE.md` decisions log with the ADR number and date (e.g. `2026-06-23: chose Supabase backend (ADR-0003)`).

---

## 4. dartdoc on public APIs

Every **public** API gets a `///` doc comment (CONVENTIONS §7). Full conventions and good/bad examples are in [`templates/dartdoc_guide.md`](templates/dartdoc_guide.md); the essentials:

- **First sentence is a self-contained summary** — it shows up in lists. Start with a verb/noun phrase, end with a period: `/// Fetches the current user's profile.`
- **Link other APIs with brackets** — `[ProfileRepository]`, `[fetchProfile]`. dartdoc resolves and hyperlinks them.
- **Reuse text with templates** — define once with `{@template name}…{@endtemplate}`, pull in with `{@macro name}`. Good for the same caveat repeated across overloads.
- **Show, don't just tell** — include a fenced `dart` code example for non-obvious APIs.
- **Document the contract, not the implementation** — params, return, what `Failure`s it can produce (CONVENTIONS §5), nullability, side effects.
- **Generate:** `dart doc .` → output in `doc/api/`. Wire it into CI (skill 21) so docs build cleanly; treat dartdoc warnings (broken `[links]`, missing docs on public members) as errors.

What this looks like, briefly:

```dart
/// Loads the profile for the signed-in user.
///
/// Returns [Ok] with the [Profile] on success, or [Err] with a
/// [NetworkFailure] / [UnauthorizedFailure] on failure — never throws.
///
/// ```dart
/// final result = await ref.read(profileRepositoryProvider).fetchProfile();
/// switch (result) {
///   case Ok(:final value): showProfile(value);
///   case Err(:final failure): showError(failure);
/// }
/// ```
Future<Result<Profile>> fetchProfile();
```

---

## 5. CONTRIBUTING.md

A short on-ramp for the next contributor (overlaps skill 19, which owns the `.github/` templates and branching/commit rules — link there, don't duplicate):

- Local setup: Flutter version (via `fvm`/`.tool-versions`), `flutter pub get`, `dart run build_runner build`.
- Run the analyzer/tests before pushing: `flutter analyze` (zero warnings — CONVENTIONS §7), `flutter test`.
- Branching & commit convention → point to skill 19.
- **Docs are part of the PR**: if you change a public API, update its dartdoc; if you make a significant decision, add an ADR; if you change the layout/flow, update `docs/ARCHITECTURE.md`. A PR that changes behavior but not the relevant doc is incomplete.

---

## What NOT to document

Bad docs are worse than none — they rot and mislead. Skip:

- **Obvious code.** `/// The user's name.` over `final String name;` adds nothing. Document *why* and *contracts*, not restatements.
- **Private members** — no public doc obligation; a `//` comment for genuinely tricky logic is fine.
- **The implementation in dartdoc** — document behavior/contract; the body can change freely.
- **Generated files** (`*.freezed.dart`, `*.g.dart`) — never hand-doc these.
- **Anything CONVENTIONS already owns** — link to it; a second copy will drift and §0 says CONVENTIONS wins.
- **Changelogs by hand** — derive from commits/tags (skill 19/21), don't maintain prose.

---

## Definition of done (stage 18)

- README runs a newcomer from clone → running app, with the Flutter version pinned and flavors covered.
- `docs/ARCHITECTURE.md` exists and matches the actual `lib/` layout (CONVENTIONS §2).
- ADRs exist for every key decision; `0001` establishes the practice; statuses are accurate.
- `CONTRIBUTING.md` exists and links skills 19/20.
- Every public API has a dartdoc comment; `dart doc .` builds with no warnings.
- Docs were updated **in the same PRs** as the code they describe.

See the house style in [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md) and the stage map in [`../../references/PIPELINE.md`](../../references/PIPELINE.md).
