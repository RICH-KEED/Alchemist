---
name: Skill Router & Minimal-Load Planner
description: Given a user request, select the SMALLEST set of skills/templates to load (avoid pulling all ~70 skill descriptions) — expand to their dependency closure, order them, and feed the orchestrator or a direct invocation. Uses a machine catalog of trigger-keyword-to-skill maps, then scores the request against it. Full-pipeline asks (trigger phrase "build me an app") defer to the orchestrator. Learns from Skill Telemetry (#35) over time. Cuts metadata token cost at scale.
when_to_use: Trigger BEFORE selecting skills for a non-trivial user request — the orchestrator calls this internally, but also invoke it when the user asks "which skills do I need", "route this request", "what should I load for X", or when you are about to context-switch and want to pre-load precisely the right skill descriptions without pulling the entire catalog. Do NOT invoke for one-line edits, CRUD, or tasks you already know the single right skill for.
---

# Skill Router & Minimal-Load Planner

You pick the smallest set of skills to load for an ad-hoc request so the agent does not pull all ~70 skill descriptions into context. You score the request against a machine catalog, expand to the `dependsOn` closure, order the plan (upstream contracts first), and return a minimal ordered list with a confidence signal.

Stay consistent with the house style in [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md). This skill is roadmap item **#28**.

---

## Why this matters

At ~70 skills and growing, loading every `SKILL.md` into context costs thousands of tokens just for *metadata* — before any real work. Most requests need 2-7 skills, not 70. The router cuts that headroom to what the request actually needs.

This is the second member of the **token-economy cluster**: the Semantic Index (#26) makes finding things cheap, the Context Compressor (#25) makes artifacts small, the Diff-Scoped Loader (#27) loads only changed files, and the Skill Router (#28) picks the right skills. Together they keep the agent lean as the catalog grows.

## Relationship to the orchestrator (#01)

| Concern | Orchestrator (#01) | Router (#28) |
|---|---|---|
| When | "Build me a whole app" — full pipeline | "Add X", "Fix Y", "Why is Z red" — ad-hoc |
| Scope | 24 sequential stages with exit gates | Smallest closure needed for one ask |
| Drives | Owns `.flutter-pipeline/STATE.md`, advances phases | Owns `skill_catalog.json`, scores + expands |
| Feed | Reads the plan from here then invokes each skill | Produces the plan the orchestrator (or caller) follows |

The orchestrator calls the router when the user has a bounded ask, but the ask could touch more skills than the orchestrator can confidently enumerate. The router answers: *load these N skills, in this order, and start here.*

For **full-pipeline requests** (phrases like "build me a Flutter app", "ship an app", "new project from scratch"), the router detects them and returns `mode: orchestrator` — do not try to pick skills piecemeal; load the orchestrator (#01) and run the pipeline.

---

## How routing works

### 1. Score the request against the catalog

[`templates/skill_catalog.json`](templates/skill_catalog.json) maps every skill id to `triggers[]` — lowercase keyword/phrase fragments. For a given request, each skill scores:
- 1 point for a single-word phrase match (e.g. "theme")
- 2 points for a two-word phrase (e.g. "design system")
- 3 points for three+ words (e.g. "build me a flutter app")
- Substring matching: the trigger appears anywhere inside the lowercased request

Skills scoring below `--threshold` (default 1) are pruned. The script handles this:

```bash
python "${CLAUDE_SKILL_DIR}/scripts/route.py" "add a login form"
python "${CLAUDE_SKILL_DIR}/scripts/route.py" --json "why is my build red"
echo "make the app responsive on tablets" | python "${CLAUDE_SKILL_DIR}/scripts/route.py"
```

### 2. Expand to dependency closure

For every matched skill, walk its `dependsOn[]` array. Each ancestor is added with `role: "dependency"`. This ensures contracts, scaffolds, and tokens are loaded before the consumer skill that needs them. The closure is **transitive**: if A depends on B and B depends on C, all three are loaded.

### 3. Prune preconditions

Phase-A planning/design skills (02-05) and the architecture scaffold (06) are **preconditions** — they are assumed to exist in a project already past inception. They appear in the plan as "Preconditions" (verify they are done) but do not count toward the loaded skill count. This prevents the router from recommending "replan the app" for a form-engine ask.

### 4. Order upstream-first

Skills are ordered by `phase` (A..E, then X) and numeric id, so contracts come before consumers. A dependency always sorts before the skill that depends on it.

### 5. Estimate confidence

Confidence is low/medium/high based on the top match score and plan size. Low means the phrasing should be more precise; high means the matches are strong and few.

---

## Modes (Roo-Code-style framing)

| Mode | Trigger | Behavior |
|---|---|---|
| **Orchestrator mode** | "build me an app", "new project", "full pipeline" | Returns `01_Master_Orchestrator` as the recommendation. The caller loads the orchestrator, not ad-hoc skills. |
| **Ad-hoc mode** | "fix X", "add Y", "why is Z" | Returns a minimal ordered plan of 1-7 skills with dependency closure, preconditions listed separately. |
| **No-match mode** | Request doesn't hit any trigger | Returns empty plan with reason. Caller should broaden the request or lower `--threshold`. |

The router never invokes skills directly — it produces a plan. The orchestrator or the calling agent reads the plan and invokes each skill in order.

---

## Worked examples

See [`templates/routing_examples.md`](templates/routing_examples.md) for the full set. Key cases:

**"add a login form"** → `55_Form_Engine` + dependencies `07_Navigation, 08_Riverpod, 15_Error_Handling, 16_Loading_States` (5 loaded of 74). Preconditions: 02, 03, 04, 06.

**"why is my build red"** → `37_Build_Doctor` alone (1 loaded, zero pipeline deps).

**"build me a flutter app for tracking habits"** → defers to orchestrator (full-pipeline ask).

**"make the app responsive on tablets"** → `17_Responsive_UI` + `07_Navigation` (3 loaded).

### Confidence-driven guidance

| Confidence | Meaning | Action |
|---|---|---|
| `high` | Top match score >= 3 and plan is focused | Trust the plan; load the skills and start |
| `medium` | Decent match, some noise | Review the preconditions; rephrase if the top match looks wrong |
| `low` | Weak keyword overlap | Broaden or reword the request, or lower `--threshold` to 0 and inspect the raw matches |
| `none` | No triggers matched | Ask the user a clarifying question to narrow the domain |

---

## The catalog

[`templates/skill_catalog.json`](templates/skill_catalog.json) is the machine's single source of truth for routing. Each entry:

```json
"NN_Name": {
  "phase": "C",
  "triggers": ["keyword", "multi-word phrase", ...],
  "dependsOn": ["07_Navigation", "08_Riverpod"],
  "fullPipeline": true   // ONLY on 01_Master_Orchestrator
}
```

Fields:
- **phase**: pipeline phase (`A`-`E`) or `X` for cross-cutting / advanced skills
- **triggers**: lowercase phrases. Prefer specific 2-3 word phrases over single words (e.g. "push notification" not just "push")
- **dependsOn**: skill ids whose contracts this skill consumes. Keep in sync with each skill's own "For X use skill NN" cross-references
- **fullPipeline**: `true` only on 01 — signals the router to defer

**Maintenance rule:** When a new skill is authored or a skill's cross-references change, update `skill_catalog.json` to match. Skill Telemetry (#35) writes hit/miss data that the router optionally consults to learn which trigger phrases work best — see Token Budget Governor (#30) for the real-time telemetry integration pattern.

---

## Telemetry integration (#35)

When Skill Telemetry (#35) has written `.flutter-pipeline/telemetry.json` with router-level hit/miss data:

1. The router loads telemetry on startup (if present)
2. Trigger phrases whose historical precision is low are down-weighted
3. Phrases with high precision get a boost
4. New skills (first 5 sessions) use raw keyword scoring only

Telemetry is **optional** — the router works on keywords alone. Telemetry just makes it accurate enough to skip the agent even reading the result.

---

## Script reference

| Script | Purpose |
|---|---|
| [`scripts/route.py`](scripts/route.py) | Core: score request → expand closure → order → print plan. `--json` emits machine-readable output. `--threshold N` adjusts sensitivity. |
| `--catalog PATH` | Override the catalog path (default: `${CLAUDE_SKILL_DIR}/templates/skill_catalog.json`). |
| `--threshold N` | Minimum match score for a skill to enter the plan (default 1). |

All scripts use Python3 stdlib only. `${CLAUDE_SKILL_DIR}` is set by the harness to this skill's root.

---

## Integration with the token-economy cluster

```
User request
       |
       v
[Semantic Index #26]  -- if the codebase is indexed, query first for file locations
       |
       v
[Skill Router #28]    -- picks the minimal skill set for THIS request
       |
       v
[30 Token Budget Governor] -- estimates the cost BEFORE loading
       |
       v
[25 Context Compressor] -- shrinks upstream artifacts into context cards
       |
       +--> load each skill's SKILL.md, invoke in order
```
