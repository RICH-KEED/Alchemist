# Dependency Health Rubric

Scoring model for the Dependency Health Monitor (#56). Each dependency gets a
**0–100 weighted health score** built from seven dimensions, then a **tier** and
an **implied action**. Hard overrides can force a tier regardless of score.

House stack reference: [`../../../references/CONVENTIONS.md`](../../../references/CONVENTIONS.md).

---

## Dimensions, weights, scoring

| # | Dimension | Weight | How to score (0–100) |
|---|---|---:|---|
| 1 | Maintenance | 25% | Last publish: ≤3mo = 100, ≤6mo = 85, ≤12mo = 65, ≤18mo = 45, ≤24mo = 25, >24mo = 0. −10 if no release in last 12mo *and* open issues trend up (manual). |
| 2 | Popularity | 15% | Blend of pub `popularityScore` (0–1 → ×100), `likeCount`, and `downloadCount30Days`. Use `popularityScore×100` as the base; +5 if likes > 500, +5 if 30-day downloads > 100k. Cap 100. |
| 3 | Pub points | 10% | `grantedPoints / maxPoints × 100`. (pub.dev's own static-analysis/quality grade.) |
| 4 | Modern-Dart | 10% | `is:null-safe` tag present = +50; `is:dart3-compatible` = +50. Missing either is a real signal in 2026. |
| 5 | Vulnerabilities | 20% | No open OSV advisory = 100. Any advisory = 0 (and triggers the Risk override). |
| 6 | Abandonment risk | 10% | Inverse score: start 100; −60 if last publish >18mo; −40 if popularity <0.3; −100 (floor 0) if package `discontinued`/archived. |
| 7 | Breaking-change risk | 10% | Distance current→latest: same = 100; patch behind = 90; minor behind = 70; one major behind = 40; ≥2 majors = 10. (Lower = riskier/more effort to adopt latest.) |

**Weighted score** = Σ(dimension × weight). Round to integer.

> Size impact is reported as a **note**, not a numeric weight (data is a
> heuristic, not an API metric): flag packages known to add significant native
> code, large assets, or heavy transitive trees (e.g. full ML/video/maps SDKs).
> Surface it in the report's "Size note" column so the reviewer can weigh it.

---

## Tiers

| Tier | Score | Meaning |
|---|---|---|
| 🟢 Healthy | **≥ 75** | Well-maintained, modern, no advisories. Keep. |
| 🟡 Warn | **50 – 74** | Usable but watch it — aging, mid popularity, or a pending major. |
| 🔴 Risk | **< 50** | Stale, unpopular, or unsupported. Plan action. |

### Hard overrides (apply *after* scoring)

- **Open OSV advisory** on the resolved version → **🔴 Risk**, regardless of score.
- Package marked **`discontinued`** on pub.dev → **🔴 Risk**.
- Missing **null-safety** in a Dart-3 project → at most **🟡 Warn** (cap).
- **Off-stack duplicate** (a package that does the job CONVENTIONS already
  assigns to a house default, e.g. a second HTTP client beside `dio`, or `GetX`)
  → flag for consolidation even if individually Healthy.

---

## Action per tier

| Tier / flag | Implied action | Owner |
|---|---|---|
| 🟢 Healthy | None. Re-check at next release cycle. | #56 (monitor) |
| 🟡 Warn (aging) | Watchlist; bundle a minor/patch bump in the next safe batch. | #32 |
| 🟡 Warn (major pending) | Schedule a reviewed major upgrade; read changelog. | #32 |
| 🔴 Risk (advisory) | **Immediate**: bump to lowest non-vulnerable version this release. | #32, gate #24 |
| 🔴 Risk (abandoned/discontinued) | Replace — request an on-stack alternative. | #57 |
| Off-stack duplicate | Consolidate onto the house default. | #57 / #32 |
| New/changed license | Compliance review before merge. | #58 |

---

## Release gate (used by #24)

A release passes the dependency gate only when:

1. **Zero** open OSV advisories on any **direct** dependency.
2. No **🔴 Risk** direct dependency without a tracked follow-up (PR/issue).
3. All direct deps are **null-safe** and **Dart-3 compatible**.

Otherwise the gate is red — hand the upgrade plan to **#32** and re-run.
