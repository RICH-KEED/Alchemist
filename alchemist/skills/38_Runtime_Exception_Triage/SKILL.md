---
name: Runtime Exception Triage
description: Turn a production crash signature into a located, hypothesized, fixable bug. Use when handed a Dart/Flutter stack trace or a Crashlytics/Sentry signature — symbolize it, map frames to file —line via the #26 index, hypothesize the root cause, and propose a fix plus a regression test. Trigger phrases — "triage this crash", "what causes this stack trace", "symbolize this", "deobfuscate this trace", "why is this crashing in prod".
when_to_use: Trigger when a crash/exception arrives from the field — a raw stack trace, an obfuscated release trace, or a Crashlytics/Sentry issue. Part of the token-economy cluster — it reads the #26 semantic index to locate frames instead of grepping lib/**. For the global error contract itself defer to #15; for symbol archival defer to #22; for dashboard wiring defer to #23; record the fix in #73 Regression Memory.
---

# Runtime Exception Triage

A crash landed. Your job is to go from an opaque signature to **a located root cause, a proposed fix, and a guarding regression test** — fast, and cheaply (read the index, not the tree). House style: [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md).

You sit downstream of the whole observability chain: #15 defines the `Failure`/`Result` contract crashes escape from, #22 archives the obfuscation symbols per `versionCode`, #23 routes crashes to the dashboard, #26 holds the `file —line` map. You consume all four to answer one question — **what broke, where, and how do we stop it coming back?**

---

## The triage flow

```
signature ─▶ symbolize ─▶ locate (via #26) ─▶ hypothesize ─▶ propose fix + test ─▶ record (#73)
 (raw/obf)   (#22 syms)   (file:line→entity)  (root cause)   (guard the regression)  (memory)
```

1. **Capture the signature.** The exception type + message + the top app-code frame is the issue's identity (e.g. `Null check operator used on a null value @ profile_controller.dart:42`). Group by this, not by the full trace — the same bug surfaces with many tails.
2. **Symbolize** if obfuscated (see below). A release trace of `#00 abc123` symbols is useless until mapped.
3. **Locate** each top frame via the #26 index — turn `file:line` into the owning **feature / screen / provider / repository** and its blast radius (reverse dependents).
4. **Reproduce the hypothesis.** State the precise condition that triggers it (a null, an empty list, a race, a bad cast) and how a test could drive it.
5. **Propose a fix** at the right layer (guard at the data boundary per #15, not a `?.` band-aid in the widget) **+ a regression test** that fails today and passes after.
6. **Record** the signature → fix in [#73 Regression Memory](../73_Regression_Memory/SKILL.md) so a recurrence is recognized instantly.

---

## Reading Dart / Flutter stack traces

A Dart frame looks like:

```
#0      ProfileController.load (package:my_app/features/profile/application/profile_controller.dart:42:18)
#1      _rootRunUnary (dart:async/zone.dart:1399:47)
```

- `#N` — frame index (0 = innermost, where it threw).
- `package:my_app/...` — **app code** (your package). `dart:`, `package:flutter/`, `package:dio/` — **framework/library** frames. Triage focuses on the **top app-code frame** — the deepest frame in *your* package is almost always the suspect.
- `file:line:col` — exactly what the #26 index keys on. `parse_trace.py` extracts this.

### Obfuscated vs not

Release builds run `--obfuscate --split-debug-info=build/symbols` (#22 §3), so symbols are renamed and the trace is **not human-readable**:

```
*** *** ***
pid: 1234, tid: 5678, name 1.ui
build_id: '0a1b2c3d...'
isolate_dso_base: 7f..., vm_dso_base: 7f...
#00 abs 000000722... virt 000000000... _kDartIsolateSnapshotInstructions+0x...
```

Tells it is obfuscated: no `package:`/`dart:` paths, raw `abs`/`virt`/`+0x` addresses, a `build_id`/`isolate_dso_base` header, `_kDartIsolateSnapshotInstructions`. `parse_trace.py` **flags this** (`obfuscated: true`) and tells you to symbolize first.

### `flutter symbolize`

Map an obfuscated trace back to symbols using the **archived debug-info for that exact `versionCode`** (#22 archives one symbol dir per release — wrong version = garbage output):

```bash
flutter symbolize -i crash.txt -d build/symbols/app.android-arm64.symbols
```

- `-i` the saved trace, `-d` the matching `.symbols` file. Output is a normal `package:`-path trace — feed *that* to `parse_trace.py`.
- Dashboard traces (Sentry/Crashlytics) arrive **already symbolicated** if the mapping/debug-info was uploaded in the #22/#23 release job — then skip this step. If they look like raw addresses, the symbol upload was missed (a #23 gate failure) — fix that, don't hand-decode.

---

## Locate frames via the #26 index (don't grep the tree)

The top app-code frame gives `lib/.../foo.dart:42`. Query `.flutter-pipeline/index.json` (built by [#26](../26_Codebase_Semantic_Index/SKILL.md)) instead of walking `lib/**`:

- **Frame → owning entity** — find the entity whose `file` matches and whose `line` is the nearest declaration at/above 42 → the **provider / repository / screen** that owns the crash.
- **Blast radius** — `files[]` where `dependsOn` contains that file → everything that could trip the same bug (where the regression test should also assert).
- **Feature context** — the entity's `feature` tells you which slice of the app and who else touches its state.

If the index is stale (`STALE` entity / file moved), rebuild with `--incremental` before trusting it (#26). Only fall back to `Read`/`Grep` when a frame is in code the index doesn't cover (generated files, `main.dart`).

---

## Severity / priority triage

Score every crash on two axes, then act:

| | **Severity** (how bad per hit) | **Frequency** (how many / how often) |
|---|---|---|
| Signal | data loss, security, money, crash-on-launch, core-loop blocked | crash-free-users % drop, # sessions, # distinct users, trend ↑ |
| Source | the exception type + which flow | #23 dashboard counts; rollout stage (#22) |

Priority = severity × reach:

- **P0 — drop everything.** Crash-on-launch, data loss/corruption, security, or a spiking crash on a live staged rollout. Halt the rollout (#22 §5), fix-forward.
- **P1 — this sprint.** Core-loop crash hitting many users; degraded but app survives.
- **P2 — backlog.** Rare, recoverable, edge-device or narrow-condition; low reach.

A trace with **no app-code frame** (pure framework/plugin) is usually a misuse pattern or a dependency bug — note it, check the plugin's issues, and guard at *your* call site.

---

## Outputs

Produce a triage report using [`templates/triage_report.md`](templates/triage_report.md): **signature · symbolized top frames · suspected file/widget/provider · hypothesis · proposed fix · regression test · severity/priority**. Then:

- Open/annotate the issue (link the #23 dashboard issue + the #26 entity).
- Hand the fix to the relevant build skill (#15 for the error path, the feature's stage).
- **Record the signature → root cause → fix in [#73](../73_Regression_Memory/SKILL.md)** — this is what turns a one-off triage into institutional memory.

---

## Worked example

**Incoming (Sentry, release, symbolicated):**

```
Null check operator used on a null value
#0  ProfileController.build (package:my_app/features/profile/application/profile_controller.dart:42:31)
#1  _NotifierBase._setStateResult (package:riverpod/src/notifier.dart:...)
#2  ...
crash-free users: 98.1% ▼ from 99.9% over last release · 1,204 sessions · 388 users
```

**1. Symbolize** — already symbolicated (has `package:` paths). `parse_trace.py` confirms `obfuscated: false`.

**2. Top app-code frame** — `profile_controller.dart:42` (frame #1 is `package:riverpod`, framework — skip).

**3. Locate via #26** —

```bash
python3 "${CLAUDE_SKILL_DIR}/scripts/parse_trace.py" crash.txt --json
# top_app_frames[0] = {file: lib/features/profile/.../profile_controller.dart, line: 42, symbol: ProfileController.build}
```

Index lookup → entity `provider:...#profileControllerProvider` (`feature: profile`). Reverse edges → `profile_screen.dart` watches it. Read `profile_controller.dart:42`:

```dart
final user = ref.watch(authProvider).valueOrNull;
return ProfileView(name: user!.displayName);   // line 42 — `user!`
```

**4. Hypothesis** — `authProvider` is `null` while auth is still loading or after sign-out; the `!` throws. Spiked because the last release added a sign-out button on this screen (the new null path).

**5. Proposed fix** — remove the `!`; pattern-match the auth state and render the loading/empty state (#16) instead of asserting non-null. The real fix lives at the boundary: the controller should not assume an authenticated user.

```dart
final user = ref.watch(authProvider).valueOrNull;
if (user == null) return const SignedOutView();   // explicit state, no `!`
return ProfileView(name: user.displayName);
```

**6. Regression test** — drive the controller with a `null`/signed-out auth override and assert it yields `SignedOutView`, not a throw:

```dart
test('profile renders signed-out state when user is null (was: null-check crash)', () {
  final c = ProviderContainer(overrides: [authProvider.overrideWith(() => SignedOutAuth())]);
  expect(() => c.read(profileControllerProvider), returnsNormally);
});
```

**7. Severity** — P1: core screen, 388 users, regression from the last release; not data-loss, app recovers. Halt rollout ramp until fixed. Record signature `NullCheck@profile_controller.dart:42` → fix in #73.

---

See the index/query mechanics in [#26](../26_Codebase_Semantic_Index/SKILL.md), symbol archival in [#22](../22_Deployment/SKILL.md), and the error contract in [#15](../15_Error_Handling/SKILL.md). Full house style: [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md).
