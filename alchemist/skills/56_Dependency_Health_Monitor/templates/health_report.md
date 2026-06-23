# Dependency Health Report — <app name>

- **Generated:** <YYYY-MM-DD>
- **Source:** `pubspec.lock` (resolved) / `pubspec.yaml` (declared)
- **Flutter / Dart:** <flutter version> / <dart version>
- **Direct deps scored:** <n>   **Transitive flagged:** <n>   **Skipped (network):** <n>
- **Rubric:** [`health_rubric.md`](health_rubric.md)   **Conventions:** [`../../../references/CONVENTIONS.md`](../../../references/CONVENTIONS.md)

---

## Summary

| Tier | Count | Packages |
|---|---:|---|
| 🟢 Healthy | <n> | … |
| 🟡 Warn | <n> | … |
| 🔴 Risk | <n> | … |

- **Open advisories:** <n> (<list IDs or "none">)
- **Release gate:** ✅ pass / ❌ fail — <reason if fail>
- **Off-stack / duplicates:** <list or "none">

---

## Per-package scorecard (direct dependencies)

| Package | Current | Latest | Last publish | Pub pts | Popularity | Null-safe / Dart3 | Advisories | Size note | Score | Tier | Recommended action |
|---|---|---|---|---:|---:|:---:|---|---|---:|:---:|---|
| `dio` | 5.4.0 | 5.7.0 | 2026-04-12 | 140/160 | 99% | ✓ / ✓ | none | light | 88 | 🟢 | Minor bump in safe batch |
| `some_pkg` | 1.2.0 | 3.0.1 | 2024-08-01 | 90/160 | 41% | ✓ / ✓ | none | medium | 58 | 🟡 | Reviewed major upgrade (read CHANGELOG) |
| `old_pkg` | 0.4.0 | 0.4.0 | 2023-01-09 | 50/160 | 12% | ✗ / ✗ | none | light | 28 | 🔴 | Replace — request #57 (abandoned, no null-safety) |
| `vuln_pkg` | 2.1.0 | 2.3.4 | 2025-11-02 | 120/160 | 70% | ✓ / ✓ | GHSA-xxxx | light | — | 🔴 | **Security**: bump to ≥2.2.1 this release |

> Fill from `scripts/dep_health.py` output. "Score" omitted (—) when a hard
> override (advisory/discontinued) sets the tier directly.

## Transitive dependencies of concern

Only listed when they carry an advisory or are clearly abandoned (you fix these
by upgrading the parent or adding a `dependency_overrides`, not directly).

| Package | Resolved | Pulled in by | Issue | Action |
|---|---|---|---|---|
| `transitive_pkg` | 1.0.3 | `some_pkg` | OSV CVE-… | Upgrade `some_pkg`, or override to 1.0.5 |

## Skipped

| Package | Reason |
|---|---|
| `flaky_pkg` | pub.dev API timeout — re-run to score |

---

## Prioritized upgrade plan

Ordered: **security → safe batch → reviewed majors → replacements**. Hand to
**#32** (execute) / **#57** (replacements) / **#58** (license review).

| # | Package | Current → Target | Class | Action | Owner |
|---|---|---|---|---|---|
| 1 | `vuln_pkg` | 2.1.0 → 2.2.1 | security/patch | Bump now; verify analyze + tests | #32 |
| 2 | `dio` + `<others>` | minor/patch | safe batch | One PR: `flutter pub upgrade`, analyze, test | #32 |
| 3 | `some_pkg` | 1.2.0 → 3.0.1 | **major** | Own PR; read CHANGELOG, list breaks, est. effort: <S/M/L> | #32 |
| 4 | `old_pkg` | — | replace | Abandoned/no null-safety → find on-stack alt | #57 |

### Major-upgrade notes (one block per major)

**`some_pkg` 1.x → 3.x**
- Breaking changes: <from CHANGELOG / migration guide>
- Affected call sites: <files / count>
- Effort: <S/M/L>   Risk: <low/med/high>   Test focus: <areas>

---

## Next steps

- [ ] Open security PR(s) — #32
- [ ] Open safe-batch PR — #32
- [ ] Schedule reviewed majors — #32
- [ ] Request replacements for abandoned deps — #57
- [ ] License review on changed/new deps — #58
- [ ] Re-run #56 to confirm gate is green before release (#24)
