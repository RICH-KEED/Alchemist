---
name: Codebase Onboarding
description: Point at an existing Flutter repo and get a complete architecture map, convention analysis, risk hotspots, and "how to add X" guide — a 15-minute ramp doc for any team member. Use when joining a new project, inheriting a codebase, reviewing an unfamiliar repo, or onboarding a teammate. Produces the onboarding report from templates/onboarding_report_template.md.
when_to_use: Trigger on "onboard me to this codebase", "explain this project", "how is this app structured", "what conventions does this repo use", "give me a ramp doc for <repo>", "new teammate onboarding", "reverse-engineer this Flutter app", or "audit this codebase against pipeline conventions".
---

# Codebase Onboarding (Roadmap #36)

Your job is to produce a **single-page ramp doc** that lets anyone — a new hire, a contractor, or
your future self — understand a Flutter codebase in about 15 minutes. You work in two modes,
auto-detected from the repo. House style: [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md).
Pipeline conventions: [`../../references/PIPELINE.md`](../../references/PIPELINE.md).

> A ramp doc is not a code dump. It surfaces **what matters**: architecture, conventions, risks,
> and the three workflows they'll use every day.

---

## 1. Mode detection

Before analysis, pick your mode. One question decides:

| Signal | Mode |
|---|---|
| Project follows `lib/features/<name>/{data,domain,application,presentation}` layout, uses Riverpod + freezed + go_router + Material 3, has `very_good_analysis` in `analysis_options.yaml` | **Greenfield** — pipeline-aligned |
| Any deviation from the above — different state management, routing, folder layout, lint package, or a pre-3.x Dart codebase | **Brownfield** — reverse-engineer what's actually there |

**Greenfield** means: compare against pipeline conventions, note where the project *is* aligned,
and flag any small gaps. The report becomes a "conformance snapshot."

**Brownfield** means: ignore the pipeline template. Discover the real conventions from the code,
document them honestly, and flag where they *differ* from pipeline defaults — but never suggest a
rewrite unless asked.

---

## 2. Analysis steps

Run in order; each step feeds the next. Use parallel agents for 2a–2c.

### 2a. Project tree
`ls -R lib/ | head -200` — map folder structure, identify bootstrap (`main.dart`),
app wiring (`app/`), cross-cutting (`core/`), feature inventory (layer fill per feature),
and `test/` structure.

### 2b. pubspec.yaml
`cat pubspec.yaml` — extract SDK constraints, state management, routing, networking,
codegen packages, lint package, test packages, and any deprecated deps.

### 2c. Routing config
Locate router files — identify router type, route count, deep-link config,
guards/redirects, and naming conventions.

### 2d. State management survey
`rg -l "riverpod|Provider|Notifier|StateNotifier|BlocProvider|Cubit|ChangeNotifier|setState" lib/ | head -30`
— identify primary mechanism, provider/bloc count, layer separation, widget logic leaks.

### 2e. Theming & UI
Check `app/theme/` or equivalent — Material version, ColorScheme, ThemeExtension tokens,
dark mode, font choices, spacing scale.

### 2f. Error handling
`rg -l "sealed class Failure|class Failure|class Result|Either<" lib/ | head -20`
— document the actual pattern: exception mapping, global boundary, UI surfacing.

### 2g. Testing
`find test/ -name "*.dart" | head -40` — count tests by category, check coverage config,
identify mocking strategy. Run `flutter test --no-pub 2>&1 | tail -5` for current status.

---

## 3. Output: the onboarding report

Write to the path the user specifies (default: `docs/ONBOARDING.md` in the repo) using the
template at [`templates/onboarding_report_template.md`](templates/onboarding_report_template.md).
Fill every section; if a section doesn't apply, say "Not present" with a one-line reason.

1. **Architecture overview** — Mermaid diagram of feature layers, data flow, external deps.
2. **Dependency inventory** — table by concern, with versions and deprecation flags.
3. **Conventions cross-reference** — pipeline convention vs. project reality with ✅⚠️❌.
   For brownfield, this is the most valuable section — "forget the standard stack; here's reality."
4. **Risk hotspots** — table: Risk, Location, Severity (🔴🟡🟢), Mitigation.
5. **How to add a feature** — numbered walkthrough with real paths and class names.
6. **How to add a screen** — exact routing snippet from this project.
7. **Key files to know** — 10–15 files with one-line descriptions, starting from `main.dart`.

---

## 4. Key differentiators

**Convention delta detection** — always compute pipeline vs. project reality. Example:
```
Pipeline says: Riverpod 2.x + codegen
Project uses:   Bloc 8.x + manual providers
Delta:          ❌ Different state management — learn Bloc, not Riverpod.
                See lib/core/di/injection_container.dart for setup.
```

**Practical walkthroughs** — never give generic advice. Use real paths, real class names, and
real snippets. If the project uses `BlocBuilder<CartCubit, CartState>`, show that exact pattern.

**Brownfield honesty** — document divergences without judgment. "Here's what this project does"
not "here's what it did wrong." Risk hotspots are the only place severity matters:
a missing test suite is 🔴 regardless of project age.

---

## 5. Safety rails

- **Read-only.** Never modify the onboarded project. Report goes to `docs/ONBOARDING.md` or inline.
- **No secrets exposure.** Redact API keys/tokens; note config exists, never paste values.
- **Time box.** ~15 minutes wall time. Skip hung steps (e.g. broken `flutter test`) with "could not run."
- **Honest scope.** For >200 Dart files, sample one representative feature deeply; note the strategy.
- **Version awareness.** Flag pinned-to-older SDK constraint; estimate migration effort.

---

## 6. Modes in practice

### Greenfield fast path

Clean pipeline output (all ✅ in conventions cross-reference) → **compact report**: skip risk
hotspots, focus on architecture diagram, feature inventory, add-feature walkthrough, key files.
Still include the conventions cross-reference as a conformance snapshot.

### Brownfield common patterns

| Pattern | Handling |
|---|---|
| No tests | 🔴 risk; note "budget 2–4 weeks to reach 60% on critical paths" |
| setState everywhere | ⚠️ convention; note migration path but don't prescribe unless asked |
| Navigator 1.0 | Document actual pattern; note go_router migration as a separate task |
| No error handling | 🔴 risk; document where exceptions propagate uncaught |
| Deprecated packages | List each with replacement and migration effort |
| >500-line files | 🔴 maintainability risk; flag each |

---

## 7. Pairing

| Skill | When |
|---|---|
| #01 Master Orchestrator | Pipeline STATE.md exists — cross-reference reported stage with reality |
| #06 Flutter Architecture | Project needs re-architecting based on findings |
| #15 Error Handling | Error patterns missing or inconsistent |
| #20 Testing | Coverage absent or needs strategy |
| #37 Build Doctor | Project fails to build/analyze during onboarding |

---

See the report template at [`templates/onboarding_report_template.md`](templates/onboarding_report_template.md),
pipeline conventions at [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md), and the
pipeline stage map at [`../../references/PIPELINE.md`](../../references/PIPELINE.md).
