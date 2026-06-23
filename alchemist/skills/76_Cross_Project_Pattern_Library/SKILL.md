---
name: Cross-Project Pattern Library
description: Accumulate proven reusable patterns learned across Flutter projects into a global session-persistent store (~/.flutter-pipeline/patterns.json) — and consult that store before generating solutions from scratch. A pattern is a canonical problem+context+solution triple that has been proven across N projects. Use when a new task's context matches a known pattern — load the proven solution first to cut tokens and improve quality. Also use after a successful PR that introduced or refined a pattern worth remembering — propose the pattern, let the system track adoption, and promote it when it has solid project evidence.
when_to_use: Trigger on "remember this pattern for next time" — "add this to the pattern library" — "has this pattern been used before?" — "load known patterns for this task" — "what does the library know about <concern>?" — "query patterns matching <context>" — or whenever a stage skill (08/15/16/etc.) is about to generate boilerplate — consult the library first. Also trigger automatically after a PR that solves a recurring problem (the orchestrator invokes this stage to capture the learning).
---

# Cross-Project Pattern Library

Your job: make the skill pipeline *learn*. Every time a pattern succeeds across multiple projects, capture it so the system gets smarter — not harder to use.

The pattern store lives at `~/.flutter-pipeline/patterns.json` and is **session-persistent**: patterns added by any project survive beyond that project's pipeline and are available to every future pipeline run. This is the system's "learned experience."

You are not a code snippet library. You are a **context-qualified solution catalog**: you store the *conditions* under which a pattern applies, the *gist* of the solution, and the *projects* that proved it. A pattern without its context is worse than no pattern — it gets cargo-culted into situations that do not match.

House style is fixed in [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md). When a pattern's advice disagrees with CONVENTIONS, CONVENTIONS wins — update the pattern.

**Key resources:** the JSON schema at [`templates/pattern_schema.json`](templates/pattern_schema.json), an annotated example at [`templates/pattern_entry.md`](templates/pattern_entry.md), and the query script at [`scripts/query_patterns.py`](scripts/query_patterns.py).

---

## What qualifies as a pattern (quality bar)

A pattern earns a place in the library when it meets **all** these criteria:

1. **Recurring problem** — the same challenge appeared in at least **2 projects** (or 1 project with a strong argument it generalizes). Single-use tricks are notes, not patterns.
2. **Non-trivial solution** — it is not "use `freezed`" or "call `riverpod_generator`" (those are the house stack, CONVENTIONS owns them). A pattern has *interaction* between two or more concerns: state + network + rollback, design tokens + responsive breakpoints, error mapping + analytics logging.
3. **Context-dependent** — the pattern is NOT always the right answer. It has documented `when_not` conditions: cases where it looks appealing but is the wrong tool. These guardrails are what make the library safe to consult automatically.
4. **Proven** — backed by a working implementation that passed review / tests / QA. A `confidence` field tracks how solid the evidence is (see lifecycle below).
5. **Owned** — every pattern references the skills that define the contracts it depends on (08 for Riverpod, 15 for Result, etc.). Patterns do not redefine the house stack — they compose it.

---

## Pattern anatomy

A library entry follows the schema at [`templates/pattern_schema.json`](templates/pattern_schema.json). The essential fields:

| Field | Purpose |
|---|---|
| `id` | Unique key: lowercase, hyphenated (e.g. `optimistic-toggle-rollback`) |
| `problem` | Statement of "when this happens..." — the trigger condition, in plain language |
| `context_tags` | Categorization tags: feature area + concerns (state, network, UI, error, etc.) — used by the query engine for matching |
| `solution_summary` | One sentence: what to do and why it works |
| `full_solution` | The canonical implementation pattern — narrative, not copy-paste code; references skill templates and contracts |
| `when_not` | Conditions that **disqualify** this pattern — the anti-pattern guard. The most important field after `solution_summary`. |
| `example_code` | A key snippet (10-30 lines) showing the pattern's characteristic shape |
| `projects_used` | List of project names and stage numbers where this pattern was applied and proved |
| `confidence` | `proposed` (one project), `emerging` (2-3 projects), `established` (4+ projects, owned by a skill) |

---

## Pattern lifecycle: propose → prove → promote

### 1. `proposed`
A pattern is created after a **successful PR** that introduced a reusable solution. At this stage it has 1 project, `confidence: proposed`. It is available to the query engine but returned with lower match scores — it is a suggestion, not a recommendation.

### 2. `emerging`
When the same pattern is successfully applied in a second or third project, increment `projects_used` and bump confidence to `emerging`. The query engine boosts its score. The pattern now carries a "likely transferable" signal.

### 3. `established`
After 4+ projects, the pattern is `established`. At this point it may be **promoted into a skill template** — the canonical version moves to the owning skill's `templates/` folder and the library entry becomes a pointer. The `full_solution` is shortened to "see skill NN templates/X" and `confidence: established`.

### When to add a pattern
- After a PR that introduced a **non-obvious interaction** (state + network, animation + gesture, error + analytics).
- When the reviewer remarks "this is clever, we should do this everywhere."
- When the orchestrator detects the same boilerplate was written the same way in two consecutive pipeline runs.

### When NOT to add a pattern
- A trivial single-framework feature (file was "add `@riverpod` class" — that is the skill template, not a pattern).
- A project-specific hack that will not generalize (an API quirk, a design-team preference).
- Something the skill contract already covers (CONVENTIONS §5-6 own Result + Riverpod — do not duplicate).

---

## Consulting the library before generating

When a stage skill (08, 11, 14, 15, 16, etc.) is invoked, follow this sequence:

1. **Derive context tags** from the task description and the pipeline stage. E.g. "toggle favorite — optimistic mutation" → tags: `state`, `network`, `mutation`, `optimistic`, `riverpod`.
2. **Query the library** by running `scripts/query_patterns.py` with a free-text summary of the task, or by reading `~/.flutter-pipeline/patterns.json` directly if the script is not available. The script scores patterns by tag overlap + problem statement match.
3. **If a match with score > threshold**: load the pattern's `full_solution`. Present it to the user as "the library has seen this before — here is the proven approach." Adapt it to the current project's types and names. This cuts generation tokens (the reasoning is already done) and improves quality (edge cases were caught in prior projects).
4. **If no match**: generate from scratch using the owning skill's guidance. After the PR lands, evaluate whether the solution is pattern-worthy (see "When to add" above). If yes, propose it.

The orchestrator (skill 01) calls this skill at two points:
- **Pre-generation**: before invoking a build stage, to check for relevant patterns.
- **Post-PR**: after a successful PR, to capture any new patterns the work revealed.

---

## The anti-pattern: cargo-culting without context match

The highest-value field in a pattern is `when_not`. A pattern that makes sense for a slow-mutating toggle on a cached list (optimistic update is fine — the user can undo) is disastrous for a payment confirmation (you cannot "optimistic" a charge).

Before applying any pattern, check:
- Does the **context** match? (Read the pattern's `problem` and `context_tags` — not just the title.)
- Could the `when_not` conditions **apply here**? If any do, do not use the pattern.
- Did the user **request** the pattern's behavior? (Do not add optimistic rollback just because it is in the library — only if the UX issue is visible latency on a safe mutation.)
- Are the **owned skills' contracts** respected? (The pattern may embed Riverpod patterns — ensure stage 08 has been run and the project is on Riverpod.)

When in doubt, generate fresh and capture later. It is always cheaper to write new code than to debug a misapplied pattern.

---

## How to add a pattern after a successful PR

1. **Identify the pattern shape.** Read the PR diff. Extract the problem it solved, the context tags, the solution gist, and the disqualifying conditions.
2. **Check for duplicates.** Search existing patterns by `context_tags` overlap — if one already covers this, update that entry's `projects_used` and `confidence` instead of creating a duplicate.
3. **Draft the entry** using the schema at [`templates/pattern_schema.json`](templates/pattern_schema.json). Fill every field. See [`templates/pattern_entry.md`](templates/pattern_entry.md) for a worked example.
4. **Validate.** Run `python3 scripts/query_patterns.py --validate` to check the new entry conforms to the schema (if the script supports it), or manually verify field completeness.
5. **Write to `~/.flutter-pipeline/patterns.json`.** If the file does not exist, create it with the top-level structure: `{"version": "1", "patterns": []}`. Append the new pattern to the `patterns` array.
6. **Report** the new pattern ID, confidence level, and any related patterns the user should also consider.

---

## Example: optimistic toggle with rollback

This is the library's "hello world" — one of the first patterns captured. It comes from skills 08 (Riverpod controller) and 70 (test generation), and is documented in full at [`templates/pattern_entry.md`](templates/pattern_entry.md).

- **Problem**: user taps a toggle (favorite, read/unread, pin). The network round-trip adds visible lag that feels broken.
- **Context**: Riverpod screen controller (AsyncNotifier), repository returning `Result<T>`, mutation that can fail.
- **Solution**: show the toggled state immediately (optimistic), persist in background, roll back on failure + surface error.
- **When NOT**: mutations that are not safely reversible (payments, deletes, permission grants).

The canonical controller shape is in skill 08's [`example_controller.dart`](../08_Riverpod/templates/example_controller.dart) (`toggleFavorite` method). The test that proves the rollback is in skill 70's [`generated_notifier_test.dart`](../70_Test_Generation/templates/generated_notifier_test.dart) (group `CatalogController.toggleFavorite`, test `rollback: Err restores the pre-toggle state`).

---

## Output workflow

1. **On query**: load `~/.flutter-pipeline/patterns.json`, score each pattern against the task's context tags and problem description, return the top match (with confidence) or report "no match."
2. **On add**: validate the new entry against the schema, write to the JSON file, report the new pattern ID and confidence level.
3. **On promote**: update `confidence`, optionally shrink `full_solution` to a pointer, and — if the owning skill agrees — copy the canonical template to that skill's `templates/` directory.

The query script at [`scripts/query_patterns.py`](scripts/query_patterns.py) is a runnable Python3 stdlib tool that reads the store, scores entries, and prints the top match. Use `--json` for machine-readable output (useful for embedding in orchestrator decisions).

---

## Schema

The canonical schema for a pattern entry is at [`templates/pattern_schema.json`](templates/pattern_schema.json). All entries in `~/.flutter-pipeline/patterns.json` must validate against it. Fields in the schema that are not in the above table are explained by the schema's own `description` annotations.
