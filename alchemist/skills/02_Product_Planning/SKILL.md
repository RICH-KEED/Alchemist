---
name: Product Planning
description: Turn a raw app idea into a crisp Product Requirements Document — problem statement, personas, user stories with acceptance criteria, a true MVP scoped by MoSCoW, and a North Star + supporting metrics. Use at the very start of a Flutter/Android build, right after the idea exists and before any UX or code. Produces docs/PRD.md and hands it to stage 03 (UI/UX Planning).
when_to_use: Trigger on "I have an app idea", "write a PRD", "scope the MVP for X", "who are the users / what are the user stories", "what should the first version do", or when the orchestrator enters stage 02. If a PRD already exists and the user only wants screens or flows, go straight to stage 03 instead.
---

# Product Planning (Stage 02)

You are the product lead. Take a vague idea — usually one sentence — and interrogate it into a **PRD** (`docs/PRD.md`) that the rest of the pipeline can build against. A premium app starts with a sharp problem and a *small* MVP, not a feature list. Stay aligned with the house style in [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md).

**Output artifact:** `docs/PRD.md` in the target app (use [`templates/PRD.md`](templates/PRD.md)).
**Exit gate:** *MVP scope (MoSCoW) + success metrics agreed with the user.*
**Hands off to:** stage 03 (UI/UX Planning) maps every **Must-have** story to a screen + flow.

---

## The process

1. **Interrogate the idea** (below) until you can state the problem in one sentence.
2. **Name 1–3 personas** — who hurts, in what context. ([`templates/personas.md`](templates/personas.md))
3. **Write user stories** in the canonical form, each with Given/When/Then acceptance criteria. ([`templates/user_story.md`](templates/user_story.md))
4. **Scope the MVP with MoSCoW** — be ruthless; the MVP is the smallest thing that delivers the core value once.
5. **Pick a North Star metric** + a small supporting set (HEART or AARRR).
6. **List non-goals** explicitly — what v1 deliberately will *not* do.
7. **Fill `docs/PRD.md`**, confirm scope + metrics with the user, then advance.

Don't write the PRD silently — ask the questions first. Assumptions you couldn't confirm go in **Open Questions / Assumptions**, not buried in prose.

---

## 1. Interrogate a vague idea

Ask targeted questions; never invent answers to these. If the user only gives one line ("an app for runners"), pull on these threads:

| Thread | Ask | Why it matters here |
|---|---|---|
| **Who** | Who exactly is this for? One narrow group, not "everyone". | drives personas + UX (03) |
| **Problem** | What painful job are they doing today, and how (the workaround)? | the PRD problem statement |
| **Value** | What's the single outcome that makes them say "I'd use this"? | the North Star |
| **Trigger** | When/where do they reach for the phone to do this? | mobile context: one-handed, offline, on the move |
| **Platform** | Android-first? phone only or tablet/foldable too? online-only or offline-capable? | minSdk, responsive (17), resilience (14) |
| **Data & accounts** | Is there a backend/login? whose data, how sensitive? | backend (11), security (13) |
| **Constraints** | Deadline, budget, team size, store/regulatory limits? | scope realism |
| **Done looks like** | How will we know v1 worked, in numbers? | success metrics + exit gate |

Mobile-specific things to surface early because they cascade through the pipeline:
- **Offline / flaky network** expectations (feeds stage 14) — phones lose signal.
- **Permissions** the core flow needs (camera, location, notifications) — each is friction + a privacy line item (13, 24).
- **One-handed / glanceable** usage and **session length** (seconds vs minutes) — shapes IA in 03.
- **Account model**: anonymous-first, social login, or hard sign-up wall (affects activation metric).

---

## 2. Personas

1–3 max. Each: name, one-line context, top goals, frustrations with today's workaround, and **tech comfort** (affects how much hand-holding the UX needs). Template: [`templates/personas.md`](templates/personas.md). Keep them real and narrow — "Maya, 28, trains for trail races on weekends" beats "fitness enthusiast".

---

## 3. User stories with acceptance criteria

Canonical form — always:

> **As a** `<persona>`, **I want** `<goal>`, **so that** `<value>`.

Then make it testable with **Given / When / Then** acceptance criteria (these become the widget/integration tests in stage 20):

```
Given Maya has no internet connection
When she opens the app to review last week's runs
Then her cached runs render within 1s and a subtle "offline" banner shows.
```

Good stories are **vertical** (deliver value end-to-end), **independent**, **small** (fit one sprint), and **persona-anchored**. Split anything that needs "and" in the goal. Avoid solution-speak in the *I want* ("a dropdown") — state the goal, let stage 03/04 design the control. Each story ends with a **Definition of Done** pointer back to [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md) §7 (four async states, light+dark, tests, tokenized) so "done" means the same thing everywhere.

---

## 4. MoSCoW → a true MVP

Sort every story into one bucket. The MVP = **Must** only.

| Bucket | Meaning | Test |
|---|---|---|
| **Must** | Without it there is no product; the core value can't happen. | Remove it → core promise breaks. Keep this set tiny. |
| **Should** | Important, painful to omit, but v1 survives without it. | Ship without it for 2 weeks — acceptable? |
| **Could** | Nice, cheap delighters if time allows. | Cut under any pressure, no regret. |
| **Won't (now)** | Explicitly deferred — becomes a **Non-goal**. | Name it so nobody quietly builds it. |

Rules of thumb: if **everything** is a Must, you haven't scoped — force a single "core loop" story to the top and justify each other Must against it. A mobile MVP is typically **one core loop** done excellently across the four async states, not five half-features.

---

## 5. Success metrics

Pick **one North Star** — the single number that proxies delivered user value (not vanity downloads). Then 3–5 supporting metrics via **HEART** or **AARRR**:

- **North Star** examples: "weekly runs logged per active user", "notes captured per user per week", "successful checkouts/week".
- **AARRR** (great for mobile funnels): Acquisition → **Activation** (the aha moment — define it concretely, e.g. "logged first run") → Retention (D1/D7/D30) → Referral → Revenue.
- **HEART** (great for experience quality): Happiness, Engagement, Adoption, Retention, Task success.

For each metric give a **target** and **how it's measured** — this directly seeds stage 23 (Monitoring) analytics events. Pick metrics you can actually instrument.

---

## 6. Non-goals (say the quiet part)

List what v1 will **not** do and why ("no social feed in v1 — core loop must prove out first"). Non-goals prevent scope creep and tell stages 03–17 what *not* to design or build. Every **Won't** from MoSCoW lands here.

---

## Mini worked example (compressed)

> Idea: *"an app for runners."*

- **Problem:** Casual trail runners forget how training is trending; phone GPS apps are heavy and online-only.
- **Persona:** Maya, 28, weekend trail runner, mid tech comfort, often runs where there's no signal.
- **North Star:** runs logged per weekly-active user.
- **Activation:** logs first run within 24h of install.
- **Stories (MoSCoW):**

| Story | Bucket |
|---|---|
| As Maya, I want to log a run (distance, time, route) so I can track training. | **Must** |
| As Maya, I want last week's runs to load offline so I can review them anywhere. | **Must** |
| As Maya, I want a weekly trend chart so I can see if I'm improving. | **Should** |
| As Maya, I want to share a run to socials so friends can cheer. | **Could** |
| Live competitive leaderboard. | **Won't (now)** → Non-goal |

- **Non-goals (v1):** no social feed, no in-app coaching, no wearables sync.
- **MVP = the two Musts**, done across loading/data/empty/error, light+dark.

This compressed slice is illustrative; the real `docs/PRD.md` fills every section of [`templates/PRD.md`](templates/PRD.md).

---

## Exit gate (must pass before stage 03)

- [ ] Problem statement is one clear sentence.
- [ ] 1–3 personas defined.
- [ ] Every MVP story is in canonical form **with** Given/When/Then acceptance criteria.
- [ ] MoSCoW table done; **Must** set is genuinely minimal (a single core loop).
- [ ] **North Star + supporting metrics** each have a target and a measurement method.
- [ ] Non-goals listed.
- [ ] **User has agreed** the MVP scope and the success metrics.

When green, write `docs/PRD.md`, record it in `.flutter-pipeline/STATE.md`, and hand off to **stage 03 (UI/UX Planning)**.
