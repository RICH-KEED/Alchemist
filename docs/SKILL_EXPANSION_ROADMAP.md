# Skill Expansion Roadmap — flutter-android

**Chief Architect's discovery log.** The base pipeline (skills 01–24) builds an app idea → production. This roadmap proposes **50 new capabilities (25–74)** that make the *system itself* more autonomous, reliable, cost-efficient, and enterprise-ready. Numbering continues from the 24 shipped skills.

---

## 0. Gap analysis of the current 24

What the v0.1 pipeline does **not** yet have (the bottlenecks worth attacking):

1. **No memory of the codebase.** Every skill re-reads files → linear token cost that grows with the app. There is no persistent index, no "what changed," no decision history.
2. **One-directional.** It builds, but doesn't **observe and react** — no triage of real crashes, no self-healing CI, no dependency drift watch.
3. **No self-economy.** No token budgeting, no context compression, no regeneration cache. The system can't predict or cap its own cost.
4. **Quality is checklist-based, not adversarial.** Gates are human-readable lists; nothing *attacks* the UI, the threat surface, or the test suite's strength.
5. **Integration is manual.** No Figma/OpenAPI/Play Console/Sentry bridges → humans copy-paste contracts and specs the agent could ingest.
6. **Enterprise blind spots.** No license/SBOM/privacy-manifest/threat-model/white-label machinery — the things that block a real org from shipping.
7. **No learning loop.** Skills don't record success/cost; bugs can be reintroduced; patterns aren't reused across projects.

The 50 below are organized into 8 clusters that close these gaps. Each is deliberately **non-obvious** — the obvious ones (theming, routing, testing) are already in 01–24.

---

## Cluster 1 — Token & Context Economy *(optimize the AI system itself — the highest-leverage, least-obvious cluster)*

### 25. Context Compression Engine
- **Purpose:** Compress pipeline artifacts (PRD, UX, STATE, large files) into dense, lossless-enough "context cards" downstream skills load instead of full docs.
- **Why it matters:** Artifacts are re-read by many stages; compression cuts per-stage tokens 40–70% as the project grows.
- **Inputs:** Artifact/file + target token budget. **Outputs:** `*.card.md` summaries + a pointer index.
- **Dependencies:** Codebase Semantic Index (26). **Approach:** Hierarchical summarization keyed by content hash; re-compress only on change. **Workflow:** Orchestrator loads `PRD.card.md` (300 tok) not `PRD.md` (3k tok); expands on demand.
- **Impact:** 9 · **Priority:** Critical

### 26. Codebase Semantic Index *(memory)*
- **Purpose:** Persistent map of symbols, widgets, providers, routes, features → file/line, with a dependency graph. Incremental.
- **Why it matters:** Eliminates "read the whole tree" — skills query the index, not the filesystem. Foundation for almost everything else.
- **Inputs:** Repo path, change set. **Outputs:** `.flutter-pipeline/index.json` (+ optional graphify graph).
- **Dependencies:** graphify. **Approach:** AST/regex pass on changed files only; store provider/route/widget registries. **Workflow:** "Where is auth state?" → index lookup, zero file reads.
- **Impact:** 10 · **Priority:** Critical

### 27. Diff-Scoped Context Loader
- **Purpose:** For any edit, load only changed files + their direct dependents (from the index), not the feature tree.
- **Why it matters:** Bounds edit-task context to O(change) instead of O(app). Mirrors Cursor's apply model.
- **Inputs:** Git diff / target symbol. **Outputs:** Minimal file set + impact list. **Dependencies:** 26. **Approach:** Reverse-dependency walk, depth-capped. **Workflow:** Change a DTO → loader surfaces the 3 mappers + 2 tests that touch it. **Impact:** 8 · **Priority:** High

### 28. Skill Router & Minimal-Load Planner
- **Purpose:** Given a request, select the **smallest** set of skills/templates to load; avoid pulling all 74 descriptions.
- **Why it matters:** Skill metadata itself costs tokens at scale; routing keeps the active set tight.
- **Inputs:** User intent. **Outputs:** Ordered skill plan + confidence. **Dependencies:** Skill Telemetry (35). **Approach:** Intent→skill embedding match + dependency closure. **Workflow:** "add a login form" → routes to 55,07,08,15 only. **Impact:** 7 · **Priority:** High

### 29. Template Delta Cache
- **Purpose:** Memoize generated template instances keyed by (skill, inputs-hash); reuse instead of regenerating identical code.
- **Why it matters:** Regenerating boilerplate (themes, dio clients) burns tokens for byte-identical output.
- **Inputs:** Skill + params. **Outputs:** Cached artifact or cache-miss. **Dependencies:** —. **Approach:** Content-addressed store under `.flutter-pipeline/cache/`. **Workflow:** Second feature reuses the cached repository scaffold. **Impact:** 6 · **Priority:** Medium

### 30. Token Budget Governor & Cost Predictor
- **Purpose:** Predict token/$ cost of a task *before* running it, enforce a ceiling, and degrade gracefully (compress, sample, defer).
- **Why it matters:** Makes autonomous operation safe and forecastable — the #1 enterprise objection to AI agents.
- **Inputs:** Task plan, budget. **Outputs:** Estimate, go/no-go, live spend. **Dependencies:** 35. **Approach:** Per-skill historical cost model × plan size; hard cap hook. **Workflow:** "Refactor all features" → predicts 1.2M tok, asks to scope or proceed. **Impact:** 9 · **Priority:** Critical

### 31. Artifact Handoff Compressor
- **Purpose:** Sub-skill of 25 specialized for stage→stage handoffs (STATE.md, gate evidence) so the orchestrator's running context stays flat across 24 stages.
- **Why it matters:** A 24-stage run otherwise accumulates unbounded context. **Inputs:** Stage outputs. **Outputs:** Compressed handoff record. **Dependencies:** 25,26. **Approach:** Keep only gate-relevant deltas. **Workflow:** Stage 20 sees a 200-tok summary of stages 02–19. **Impact:** 8 · **Priority:** High

---

## Cluster 2 — Autonomy & Self-Operation *(turn the pipeline from a builder into an operator)*

### 32. Autonomous Maintenance Agent
- **Purpose:** Scheduled agent that bumps deps/SDK, fixes new lints, regenerates code, runs tests, and opens a PR — unattended.
- **Why it matters:** Dependency rot is the silent killer of mobile apps; this keeps projects green between feature work.
- **Inputs:** Repo, cadence. **Outputs:** PRs with passing CI + changelog. **Dependencies:** 33,56,41,19. **Approach:** Cron → branch → upgrade → verify → PR. **Workflow:** Weekly "chore: deps + lint" PR appears, CI green. **Impact:** 9 · **Priority:** High

### 33. Self-Healing CI Agent
- **Purpose:** On CI failure, ingest logs, localize the cause (flaky test, version solve, signing), patch, and re-run.
- **Why it matters:** Most CI red is mechanical; auto-repair removes the most common human interruption.
- **Inputs:** CI run logs. **Outputs:** Fix commit + re-run, or escalation. **Dependencies:** 37,38. **Approach:** Failure-class classifier → targeted fixer. **Workflow:** Gradle version solve fails → agent pins, pushes, green. **Impact:** 9 · **Priority:** High

### 34. Crash-Free Rate Watchdog *(agent)*
- **Purpose:** Continuously watch Sentry/Crashlytics; when crash-free % drops or a new signature spikes, open a triaged issue with suspected code.
- **Why it matters:** Closes the observe→fix loop autonomously. **Inputs:** Crash dashboard (MCP). **Outputs:** GitHub issue + suspect diff. **Dependencies:** 38,23. **Approach:** Poll → anomaly detect → triage. **Workflow:** v1.4 ANR spike → issue with stack→code mapping. **Impact:** 8 · **Priority:** High

### 35. Skill Telemetry & Self-Tuning *(memory)*
- **Purpose:** Record each skill's success rate, token cost, and rework; feed routing, budgeting, and prompt tuning.
- **Why it matters:** The system can't improve what it doesn't measure. **Inputs:** Skill runs. **Outputs:** `.flutter-pipeline/telemetry.json`. **Dependencies:** —. **Approach:** Lightweight run ledger + rollups. **Workflow:** Router learns skill 49 fails on GraphQL → deprioritizes. **Impact:** 7 · **Priority:** Medium

### 36. Codebase Onboarding Agent
- **Purpose:** Point at an *unfamiliar* Flutter repo → produce an architecture map, conventions, risk hotspots, and a "how to add X" guide.
- **Why it matters:** Brownfield is the real world; the 24 assume greenfield. **Inputs:** Repo. **Outputs:** `docs/ONBOARDING.md` + index. **Dependencies:** 26. **Approach:** Index + heuristics + graphify communities. **Workflow:** Inherited 80k-LOC app → 2-page orientation in minutes. **Impact:** 8 · **Priority:** High

---

## Cluster 3 — Correctness, Debugging & Performance *(hidden bottlenecks that eat senior-engineer hours)*

### 37. Build Doctor
- **Purpose:** Diagnose Gradle/AGP/Kotlin/CocoaPods/version-solve/NDK failures from raw build logs and propose exact fixes.
- **Why it matters:** Build breakage is the most common, least-Googleable Flutter time sink. **Inputs:** Build log. **Outputs:** Root cause + patch. **Dependencies:** —. **Approach:** Error-signature KB + version-compat matrix. **Workflow:** "Namespace not specified" → adds `namespace`, bumps AGP. **Impact:** 9 · **Priority:** Critical

### 38. Runtime Exception Triage Agent
- **Purpose:** Map a stack trace / Crashlytics signature → exact file/line/provider, hypothesize cause, propose fix + test.
- **Why it matters:** Turns opaque crashes into PRs. **Inputs:** Stack trace + symbols. **Outputs:** Suspect diff + repro test. **Dependencies:** 26,22(symbols). **Approach:** Deobfuscate → index lookup → reasoned fix. **Workflow:** Null deref in checkout → fix + regression test. **Impact:** 9 · **Priority:** High

### 39. Rebuild & Jank Profiler
- **Purpose:** From DevTools timeline / `--profile` traces, find excessive widget rebuilds and slow frames; recommend `const`, `select`, `RepaintBoundary`, isolate offload.
- **Why it matters:** "It feels laggy" is vague; this makes it specific and fixable. **Inputs:** Timeline export. **Outputs:** Hotspot report + patches. **Dependencies:** 26. **Approach:** Parse frame/build events → attribute to widgets. **Workflow:** 32ms frames on scroll → adds RepaintBoundary, 9ms. **Impact:** 8 · **Priority:** High

### 40. State-Leak & Dispose Auditor
- **Purpose:** Static scan for undisposed `AnimationController`/`StreamSubscription`/`TextEditingController`, leaked providers, missing `autoDispose`.
- **Why it matters:** Memory leaks ship silently and crash on low-end Android. **Inputs:** Source. **Outputs:** Leak list + fixes. **Dependencies:** 26. **Approach:** Pattern + dataflow checks. **Workflow:** Flags a controller created in `build` w/o dispose. **Impact:** 7 · **Priority:** Medium

### 41. Analyzer Auto-Fix Loop
- **Purpose:** Run `flutter analyze`, auto-resolve lints/format, loop until clean under `very_good_analysis`.
- **Why it matters:** Keeps the universal gate green with zero human toil. **Inputs:** Repo. **Outputs:** Clean tree + fix summary. **Dependencies:** —. **Approach:** analyze → categorized fixers → re-run. **Workflow:** 140 warnings → 0 in one pass. **Impact:** 8 · **Priority:** Critical

### 42. Multi-Agent Architecture Debate
- **Purpose:** For a hard decision (state lib, offline strategy, modularization), spawn N advocate agents + a judge → scored recommendation + ADR.
- **Why it matters:** Reduces single-pass bias on high-cost, irreversible choices. **Inputs:** Decision + constraints. **Outputs:** Ranked options + ADR. **Dependencies:** 63. **Approach:** Parallel advocates → adversarial critique → judge. **Workflow:** "Monorepo vs packages?" → reasoned verdict. **Impact:** 7 · **Priority:** Medium

---

## Cluster 4 — UI/UX Intelligence *(the "awesome UI" differentiator, made adversarial)*

### 43. Design Critic Agent
- **Purpose:** Screenshot a built screen, critique it against the design system + premium rubric (hierarchy, spacing rhythm, contrast, alignment, density), return prioritized fixes.
- **Why it matters:** Moves UI from "compiles" to "looks designed"; closes the loop the human eye usually provides. **Inputs:** Screenshot (Pencil/`flutter run`). **Outputs:** Scored critique + diffs. **Dependencies:** 04,05. **Approach:** Vision analysis vs token rules. **Workflow:** Flags inconsistent gutters + weak CTA contrast. **Impact:** 9 · **Priority:** High

### 44. Visual Regression / Pixel-Diff Agent
- **Purpose:** Capture golden screenshots per screen × theme × size; diff on every change; flag unintended visual deltas.
- **Why it matters:** UI regressions are invisible to unit tests. **Inputs:** Build + baseline. **Outputs:** Diff report. **Dependencies:** 20,17. **Approach:** Deterministic render + perceptual diff. **Workflow:** A padding tweak silently shifts 6 screens → caught. **Impact:** 8 · **Priority:** High

### 45. Accessibility Auditor
- **Purpose:** Audit semantics labels, contrast ratios, touch-target size, dynamic type, focus order, TalkBack traversal.
- **Why it matters:** Legal + ethical requirement most apps fail; also a Play quality signal. **Inputs:** Widget tree + screenshots. **Outputs:** WCAG/Material a11y report + fixes. **Dependencies:** 26,43. **Approach:** Semantics tree walk + contrast math. **Workflow:** Adds missing `Semantics`, fixes 3.8:1 text. **Impact:** 8 · **Priority:** High

### 46. Figma → Flutter Bridge *(MCP)*
- **Purpose:** Import Figma frames/variables → Flutter widget tree mapped onto the project's design tokens (not raw hex).
- **Why it matters:** Eliminates the designer→dev translation tax; tokens stay the source of truth. **Inputs:** Figma file (MCP). **Outputs:** Token-mapped widgets. **Dependencies:** 04. **Approach:** Figma API → layout/auto-layout → Flutter mapping. **Workflow:** Designer ships a frame → screen scaffolds itself. **Impact:** 8 · **Priority:** Medium

### 47. Screenshot → Widget Reconstructor
- **Purpose:** Given a screenshot of *any* app, reconstruct an editable Flutter widget tree using the design system.
- **Why it matters:** "Build me something like this" → working UI; competitive parity with v0/Bolt. **Inputs:** Image. **Outputs:** Widget code. **Dependencies:** 04,16. **Approach:** Vision → layout inference → token-bound widgets. **Workflow:** Drop a competitor screen → editable clone scaffold. **Impact:** 7 · **Priority:** Medium

### 48. Motion Consistency Critic
- **Purpose:** Sub-skill: verify all animations draw durations/curves from `AppTokens.motion`; flag ad-hoc timings and jarring transitions.
- **Why it matters:** Inconsistent motion is the tell of an amateur app. **Inputs:** Source. **Outputs:** Motion lint. **Dependencies:** 09,04. **Approach:** Scan for literal Durations/Curves. **Workflow:** Flags a `Duration(milliseconds: 350)` not from tokens. **Impact:** 6 · **Priority:** Low

---

## Cluster 5 — Codegen & Integration Accelerators

### 49. OpenAPI → Dart Client Generator
- **Purpose:** From an OpenAPI/Swagger spec, generate dio client + freezed DTOs + repository interfaces returning `Result`.
- **Why it matters:** Hand-writing API layers is the biggest repetitive cost in app builds; spec becomes the contract. **Inputs:** OpenAPI doc. **Outputs:** `data/` layer. **Dependencies:** 11,15. **Approach:** Spec parse → house-style emitter. **Workflow:** Backend ships spec → typed client in minutes. **Impact:** 9 · **Priority:** High

### 50. Localization & i18n Engine
- **Purpose:** Extract hardcoded strings → ARB, manage `intl`/`slang`, machine-translate + flag review, audit RTL/pluralization.
- **Why it matters:** Retrofitting i18n late is brutal; non-English markets are where growth is. **Inputs:** Source + locales. **Outputs:** ARB + generated accessors + RTL report. **Dependencies:** 26. **Approach:** String scan + ICU handling. **Workflow:** Adds `es`, `ar` (RTL-checked) across the app. **Impact:** 8 · **Priority:** High

### 51. Schema → DB / Drift Migration Generator
- **Purpose:** From domain models, generate Drift/Isar schema + typed DAOs + forward migrations with tests.
- **Why it matters:** Local persistence + migrations are error-prone and ship data-loss bugs. **Inputs:** Models + current schema. **Outputs:** Schema, DAOs, migration. **Dependencies:** 26,20. **Approach:** Diff old↔new schema → migration steps. **Workflow:** Add a column → migration + round-trip test. **Impact:** 7 · **Priority:** Medium

### 52. Push Notification Pipeline
- **Purpose:** Wire FCM end-to-end: permissions (Android 13+), typed payload models, foreground/background/terminated handlers, deep-link routing, topic mgmt.
- **Why it matters:** Notifications are integration-heavy and easy to get subtly wrong. **Inputs:** Event taxonomy. **Outputs:** Notification module. **Dependencies:** 07,13. **Approach:** Template + handler wiring. **Workflow:** "order shipped" push → opens order screen. **Impact:** 7 · **Priority:** Medium

### 53. Background Work & Sync Scheduler
- **Purpose:** Set up WorkManager/`workmanager` + isolates for periodic sync, retries, and offline outbox flush (pairs with 14).
- **Why it matters:** Reliable background sync is a top source of "works on my phone" bugs. **Inputs:** Job specs. **Outputs:** Scheduler module. **Dependencies:** 14,11. **Approach:** Constraint-based job registry. **Workflow:** Flush outbox on connectivity + charging. **Impact:** 7 · **Priority:** Medium

### 54. Feature Flag & Remote Config Scaffolder
- **Purpose:** Typed access to Firebase Remote Config/flags with local overrides, gating, and a kill-switch pattern.
- **Why it matters:** Safe rollouts + instant rollback without a release. **Inputs:** Flag list. **Outputs:** Typed flag service. **Dependencies:** 08. **Approach:** Codegen typed keys + provider. **Workflow:** Ship dark, enable to 5%, kill on spike. **Impact:** 7 · **Priority:** Medium

### 55. Form Engine
- **Purpose:** Generate forms (fields, validation, error UX, submit→Result) from a schema, wired to Riverpod and design tokens.
- **Why it matters:** Forms are everywhere and tediously hand-built. **Inputs:** Field schema. **Outputs:** Form widget + controller. **Dependencies:** 08,15,16. **Approach:** Schema→widgets + validators. **Workflow:** Login/checkout forms scaffolded with validation. **Impact:** 7 · **Priority:** Medium

---

## Cluster 6 — Enterprise, Security & Compliance *(the things that actually block shipping in an org)*

### 56. Dependency Health Monitor
- **Purpose:** Score every pub dep on maintenance, popularity, pub points, known CVEs, abandonment, size, and breaking-change risk.
- **Why it matters:** A bad transitive dep is a future incident. **Inputs:** `pubspec.lock`. **Outputs:** Health report + upgrade plan. **Dependencies:** pub.dev/OSV (MCP). **Approach:** Query pub + advisory DBs. **Workflow:** Flags an unmaintained pkg → suggests replacement. **Impact:** 8 · **Priority:** High

### 57. Package Recommendation Engine
- **Purpose:** Given a need ("charts", "secure storage"), recommend the best pub package weighing health, license, size, null-safety, and house-stack fit.
- **Why it matters:** Stops the agent from picking abandoned/risky packages. **Inputs:** Capability need. **Outputs:** Ranked options + rationale. **Dependencies:** 56. **Approach:** Catalog + scoring. **Workflow:** "need a calendar" → 3 ranked picks. **Impact:** 7 · **Priority:** Medium

### 58. License / OSS Compliance & SBOM Auditor
- **Purpose:** Resolve transitive licenses, flag GPL/AGPL/non-commercial risk, generate NOTICE + a CycloneDX SBOM.
- **Why it matters:** Hard legal gate for enterprise & acquisition. **Inputs:** Dep tree. **Outputs:** License report, NOTICE, SBOM. **Dependencies:** 56. **Approach:** License resolution + policy. **Workflow:** Catches an AGPL transitive before release. **Impact:** 8 · **Priority:** High

### 59. Privacy Manifest & Play Data-Safety Generator
- **Purpose:** Scan SDKs/permissions/data flows → auto-fill Play Data Safety form + iOS privacy manifest + a privacy-policy draft.
- **Why it matters:** Required by stores; wrong answers cause rejections/removals. **Inputs:** Manifest + deps + code. **Outputs:** Data-safety mapping + manifest. **Dependencies:** 13,26. **Approach:** SDK→data-type KB. **Workflow:** Detects analytics SDK → declares "Usage data: Analytics". **Impact:** 8 · **Priority:** High

### 60. Threat Modeling Agent
- **Purpose:** STRIDE over the app's data flows (auth, storage, network, deep links, IPC) → ranked threats + mitigations mapped to skill 13.
- **Why it matters:** Proactive security beats post-breach. **Inputs:** Architecture + index. **Outputs:** Threat model doc. **Dependencies:** 13,26. **Approach:** Dataflow extraction → STRIDE prompts. **Workflow:** Flags unvalidated deep-link param → fix. **Impact:** 7 · **Priority:** Medium

### 61. Secrets Scanner *(sub-skill of 13)*
- **Purpose:** Pre-commit/CI scan for API keys, tokens, keystores, `google-services.json` leaks, base64 blobs — Flutter/Android tuned.
- **Why it matters:** Leaked secrets are the most common, most damaging mistake. **Inputs:** Diff/tree. **Outputs:** Findings + block. **Dependencies:** 19,13. **Approach:** Entropy + rule patterns + allowlist. **Workflow:** Blocks a commit with a hardcoded key. **Impact:** 8 · **Priority:** High

### 62. White-Label / Multi-Flavor Engine
- **Purpose:** From one config (brand colors, name, icon, endpoints, flags), generate N flavored, signed builds.
- **Why it matters:** Agencies/enterprises ship the same app for many clients; manual flavoring is brittle. **Inputs:** Brand config matrix. **Outputs:** Flavors + CI matrix. **Dependencies:** 04,10,21. **Approach:** Token + flavor templating. **Workflow:** 12 client builds from one source. **Impact:** 7 · **Priority:** Medium

### 63. Decision Ledger & Provenance *(memory)*
- **Purpose:** Auto-capture every significant decision (and *why*, with the alternatives) as a linked ADR + trace from requirement→code.
- **Why it matters:** Institutional memory; audits; prevents re-litigating settled choices (token waste). **Inputs:** Decisions across stages. **Outputs:** `docs/adr/*` + trace graph. **Dependencies:** 18,42. **Approach:** Hook on decision points. **Workflow:** "Why Drift?" → ADR-0007 with context. **Impact:** 7 · **Priority:** Medium

---

## Cluster 7 — Product, Growth & Ops

### 64. App Store Optimization (ASO) Agent
- **Purpose:** Optimize title, subtitle, keywords, description, and screenshot order/captions for conversion; localize listings.
- **Why it matters:** Discovery is half the battle; engineering excellence is wasted if no one installs. **Inputs:** App + category + competitors. **Outputs:** Listing variants + A/B plan. **Dependencies:** 22. **Approach:** Keyword research + competitor scan. **Workflow:** Rewrites listing → tracks install lift. **Impact:** 7 · **Priority:** Medium

### 65. Release Notes & Changelog Generator
- **Purpose:** From Conventional Commits between tags → human changelog + Play "what's new" (localized, user-facing tone).
- **Why it matters:** Every release needs it; nobody enjoys writing it. **Inputs:** Commit range. **Outputs:** `CHANGELOG.md` + `whats_new.txt`. **Dependencies:** 19,22. **Approach:** Commit parse + summarize. **Workflow:** Tag `v1.3` → notes auto-drafted. **Impact:** 6 · **Priority:** Low

### 66. Analytics Taxonomy Designer & Instrumenter
- **Purpose:** Turn PRD success metrics into a typed event taxonomy and auto-instrument key flows (screen views, funnels).
- **Why it matters:** Most apps ship with messy, unusable analytics. **Inputs:** PRD metrics + flows. **Outputs:** Event schema + instrumentation. **Dependencies:** 02,23. **Approach:** Metric→event mapping + insertion. **Workflow:** Checkout funnel instrumented consistently. **Impact:** 7 · **Priority:** Medium

### 67. A/B Experiment Scaffolder
- **Purpose:** Wire experiments (variant assignment, exposure logging, guardrail metrics) on top of Remote Config.
- **Why it matters:** Data-driven product needs first-class experimentation. **Inputs:** Hypothesis + metric. **Outputs:** Experiment harness. **Dependencies:** 54,66. **Approach:** Variant provider + logging. **Workflow:** Test new onboarding → measured. **Impact:** 6 · **Priority:** Low

### 68. Performance Budget Enforcer *(CI gate)*
- **Purpose:** Enforce budgets on app size (AAB), cold-start, and frame timings; fail CI on regression.
- **Why it matters:** Performance rots gradually; budgets make it a gate, not a vibe. **Inputs:** Build artifacts + baselines. **Outputs:** Pass/fail + trend. **Dependencies:** 21,39. **Approach:** Measure in CI vs thresholds. **Workflow:** A dep bloats size 8% → CI red. **Impact:** 7 · **Priority:** Medium

### 69. Device Matrix / Test Lab Orchestrator
- **Purpose:** Run integration/golden tests across a real device matrix (Firebase Test Lab) incl. low-end + foldables.
- **Why it matters:** "Works on Pixel" ≠ works on a 2GB Android Go device. **Inputs:** Test suite + matrix. **Outputs:** Cross-device report. **Dependencies:** 20,17. **Approach:** Test Lab API orchestration. **Workflow:** Catches an OOM on low-RAM device. **Impact:** 6 · **Priority:** Low

---

## Cluster 8 — Testing & Reliability, Deeper

### 70. Test Generation Agent
- **Purpose:** From a screen/notifier/repository, generate meaningful widget/golden/unit tests (happy + edge + error), not coverage-padding.
- **Why it matters:** Tests are the most-skipped step; auto-generation makes the coverage gate cheap. **Inputs:** Target symbol. **Outputs:** Test files. **Dependencies:** 20,08,12. **Approach:** Behavior inference from types/states. **Workflow:** New controller → 6 state-transition tests. **Impact:** 8 · **Priority:** High

### 71. Mutation Testing Harness
- **Purpose:** Mutate code, re-run tests; surviving mutants reveal weak/assertion-free tests.
- **Why it matters:** Coverage % lies; mutation score measures real strength. **Inputs:** Source + tests. **Outputs:** Mutation report. **Dependencies:** 70. **Approach:** Operator-based mutation + run. **Workflow:** Finds a test that passes even when logic flips. **Impact:** 6 · **Priority:** Low

### 72. Contract & Golden Drift Detector
- **Purpose:** Detect when backend responses drift from pinned contracts, or goldens need legit updates vs real regressions.
- **Why it matters:** Distinguishes "intended change" from "silent break." **Inputs:** Live/sample responses + goldens. **Outputs:** Drift report + suggested action. **Dependencies:** 12,44,49. **Approach:** Schema/image diff classification. **Workflow:** API adds a field → DTO update suggested, not a failure. **Impact:** 7 · **Priority:** Medium

### 73. Regression Memory *(memory)*
- **Purpose:** Record every fixed bug (signature, root cause, fix, guarding test); warn when a change risks reintroducing one.
- **Why it matters:** Stops the "we fixed this before" class of waste. **Inputs:** Bug fixes. **Outputs:** `.flutter-pipeline/regressions.json` + warnings. **Dependencies:** 38,26. **Approach:** Fingerprint + similarity match on diffs. **Workflow:** Edit near an old NPE site → reminder + its test. **Impact:** 7 · **Priority:** Medium

### 74. Chaos / Resilience Tester
- **Purpose:** Inject failures (network loss, slow API, denied permissions, low memory, clock skew, killed isolate) and assert graceful degradation.
- **Why it matters:** Validates skills 14/15/16 under real adversity, not just unit happy paths. **Inputs:** Scenario set. **Outputs:** Resilience report. **Dependencies:** 14,15,16. **Approach:** Interceptor + platform-channel fault injection. **Workflow:** Kills network mid-checkout → must show retry, not crash. **Impact:** 7 · **Priority:** Medium

---

## Meta-Analysis

### Which should **merge**
- 30 (Cost Predictor) absorbs a standalone budget skill → one **Token Budget Governor**.
- 39 (Rebuild) + jank profiling → one **Performance Profiler**.
- 58 (License) + SBOM → one **Compliance Auditor**.
- 59 (Privacy manifest) + Play data safety → one **Privacy Generator**.
- 65 + ASO localization share a copy-generation core.

### Which become **sub-skills** (not top-level)
- 31 under 25 · 48 under 09 · 61 under 13 · 67 under 54 · RTL audit under 50 · Secrets under 19/13.

### Which become **autonomous agents** (loop / scheduled / event-driven)
- 32 Maintenance · 33 Self-Healing CI · 34 Crash Watchdog · 36 Onboarding · 38 Triage · 42 Debate · 43 Design Critic · 60 Threat Model. These run with `context: fork`, on cron or CI/crash events — not inline.

### Which become **MCP integrations**
- 46 Figma · 26 Codebase Index (graphify MCP) · 34/38 Sentry/Crashlytics MCP · 56/57 pub.dev + OSV MCP · 49 OpenAPI source · 64/22 Play Console · 69 Firebase Test Lab · 19/33 GitHub. Pattern: anything that talks to an external system of record.

### Which become **memory systems** (persistent, cross-session)
- 26 Semantic Index · 35 Telemetry · 63 Decision Ledger · 73 Regression Memory · a Cross-Project Pattern Library (learned reusable patterns). These live under `.flutter-pipeline/` and a global store; they are what let the system *learn*.

### Which **reduce token usage** (pay for themselves immediately)
- 25 Compression · 26 Index · 27 Diff-Scoped Loader · 28 Skill Router · 29 Template Cache · 30 Budget Governor · 31 Handoff Compressor. **Build these first** — every other skill gets cheaper once they exist.

---

## Inspiration Matrix (what we borrow, and from whom)

| Source | Borrowed idea → our skill |
|---|---|
| **Cursor** | Codebase index + apply-model diff edits → 26, 27 |
| **Claude Code** | Skills/subagents/hooks/cron → 28, 32, 35, agent layer |
| **Windsurf** | Cascade "memories" → 63, 73, Pattern Library |
| **Replit Agent** | Autonomous build→deploy→fix → 32, 33 |
| **Devin** | Long-horizon planning + self-debug → 38, 42, 36 |
| **Roo Code** | Modes → 28 Skill Router as "modes" |
| **Copilot** | Inline + PR review → 43, code-review |
| **Lovable / Bolt / v0** | Prompt/image→app, instant preview → 47, 05, 46 |
| **Android Studio** | Build Analyzer, Layout Inspector, Profiler → 37, 39, 40 |
| **FlutterFlow** | Visual builder + integrations → 46, 55 |
| **Figma (Dev Mode)** | Tokens/variables → 46, 04 |
| **GitHub Actions** | CI automation → 33, 68, 21 |
| **Enterprise mobile** | SBOM, threat model, white-label, data safety → 58, 60, 62, 59 |

---

## Prioritized Build Waves

**Wave 1 — Foundation & self-economy (build first; everything else gets cheaper/safer): ✅ SHIPPED**
26 Semantic Index · 25 Context Compression · 30 Token Governor · 41 Analyzer Auto-Fix · 37 Build Doctor · 56 Dependency Health · 43 Design Critic · 70 Test Generation.
*All authored under `skills/NN_*` with runnable scripts (`build_index.py`, `card_index.py`, `estimate.py`, `analyze_fix.sh`, `diagnose.py`, `dep_health.py`) — validated, frontmatter-clean, scripts compile.*

**Wave 2 — Autonomy & integration leverage: ✅ SHIPPED**
27 Diff-Scoped Loader · 28 Skill Router · 33 Self-Healing CI · 38 Triage · 49 OpenAPI Gen · 50 i18n · 44 Visual Regression · 45 A11y Auditor · 59 Privacy Generator · 57 Package Rec · 63 Decision Ledger · 35 Telemetry.
*All 12 skills authored (frontmatter-clean, scripts compile/parse).

**Wave 3 — Enterprise & product depth:**
32 Maintenance · 34 Crash Watchdog · 36 Onboarding · 58 Compliance/SBOM · 60 Threat Model · 61 Secrets · 62 White-Label · 39 Profiler · 40 Leak Auditor · 51 DB Migrations · 52 Push · 53 Background Sync · 54 Flags · 55 Forms · 66 Analytics · 68 Perf Budget · 72 Drift · 73 Regression Memory · 46 Figma.

**Wave 4 — Experimental / frontier:**
42 Debate · 47 Screenshot→Widget · 71 Mutation · 74 Chaos · 69 Test Lab · 64 ASO · 67 A/B · 65 Changelog · 48 Motion Critic · Cross-Project Pattern Library.

---

## Architectural Evolution — the layering principle

Each capability matures down a ladder; not everything needs every rung:

**Skill → Sub-skill → Agent → Workflow → Automation → Integration → Memory → Optimization**

Worked example (error handling lineage):
`15 Error Handling (skill)` → `61 Secrets / 48 critics (sub-skills)` → `38 Triage (agent)` → `Self-Healing CI (workflow)` → `cron + CI-failure hook (automation)` → `Sentry MCP (integration)` → `73 Regression Memory` → `27 Diff-Scoped Loader (optimization)`.

The system becomes *most powerful* not when it has the most skills, but when the **memory + optimization rungs** exist — because then every skill runs cheaper, learns from the last run, and operates unattended. That is the real end-state: a Flutter development system that **builds, observes, heals, learns, and forecasts its own cost.**

---

## Addendum — implemented on request

### 75. User Onboarding & Coach Marks *(SHIPPED)*
- **Purpose:** First-run onboarding intro + in-context ShowcaseView/FeatureDiscovery coach marks, shown only on first launch, with persisted versioned completion state and replay from Settings.
- **Why it matters:** Feature discoverability directly drives activation/retention; most apps either skip it or re-show it forever (the classic persistence bug). Sits in Cluster 4 (UI/UX Intelligence).
- **Status:** Authored at `skills/75_User_Onboarding_And_Coach_Marks/` — SKILL.md + templates (`onboarding_state.dart`, `showcase_setup.dart`, `onboarding_carousel.dart`, `onboarding_settings_tile.dart`). Pairs with stages 03/04/07/08/10/23.
- **Impact:** 8 · **Priority:** High

---

## Stopping condition

Meaningful additions remain as long as any of these are true: a task is still done manually, a failure mode has no owning skill, a decision is re-derived instead of recalled, or a token is spent re-reading what the index already knows. When all four are false, the ecosystem is saturated. We are far from saturated — Wave 1 is the path to the steepest gains.
