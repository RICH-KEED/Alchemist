# Pattern: optimistic-toggle-rollback

A filled, annotated example of a pattern library entry. This is the first pattern any project should capture — it is the "hello world" of the pattern library and comes directly from skills 08 (Riverpod) and 70 (test generation).

Each field in this example corresponds to the schema in [`pattern_schema.json`](pattern_schema.json). Use this as a template when drafting new pattern entries: replace the content but keep the structure.

---

```json
{
  "id": "optimistic-toggle-rollback",
  "problem": "When the user toggles a state (favorite, read/unread, pin, bookmark) and the network round-trip causes visible lag (>100ms), the UI feels broken — the toggle appears to be ignored, then jumps to the new state. Users often tap again before the response arrives, creating a double-toggle race.",
  "context_tags": [
    "state",
    "network",
    "mutation",
    "optimistic",
    "riverpod",
    "error",
    "rollback",
    "async-notifier"
  ],
  "solution_summary": "Show the toggled state immediately (optimistic), persist in background via the repository, and roll back to the previous state on failure — surfacing the error as AsyncError so the UI can show a retry affordance.",
  "full_solution": "The controller's mutation method does three things atomically: (1) snapshot the current state before the mutation, (2) call the repository's toggle method wrapped in AsyncValue.guard so any thrown Failure becomes AsyncError, (3) on success, emit the new state with the toggled item replaced; on failure, AsyncValue.guard preserves the previous value on the AsyncError — the UI sees the rollback automatically because the optimistic change never committed to state.\n\nThe controller shape is the standard @riverpod AsyncNotifier from skill 08 (see ../08_Riverpod/templates/example_controller.dart, method toggleFavorite). The key mechanics: the repository returns Result<T> (Ok/Err per CONVENTIONS §5), the controller unwraps Ok or rethrows the Failure, and guard catches it. The actual rollback is not manual — it is a property of AsyncValue.guard: when the callback throws, state is set to AsyncError carrying the previous value, which is what the UI was already rendering before the optimistic toggle.\n\nThe test that proves this pattern works is skill 70's generated rollback test (see ../70_Test_Generation/templates/generated_notifier_test.dart, group 'CatalogController.toggleFavorite', test 'rollback: Err restores the pre-toggle state and surfaces error'). The test asserts: (a) the pre-toggle boolean is preserved after the failed mutation, (b) the error is surfaced as AsyncError with the correct Failure type, (c) the repository was called exactly once.",
  "when_not": "Do NOT use optimistic toggle for mutations that are not safely reversible if the persist fails — payments, deletes, permission grants, anything with a side effect the user cannot undo. Do NOT use when the toggled state must be server-authoritative before the UI updates (e.g. stock quantity, seats remaining — showing the optimistic value then rolling back is worse UX than showing a spinner). Do NOT use for mutations that are fast (<50ms) and the optimistic flicker is more distracting than a brief loading indicator. Do NOT use when the mutation requires server-computed data to render (e.g. a 'like count' that changes non-linearly) — the optimistic value will be wrong and the correction is jarring.",
  "example_code": "// Inside an @riverpod AsyncNotifier controller.\n// This is the characteristic optimistic-toggle shape.\nFuture<void> toggleFavorite(String id) async {\n  final current = state.valueOrNull;\n  if (current == null) return; // not yet loaded — no-op\n\n  state = await AsyncValue.guard(() async {\n    // The repo returns Ok(updatedItem) or Err(Failure).\n    final res = await ref.read(repoProvider).toggleFavorite(id);\n    final updated = switch (res) {\n      Ok(:final value) => value,      // persist succeeded\n      Err(:final failure) => throw failure, // guard → AsyncError + rollback\n    };\n    // Replace the toggled item in the local list with the server response.\n    final items = [\n      for (final i in current.items)\n        if (i.id == id) updated else i,\n    ];\n    return current.copyWith(items: items);\n  });\n  // If guard caught a Failure, state is now AsyncError with the\n  // PRE-mutation value preserved — the optimistic change never committed.\n}",
  "projects_used": [
    {
      "name": "catalog-app-reference",
      "stage": 8,
      "date": "2026-06-01"
    },
    {
      "name": "catalog-app-reference",
      "stage": 70,
      "date": "2026-06-10"
    }
  ],
  "confidence": "emerging",
  "date_captured": "2026-06-01",
  "last_updated": "2026-06-23",
  "related_patterns": [],
  "owned_by_skill": 8,
  "prerequisites": [
    "Riverpod 2.x with @riverpod codegen",
    "skill 08 (Riverpod) completed — AsyncNotifier pattern",
    "skill 15 (Error_Handling) completed — Result<T> / Failure hierarchy",
    "Repository returning Future<Result<T>>",
    "AsyncValue.guard for error catching"
  ]
}
```

---

## Field-by-field commentary

- **`id`**: Stable key. Never rename — cross-references break. Use the problem domain, not the project: `optimistic-toggle-rollback`, not `catalog-favorite-toggle`.
- **`problem`**: Written as a **condition the developer feels**, not an abstract statement. "The UI feels broken" is a valid problem statement — it names the user-visible symptom.
- **`context_tags`**: These drive the query engine. Choose tags that a SEARCH for this problem would use. Prefer two-word tags: `optimistic` alone is too broad; `optimistic mutation` is better but we already have `mutation` as a separate tag — the overlap is the match signal.
- **`solution_summary`**: If someone reads nothing else, they should get the pattern. One sentence, active voice, names the mechanism.
- **`full_solution`**: Narrative, not code dump. References skill templates by path. Explains **why** each step, not just what. When the pattern is `established`, this shrinks to "see skill NN templates/X" — the canonical code lives there.
- **`when_not`**: This is the most important field after `solution_summary`. Be exhaustive here — every bad application of this pattern is a bug you prevented.
- **`example_code`**: The signature move in 10-30 lines. Not the full controller — just the method that IS the pattern. Line comments point at the parts that are pattern-specific, not generic Riverpod boilerplate.
- **`projects_used`**: Two entries from the same project is correct here because stages 8 and 70 both exercised the same pattern (controller + test), building the 2-project evidence trail. When a second *real* project applies it, add a third entry.
- **`confidence: emerging`**: 2 uses (across two stages) = emerging. It needs one more project to reach `established`.
- **`owned_by_skill: 8`**: The canonical controller template lives in skill 08. When `confidence` reaches `established`, the `full_solution` here should shrink to a pointer.

---

## How to use this template

1. Copy this file's JSON block.
2. Replace every field value with content for your pattern.
3. Delete fields you do not need (`related_patterns` if none, `owned_by_skill` if not yet promoted).
4. Validate against [`pattern_schema.json`](pattern_schema.json) before writing to the store.
5. Write the entry to `~/.flutter-pipeline/patterns.json`.
