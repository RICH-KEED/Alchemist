---
name: State Leak Auditor
description: Scan a Flutter/Dart project for undisposed controllers, uncancelled subscriptions, missing autoDispose on Riverpod providers, and other resource leaks that drain memory or keep dead listeners alive. Use when you want to audit a codebase for leaks — pre-commit, in CI, or as a one-shot health sweep.
when_to_use: Trigger on "scan for leaks", "find undisposed controllers", "check Riverpod autoDispose", "audit memory leaks", "leak check the project", "run the leak auditor", or any request to find AnimationController / StreamSubscription / TextEditingController / Timer / FocusNode resources that are never disposed. Pairs with #41 (Analyzer Auto-Fix) for dispose-related lints and #33 (Self-Healing CI) for automated leak gating in CI.
---

# State Leak Auditor (Roadmap #40)

A leak is a resource that outlives its owner — a controller never `.dispose()`d, a stream
subscription never `.cancel()`ed, a Timer running after the widget is gone. This skill scans
every `.dart` file in a project and surfaces every high-signal match, ranked by severity.
House style: [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md).

## 1. What it scans for — the leak catalog

| # | Leak pattern | Signature | Why it leaks |
|---|---|---|---|
| 1 | **AnimationController** | Instance created, `.dispose()` absent in same file | Holds a `Ticker` that keeps the render loop alive after the widget tree detaches |
| 2 | **StreamSubscription** | `.listen(` with no matching `.cancel()` | Keeps a callback registered on a stream that may never close; GC cannot collect the closure |
| 3 | **TextEditingController** | Constructor call, no `.dispose()` | Retains a `ValueNotifier` and focus attachment; text fields outlive their owning state |
| 4 | **FocusNode** | `FocusNode(` without `.dispose()` | Holds a focus attachment in the focus tree; leaks focus traversal state |
| 5 | **Timer** (periodic / one-shot) | `Timer(` or `Timer.periodic(` without `.cancel()` | Callback fires after the widget is unmounted or the isolate has no reason to keep running |
| 6 | **ScrollController** | `ScrollController(` without `.dispose()` | Holds scroll position listeners; keeps a `ScrollPosition` alive past widget removal |
| 7 | **PageController** | `PageController(` without `.dispose()` | Same family as ScrollController; holds page-position state |
| 8 | **VideoPlayerController** | `VideoPlayerController.*(` without `.dispose()` | Holds platform-channel handles and native media resources |
| 9 | **Riverpod provider — missing autoDispose** | `@riverpod` or `@Riverpod()` annotation with no `autoDispose` modifier in the provider declaration | Provider retains state for the lifetime of `ProviderScope` instead of being garbage-collected when no longer watched; rebuilds on stale data |

See [`templates/leak_patterns.md`](templates/leak_patterns.md) for the full catalog with
before/after fix snippets and severity ratings.

## 2. How it works

The scan is a **two-pass regex sweep** run by
[`scripts/scan_leaks.py`](scripts/scan_leaks.py):

**Pass 1 — Controller/subscription leaks.** For each `.dart` file, the scanner looks for
creation patterns (`AnimationController(`, `StreamSubscription`, `TextEditingController(`, etc.)
and then checks whether the corresponding teardown call (`.dispose()`, `.cancel()`) appears
anywhere in the same file. A file that creates a resource but never tears it down is a
high-signal match.

**Pass 2 — Riverpod autoDispose.** The scanner finds every `@riverpod` or `@Riverpod()`
annotation and checks whether `autoDispose` appears in the same declaration context. Providers
without `autoDispose` are flagged.

Because regex cannot trace ownership (was the controller **created here** or **passed in from a
parent**?), every match requires a manual triage pass. The scanner helps you focus by ranking
hits by severity and letting you suppress false positives.

Run it:

```bash
# Basic scan (reports controller + Riverpod leaks)
python scripts/scan_leaks.py lib/

# JSON output (machine-readable — for CI gating)
python scripts/scan_leaks.py lib/ --json

# Only critical + high severity
python scripts/scan_leaks.py lib/ --severity high

# Skip the controller-dispose check (Riverpod-only scan)
python scripts/scan_leaks.py lib/ --no-require-dispose-in-file

# Skip the Riverpod check (controller-only scan)
python scripts/scan_leaks.py lib/ --no-check-riverpod-autodispose
```

## 3. Interpreting results

Every result includes `file`, `line`, `category`, and `severity`. Not every match is a real leak:

| Signal | Likely true positive | Likely false positive |
|---|---|---|
| `AnimationController(` in a `State` class, no dispose | **Yes** — the State owns it | `vsync: this` in a widget that passes the controller to a child that disposes it |
| `TextEditingController(` assigned to a local, no dispose | **Yes** — owned here | Constructor-injected controller (e.g. `const MyField(controller: this._controller)`) |
| `StreamSubscription` stored in a field, no cancel | **Yes** — subscription outlives | `.listen()` in `initState` with `.cancel()` in `dispose()` — scanner may miss if the file is long |
| Riverpod provider without `autoDispose` | **Yes** — unless the provider is a singleton that must live forever | A `@riverpod` whose generated provider is used as a global cache (rare — usually you still want `autoDispose`) |

### Severity levels

| Level | Meaning | Action |
|---|---|---|
| **critical** | Deterministic leak — resource created in init/constructor; no teardown path exists | Fix immediately; this is a shipping memory leak |
| **high** | High-confidence leak — resource created in a StatefulWidget or Notifier; dispose path missing | Fix before next release |
| **medium** | Possible leak — resource may be owned externally; needs human triage | Review within the sprint |
| **low** | Low-confidence or cosmetic — Riverpod provider that may legitimately be long-lived | Note and close if intentional |

## 4. Fix patterns

Every fix follows the same shape: **create in `initState` / constructor, dispose in `dispose()`**.

### Before (leaking)

```dart
class _MyWidgetState extends State<MyWidget> {
  late final AnimationController _anim = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 300),
  );
  // ... no dispose() override
}
```

### After (fixed)

```dart
class _MyWidgetState extends State<MyWidget> {
  late final AnimationController _anim = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 300),
  );

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }
}
```

### Riverpod — before / after

```dart
// BEFORE: leaks state for ProviderScope lifetime
@riverpod
class MyNotifier extends _$MyNotifier { ... }

// AFTER: auto-disposed when no longer watched
@Riverpod(keepAlive: false)
class MyNotifier extends _$MyNotifier { ... }
```

Use `keepAlive: false` (the `autoDispose` equivalent in codegen syntax) or the
`autoDispose` modifier on function providers:

```dart
@riverpod
Future<List<Item>> items(ItemsRef ref) async { ... }
// -->
@riverpod
Future<List<Item>> autoDisposeItems(AutoDisposeItemsRef ref) async { ... }
```

For `StreamSubscription`, cancel in `dispose()` or use `ref.onDispose()` / `ref.onCancel()`
in Riverpod providers:

```dart
@override
void dispose() {
  _subscription.cancel();
  super.dispose();
}
```

## 5. Integration points

| Integration | How | Benefit |
|---|---|---|
| **Pre-commit hook** | `python scripts/scan_leaks.py lib/ --severity critical` in `.pre-commit-config.yaml` | Blocks commits that introduce a deterministic leak |
| **CI gate** | Add a `leak-scan` job that runs `scan_leaks.py --json` and fails on critical hits | Catches leaks before they reach `main` |
| **Ad-hoc audit** | Run `scan_leaks.py lib/ --severity high` before a release | One-shot health sweep |
| **#33 Self-Healing CI** | CI job runs the scan; critical hits block the pipeline and open an issue | Leak = red CI |
| **#41 Analyzer Auto-Fix** | Pairs with lints like `use_dispose`, `cancel_subscriptions`, and `close_sinks` | Mechanical fixes for patterns the linter can prove |

## 6. Limitations (and why the human is in the loop)

- **Ownership is semantic, not syntactic.** The scanner cannot distinguish "I created this
  controller" from "I received this controller from a parent." A human must triage.
- **Indirect disposal.** A controller passed to a child that disposes it won't show `.dispose()`
  in the owning file — a false positive the human dismisses.
- **Generated code.** The scanner skips `.g.dart` and `.freezed.dart` files.
- **Riverpod codegen syntax.** `@Riverpod(keepAlive: false)` is the codegen way to get
  `autoDispose`. The scanner checks for both the `autoDispose` keyword and the `keepAlive:
  false` annotation parameter.

---

See the full leak catalog in [`templates/leak_patterns.md`](templates/leak_patterns.md) and
house style in [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md).
