# PRD — <App name>

> Stage 02 artifact. Lives at `docs/PRD.md` in the target app. Feeds stage 03 (UI/UX Planning).
> Status: `draft | agreed` · Owner: <name> · Last updated: <YYYY-MM-DD>
> Conventions: see `../references/CONVENTIONS.md` (house stack & Definition of Done §7).

## 1. Problem

State the problem in **one sentence**: who hurts, doing what, and why today's workaround is bad.

- **Today's workaround:** <how users solve this now (other app, spreadsheet, nothing)>
- **Why now:** <what makes this worth building today>

## 2. Goals & Non-Goals

**Goals (v1 will…):**
- <outcome 1 — phrased as a user outcome, not a feature>
- <outcome 2>

**Non-Goals (v1 will NOT…):**
- <deferred thing — and one line of why> (e.g. "no social feed — prove the core loop first")
- <every MoSCoW "Won't (now)" lands here>

## 3. Platform & constraints

| Item | Decision |
|---|---|
| Primary platform | Android-first (Material 3); code stays cross-platform-clean |
| Form factors | <phone only / + tablet / + foldable> |
| minSdk | <23 default unless stated> |
| Connectivity | <online-only / offline-capable / offline-first> |
| Accounts | <anonymous-first / social login / hard sign-up> |
| Permissions needed by core flow | <camera / location / notifications / none> |
| Sensitive data | <none / PII / health / payment → flags stage 13> |
| Deadline / team | <date, team size> |

## 4. Personas

Summarize 1–3 personas (full detail in `personas.md`).

| Persona | One-line context | Top goal | Tech comfort |
|---|---|---|---|
| <Maya, 28> | <weekend trail runner, often no signal> | <track training trend> | <low / mid / high> |

## 5. User Stories

Canonical form **As a `<persona>`, I want `<goal>`, so that `<value>`**, each with Given/When/Then acceptance criteria. (Use `user_story.md` for the long form; list them here.)

### US-01 — <short title>  · MoSCoW: **Must**
**As a** <persona>, **I want** <goal>, **so that** <value>.

Acceptance criteria:
- **Given** <context> **When** <action> **Then** <observable outcome>.
- **Given** <edge/offline/error context> **When** <action> **Then** <graceful outcome>.

_Definition of Done:_ meets `CONVENTIONS.md` §7 (four async states, light+dark, tokenized, tests).

### US-02 — <short title>  · MoSCoW: **Must**
…

### US-03 — <short title>  · MoSCoW: **Should**
…

## 6. MVP scope (MoSCoW)

The MVP = **Must** rows only — the smallest core loop that delivers the value once, excellently.

| ID | Story (one line) | Bucket | Notes |
|---|---|---|---|
| US-01 | <…> | **Must** | core loop |
| US-02 | <…> | **Must** | |
| US-03 | <…> | **Should** | |
| US-04 | <…> | **Could** | delighter |
| US-05 | <…> | **Won't (now)** | → Non-goal §2 |

> Sanity check: if every row is a Must, scope harder. A mobile MVP is usually one core loop, not five half-features.

## 7. Success Metrics

**North Star:** <the single number that proxies delivered user value> — target **<X>**, measured by **<event/source>**.

Supporting metrics (AARRR / HEART):

| Metric | Definition | Target | How measured (→ stage 23) |
|---|---|---|---|
| Activation | <the "aha" — e.g. logs first run within 24h> | <%> | analytics event `<name>` |
| Retention (D7) | <returns day 7> | <%> | cohort |
| Task success | <completes core loop without error> | <%> | funnel |
| <Engagement> | <core action / WAU> | <N> | event |

Only list metrics you can actually instrument.

## 8. Risks / Assumptions

| # | Risk or assumption | Impact | Mitigation / validation |
|---|---|---|---|
| A1 | <assumption we couldn't confirm> | <H/M/L> | <how we'll test it> |
| R1 | <risk, e.g. offline sync complexity> | <H/M/L> | <plan, ties to stage 14> |

## 9. Open Questions

- [ ] <question that needs a user/stakeholder answer before stage 03>
- [ ] <unconfirmed assumption to resolve>

---

**Exit gate (stage 02):** problem is one sentence · personas defined · every MVP story has Given/When/Then · MoSCoW done with a minimal **Must** set · North Star + supporting metrics have targets + measurement · non-goals listed · **user agreed** scope + metrics.
