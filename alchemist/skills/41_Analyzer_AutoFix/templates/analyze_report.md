# Analyzer Auto-Fix Report

> Output of the Analyzer Auto-Fix Loop (#41). Enforces `../../references/CONVENTIONS.md`
> §7 (Definition of Done = `flutter analyze` clean under very_good_analysis).
> Fill every `<…>`. Delete this blockquote in the final report.

**Package:** `<path/to/package>`
**Date:** `<YYYY-MM-DD>`
**Iterations run:** `<n>` of `<MAX>`
**Invoked by:** `<#41 direct | #32 Maintenance | #33 Self-Healing CI>`

---

## Before → After

| Severity | Before | After | Cleared |
|---|---:|---:|---:|
| error   | `<e0>` | `<e1>` | `<…>` |
| warning | `<w0>` | `<w1>` | `<…>` |
| info    | `<i0>` | `<i1>` | `<…>` |
| **Total** | **`<t0>`** | **`<t1>`** | **`<fixed>`** |

## Fixed automatically (`dart format` + `dart fix --apply`)

Cleared `<fixed>` issues across these rules:

- `<rule>` × `<count>`
- `<rule>` × `<count>`
- `<…>`

## Remaining — needs human judgment

> If empty, write `None — CLEAN.` Otherwise one row per issue, bucketed JUDGMENT/GUIDED
> per `lint_playbook.md`. Each row tells the human exactly what to do, no re-run needed.

| Severity | Rule | Location | Why it needs you / action |
|---|---|---|---|
| `<error\|warning\|info>` | `<lint_rule>` | `<lib/foo.dart:LINE>` | `<one-line reason / decision>` |
| `<…>` | `<…>` | `<…>` | `<…>` |

## Verdict

`<CLEAN ✅  — 0 issues, §7 DoD satisfied; stage gate may go green.>`
`<— or —>`
`<BLOCKED  — <n> manual issue(s) above must be resolved before the gate passes.>`

---

### Notes / suppressions added

> List any `// ignore:` added this pass, each with its justification. None is the good case.

- `<file:line>` — `// ignore: <rule>` — `<reason>`
- `<none>`
