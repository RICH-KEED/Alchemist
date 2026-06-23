# Go / No-Go Launch Report — <app name>

**Version:** <versionName> (<versionCode>) · **Date:** <yyyy-mm-dd> · **Reviewer:** <name>
**Target track:** <internal | closed | open | production> · **Rollout plan:** <e.g. 5%→20%→50%→100%>

> **Advisory only.** This report is a recommendation produced by a read-only audit (stage 24).
> The human owner makes the launch decision and signs off below.

---

## Recommendation

> **GO** / **NO-GO** / **CONDITIONAL**

One-line rationale: <…>

- **GO** — all gates 02–23 green; every area PASS; store compliance + privacy done.
- **CONDITIONAL** — no hard blockers; minor time-boxed gap(s) with named owner + date (list below).
- **NO-GO** — ≥1 red gate, or any security / privacy / store-compliance / crash-reporting failure.

---

## Pipeline gates 02–23

| Gate | Owning stage | Status | Evidence / note |
|---|---|---|---|
| Plan & Design | 02–05 | ✅ / ❌ | <PRD, UX, tokens, preview> |
| Foundation | 06–08 | ✅ / ❌ | <analyze clean, nav, providers> |
| Experience | 09–17 | ✅ / ❌ | <motion, assets, API, security, resilience, errors, states, responsive> |
| Quality | 18–20 | ✅ / ❌ | <docs, repo, coverage + CI> |
| Ship & Operate | 21–23 | ✅ / ❌ | <CI/CD, internal release, dashboard> |

---

## Cross-cutting areas

| # | Area | Status | Owning stage | Evidence / note |
|---|---|---|---|---|
| 1 | Performance | PASS / FAIL / N/A | 06, 09, 10 | <startup, jank, size, memory> |
| 2 | Stability | PASS / FAIL / N/A | 15, 16 | <crash-free %, error UX> |
| 3 | Security | PASS / FAIL / N/A | 13 | <MASVS-L1, secrets, TLS, obfuscation+mapping> |
| 4 | Accessibility | PASS / FAIL / N/A | 04, 16, 17 | <semantics, contrast, scaling, targets, TalkBack> |
| 5 | Store compliance | PASS / FAIL / N/A | 22 | <API level, permissions, data safety, rating, policy URL> |
| 6 | Privacy | PASS / FAIL / N/A | 23 | <consent, minimization, opt-out> |
| 7 | Observability | PASS / FAIL / N/A | 23 | <crash live, analytics live, alerting> |
| 8 | Release hygiene | PASS / FAIL / N/A | 22 | <versioning, staged rollout, rollback> |
| 9 | Docs | PASS / FAIL / N/A | 18 | <README, ADRs, runbook> |

---

## Blockers (must clear before GO)

| # | Blocker | Area | Owning stage | Owner | Action to clear |
|---|---|---|---|---|---|
| 1 | <…> | <area> | <NN> | <name> | <send back to stage NN skill> |

*(If none: "No blockers.")*

## Conditional items (time-boxed, for CONDITIONAL only)

| # | Item | Owner | Clear-by date | Gate (e.g. before 100% rollout) |
|---|---|---|---|---|
| 1 | <…> | <name> | <yyyy-mm-dd> | <…> |

## Risks accepted (non-blocking)

| # | Risk | Likelihood | Impact | Mitigation / monitoring |
|---|---|---|---|---|
| 1 | <…> | low/med/high | low/med/high | <…> |

---

## Sign-off

This is an advisory recommendation from the stage-24 audit. The decision and accountability rest
with the signer.

- **Audit reviewer:** ______________________  Date: __________
- **Release owner (decision):** ______________________  Date: __________
- **Decision:** ⬜ GO  ⬜ CONDITIONAL  ⬜ NO-GO

See [`../../../references/CONVENTIONS.md`](../../../references/CONVENTIONS.md) and the gate map in
[`../../../references/PIPELINE.md`](../../../references/PIPELINE.md).
