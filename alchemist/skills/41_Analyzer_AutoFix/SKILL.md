---
name: Analyzer Auto-Fix Loop
description: Drive `flutter analyze` to ZERO under very_good_analysis with minimal toil — format, dart fix, analyze, categorize, auto-resolve mechanical issues, loop until clean. Use when the analyzer reports warnings/infos/errors, before any stage gate, or when a CI lint check fails. Trigger on "fix analyzer", "make analyze pass", "clean up lints", "zero warnings".
when_to_use: Run after any code-producing stage and before its exit gate, since CONVENTIONS §7 (Definition of Done) requires `flutter analyze` to be clean. Invoked directly by Self-Healing CI (#33) and Maintenance (#32) as the universal lint gate. For a single tricky lint that needs design judgment, fix it by hand; for the bulk mechanical sweep, use this loop.
---

# Analyzer Auto-Fix Loop

The universal lint gate. Every stage in [`../../references/PIPELINE.md`](../../references/PIPELINE.md)
must leave `flutter analyze` at **zero issues** under `very_good_analysis` before its
exit gate is green — that is [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md) **§7 Definition of Done**.

This skill does the boring 90%: it formats, applies every safe automated fix, re-analyzes,
categorizes what's left, and loops — so a human only ever looks at the handful of issues
that genuinely need judgment.

## When to run

- After any stage that writes Dart (build, test, refactor) — before claiming the gate.
- When `flutter analyze` (or the CI lint job) reports anything that isn't `0 issues found`.
- As the first step of Maintenance (#32) and Self-Healing CI (#33).

## The loop

```
dart format .                 # canonical formatting (whitespace, trailing commas)
dart fix --apply              # bulk automated lint fixes (const, ordering, etc.)
loop up to N times:
  flutter analyze             # collect remaining issues
  if 0 issues  -> DONE (clean)
  dart fix --apply            # fix what newly became fixable
  flutter analyze (recount)
  if count did not drop -> BREAK (no more progress is automatable)
report before/after counts + remaining manual list
```

The script [`scripts/analyze_fix.sh`](scripts/analyze_fix.sh) implements exactly this.
Run it from the package root:

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/analyze_fix.sh"        # default 5 iterations
bash "${CLAUDE_SKILL_DIR}/scripts/analyze_fix.sh" 8      # bound to 8 iterations
```

It exits `0` only when the analyzer is clean, non-zero if issues remain (so it doubles
as a CI gate). It is defensive: if `flutter`/`dart` are not on `PATH` it says so and exits
without pretending to pass.

### Escaping infinite loops

`dart fix` is not guaranteed to make progress every pass, and a fix for one lint can surface
another. Two hard stops prevent spinning:

1. **Iteration cap** `N` (default 5) — the loop never runs more than N analyze passes.
2. **Progress check** — if an iteration does not *reduce* the issue count, stop. Anything
   still present is, by definition, not automatable; surface it for human review.

Never edit source in a `while true` based on analyzer output without a cap.

## Categorize before you touch anything

After the automated sweep, classify each remaining issue into one of three buckets. This is
the judgment the script can't make — you do it from the analyzer output.

| Bucket | Meaning | Action |
|---|---|---|
| **SAFE / mechanical** | Deterministic single-correct fix; `dart fix` knows it | Already applied by the loop; if any leak through, apply by hand |
| **GUIDED** | Mechanical *shape* but needs a tiny local choice (a name, a const value) | Fix inline, keep the diff small, no behavior change |
| **JUDGMENT** | Implies API/architecture change or a real decision | **Do not auto-fix.** List it and escalate to the human |

The full mapping lives in [`templates/lint_playbook.md`](templates/lint_playbook.md). Load it
when you need to decide a bucket.

### Safe to auto-fix (representative)

These are pure-mechanical; `dart fix --apply` resolves them and the loop will clear them:

- `prefer_const_constructors`, `prefer_const_declarations`,
  `prefer_const_literals_to_create_immutables` — insert `const`.
- `require_trailing_commas` — `dart format` adds them.
- `directives_ordering` — reorder/sort imports & exports.
- `cascade_invocations` — collapse repeated receiver into `..` cascade.
- `avoid_redundant_argument_values` — drop args equal to the default.
- `unnecessary_const`, `unnecessary_new`, `unnecessary_this`, `unnecessary_late`.
- `prefer_final_locals`, `prefer_final_fields`, `unnecessary_string_interpolations`.
- `sort_constructors_first`, `sort_unnamed_constructors_first`, `sort_child_properties_last`.

### Needs human judgment (never auto-fix)

These look like lints but the "fix" is a decision. Surface them; do not rewrite blindly:

- `avoid_dynamic_calls` / removing `dynamic` — implies a real type (API redesign).
- `public_member_api_docs` — requires writing *correct* prose, not a stub.
- `use_build_context_synchronously` — needs a `mounted` guard or restructured async flow.
- `avoid_catches_without_on_clauses` — which exception type is correct is domain knowledge.
- `one_member_abstracts`, `prefer_mixin`, design-shape lints — architectural call.
- `lines_longer_than_80_chars` on a URL/string that can't wrap — may warrant an inline ignore.
- Any **error** severity (not warning/info) — usually a genuine bug; read it, don't suppress it.

> Suppressing a lint (`// ignore:` / `// ignore_for_file:`) is a JUDGMENT action and must
> carry a one-line reason. Generated files (`*.g.dart`, `*.freezed.dart`, …) are already
> excluded in `analysis_options.yaml` — never add ignores there.

## very_good_analysis specifics

- The baseline is `package:very_good_analysis/analysis_options.yaml`, layered with the house
  `analysis_options.yaml` (see `06_Flutter_Architecture/templates/`). It is strict by design:
  `strict-casts`, `strict-inference`, `strict-raw-types`, plus `avoid_print`,
  `public_member_api_docs`, `require_trailing_commas`.
- `flutter analyze` reports three severities: **error**, **warning**, **info**. §7 DoD = **all**
  at zero, not just errors.
- `dart fix` only applies fixes for lints that have a registered automated fix; many
  very_good lints are detect-only and land in the GUIDED/JUDGMENT buckets.
- The custom_lint plugin (riverpod_lint) runs through the analyzer too. Its issues are almost
  always JUDGMENT (provider scope, ref misuse) — read them, don't suppress.

## Parsing `flutter analyze` output

The machine-friendly lines look like:

```
   info • Prefer const with constant constructors • lib/main.dart:12:14 • prefer_const_constructors
warning • The value of the field '_x' isn't used • lib/foo.dart:8:3 • unused_field
  error • Undefined name 'bar' • lib/foo.dart:20:5 • undefined_identifier
```

Per issue, extract: **severity** (1st field), **message**, **file:line:col**, **lint rule**
(last field, after the final `•`). The closing summary line is `N issues found.` or
`No issues found!`. The script greps for ` • ` lines and the count; when reading output
yourself, key off the trailing rule name to pick the bucket from the playbook.

## Reporting

After the loop, produce the report from [`templates/analyze_report.md`](templates/analyze_report.md):

1. **Before / after counts** by severity (error / warning / info) and total.
2. **Fixed automatically** — count and the rules that were cleared.
3. **Remaining — manual** — every JUDGMENT issue as `severity • rule • file:line` with a one-line
   "why it needs you" note, so the human can act without re-running anything.
4. **Verdict** — `CLEAN ✅` (zero issues) or `BLOCKED` with the manual count.

A stage gate is green only on `CLEAN`. If issues remain, the stage stays open (per the
Master Orchestrator loop) until the manual list is resolved.

## Output discipline

- Show the before→after delta first; it's the headline.
- Never claim "analyze passes" unless the script exited `0` / output is `No issues found!`.
- Keep auto-fix diffs reviewable: format + `dart fix` only; no opportunistic refactors mixed in.
- Escalate JUDGMENT issues with file:line and the rule name, never as a vague "some lints remain".

See [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md) §7 for the Definition of Done this gate enforces.
