---
name: Testing
description: Build the app's test strategy and infrastructure — the test pyramid for this stack (lots of unit on domain/application, focused widget tests, a few golden + integration), Riverpod ProviderScope overrides in widget tests, golden tests in light+dark at fixed sizes, integration smoke flows, test-data builders/fakes, and a coverage gate wired into CI. Use when the user says "write tests", "set up testing", "add widget/golden/integration tests", "raise coverage", or the orchestrator enters stage 20.
when_to_use: Stage 20 of the pipeline — run after the feature build stages (09–17) so there is real UI and state to test. Trigger on "test this screen", "golden test", "integration test", "coverage gate", "ProviderScope override in a test", or "is this feature done". For data-layer/API tests (mock dio, DTO parsing, repository→Failure mapping) invoke skill 12 — do not duplicate it here. For provider-override unit tests of a single notifier see skill 08. Hand the CI wiring off to skill 21.
---

# Testing (Stage 20)

You own the app's **overall test strategy and infrastructure**: unit, widget, golden, and integration tests, the pyramid that balances them, and the coverage gate that CI enforces. You fold in the data-layer suite from **skill 12** and the controller tests from **skill 08** — you do not re-write them — and add the layers above: widget tests that pump real screens with overridden providers, goldens that pin rendered pixels in light + dark, and a thin integration smoke flow.

House style is fixed in [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md) (§7 *Definition of Done* and the stack table §1). When in doubt, that file wins.

**Output artifact:** `test/` (unit · widget · golden) + `integration_test/` + `test/support/` helpers + a coverage threshold checked in CI.
**Exit gate:** *coverage gate met; CI test job green.*

Stack: `flutter_test` · **mocktail** · golden (built-in `matchesGoldenFile`, or `alchemist` for multi-theme) · `integration_test` · `flutter test --coverage` → `lcov`.

---

## The test pyramid for this stack

Most coverage, lowest cost at the bottom; few, expensive tests at the top.

| Layer | What | How many | Speed | Skill |
|---|---|---|---|---|
| **Unit** | pure domain logic (value objects, mappers, `Result`), application notifiers via `ProviderContainer` | **the bulk** | ms | 08 (notifiers), 12 (data layer), here (domain) |
| **Widget** | one screen/widget pumped in a `ProviderScope` with fakes; states + interactions | a focused set — the screens that matter | tens of ms | **here** |
| **Golden** | pixel-pin a component in light + dark at fixed sizes | a few per key component | tens of ms | **here** (ties to 17) |
| **Integration** | the app (or a big slice) driving a real flow on a device/emulator | a handful of smoke flows | seconds | **here** |

Rules of thumb:
- Push a test **down** the pyramid whenever you can — if pure logic can be unit-tested, don't reach for a widget test to cover it.
- Domain layer (`domain/`) should be near-exhaustively unit-tested: it has no Flutter, no IO, so there's no excuse.
- Widget-test the **states and interactions** a user can hit, not every pixel — pixels are goldens' job.
- Keep integration tests to **happy-path smoke flows**: launch → navigate → core action → assert. They prove the wiring; unit/widget tests prove the logic.

---

## Unit testing (domain + application)

Two flavors, both fast and offline:

1. **Pure logic** — value objects, mappers, extension methods, `Result` helpers. Plain `test()`, no Flutter binding, no mocks. Assert inputs → outputs and every `switch` branch.
   ```dart
   test('Email.parse rejects a missing @', () {
     expect(Email.parse('nope'), isA<Err<Email>>());
   });
   ```
2. **Notifiers/controllers** — drive an `@riverpod` AsyncNotifier through a `ProviderContainer` with its repository overridden by a mocktail fake; assert loading→data and the error path. **This is skill 08's territory** — its [`controller_test.dart`](../08_Riverpod/templates/controller_test.dart) is the canonical template. Reuse it; don't re-derive the pattern here.

For the **data layer** (data sources, DTO parsing, repository → `Failure` mapping against a mocked `dio`), use **skill 12** and its fixtures. This skill *consumes* that suite into the full run and the coverage number — it does not duplicate it.

---

## Widget testing — `ProviderScope(overrides:)` + `pumpWidget`

A widget test renders a real widget tree against fake dependencies and exercises it. The shape that works for this stack:

1. **Override the providers** the screen depends on (controller's repo, or the controller itself) with mocktail fakes, inside a `ProviderScope`. Wrap in a `MaterialApp` so `Theme`, `Directionality`, and `Navigator` exist. Use the `pumpApp` helper in [`templates/test_helpers.dart`](templates/test_helpers.dart) so every test gets the same wrapper.
   ```dart
   await tester.pumpApp(
     const ProfileScreen(),
     overrides: [profileRepositoryProvider.overrideWithValue(fakeRepo)],
   );
   ```
2. **Find** with semantic finders — `find.text`, `find.byType`, `find.byKey`, `find.byIcon`. Prefer keys/`Semantics` over brittle text where text may change.
3. **Pump frames deliberately:**
   - `pump()` — advance **one** frame. Use it to observe the **loading** state before async resolves.
   - `pump(Duration)` — advance by a fixed time (a specific animation step).
   - `pumpAndSettle()` — pump until no frames are scheduled. Use after a tap that triggers a transition/animation. **Never** call it on an infinitely-animating widget (a spinner) — it will time out; use `pump()` there.
4. **Assert state transitions:** first frame shows loading, after the future resolves shows data; then tap and assert the result.
   ```dart
   expect(find.byType(CircularProgressIndicator), findsOneWidget); // loading
   await tester.pump();                                            // resolve
   expect(find.text('Ada Lovelace'), findsOneWidget);             // data
   await tester.tap(find.byKey(const Key('refresh')));
   await tester.pumpAndSettle();
   ```
See [`templates/widget_test.dart`](templates/widget_test.dart) for the full loading→data + tap test.

**Mock async with mocktail:** `when(() => repo.fetch()).thenAnswer((_) async => Ok(data))`; for a controlled delay use a `Completer` so you can assert the loading frame, then complete it. Verify interactions with `verify(() => repo.save(any())).called(1)`. Register fallbacks for custom argument types with `registerFallbackValue` in `setUpAll`.

---

## Golden tests (light + dark, multiple sizes)

A golden test renders a widget and compares it byte-for-byte against a committed reference PNG. It catches *visual* regressions unit/widget tests miss. This is where **skill 17**'s "goldens across sizes" requirement lands.

What to golden, and how:
- **Pick stable components** — a card, an empty state, a populated list row — not whole flaky screens with live data or time.
- **Render each in light *and* dark** (CONVENTIONS §4: both themes are first-class) and at the **device sizes** that matter (phone, tablet) — one golden per theme × size. See [`templates/golden_test.dart`](templates/golden_test.dart).
- **Determinism is everything** — a golden that drifts on a different machine is worse than none:
  - **Load real fonts.** The default test font is `Ahem` (boxes). Call `loadAppFonts()` (from `golden_toolkit`/`alchemist`) or load your `.ttf` via `FontLoader` in `flutter_test_config.dart` so text renders consistently.
  - **Pin size** with `tester.view.physicalSize` + `devicePixelRatio` (or a sized wrapper); never let the host window decide.
  - **Freeze nondeterminism** — no real network (override providers with fakes), no `DateTime.now()` in the rendered widget (inject a clock), no random.
- **Manage the files:** goldens live next to the test under `test/.../goldens/`. Generate/refresh with:
  ```bash
  flutter test --update-goldens path/to/widget_golden_test.dart
  ```
  **Review the PNG diff in the PR** before accepting — `--update-goldens` makes the test pass by definition, so an unreviewed update hides the very regression goldens exist to catch. Run goldens on a **single pinned environment** (one CI runner image) so cross-platform anti-aliasing doesn't cause false diffs; `alchemist` can disable platform-specific rendering for CI.

---

## Integration tests (`integration_test` + flows)

Integration tests run the **real app** on a device/emulator and drive it like a user. They prove the pieces are wired together — routing, real providers, real rendering — which unit/widget tests can't.

- Live in **`integration_test/`** (a sibling of `test/`), using the `integration_test` package's `IntegrationTestWidgetsFlutterBinding`.
- Keep them to **smoke flows**: launch the app → navigate to a screen → perform one core action → assert the outcome. See [`templates/integration_test.dart`](templates/integration_test.dart).
- Override only what must not be real (e.g. point at a mock/staging backend via a `ProviderScope` override at `runApp`) — but otherwise exercise the real stack. Use `tester.pumpAndSettle()` between steps; query with the same finders as widget tests.
- Run on an emulator:
  ```bash
  flutter test integration_test/app_smoke_test.dart
  ```
  Driving them in CI (and on a device farm) is **skill 21**'s job — hand the invocation off there.

Don't try to integration-test every path — that's slow and flaky. One or two flows through the app's spine is the right amount; logic depth belongs lower in the pyramid.

---

## Test data builders & fakes

Stop hand-constructing objects in every test — centralize in `test/support/` ([`templates/test_helpers.dart`](templates/test_helpers.dart)):

- **Builders** — a function/class with sensible defaults and overridable fields: `buildUser(name: 'Ada')`. One change when a model gains a field, not a hundred.
- **Fakes** — mocktail `Mock` subclasses of repository interfaces, or hand-written `Fake` implementations for behavior you want to control. Reuse them across unit, widget, and integration tests.
- Keep fixtures (real JSON payloads) under `test/fixtures/` — that's **skill 12**'s convention; share the directory.

---

## Coverage — measure it, gate it, don't worship it

```bash
flutter test --coverage          # writes coverage/lcov.info
```

- **Gate on a threshold** (e.g. **80%** line coverage) in CI; fail the build below it. Tools: `very_good test --coverage --min-coverage 80`, or parse `lcov.info` (`lcov --summary` / a small script), or a `dart_code_metrics`/codecov check.
- **Exclude what coverage shouldn't count:** generated code (`*.g.dart`, `*.freezed.dart`), `main.dart` bootstrap, generated routes/assets. Filter them out of `lcov.info` (`lcov --remove`) so the number reflects code you actually wrote.
- **What NOT to chase to 100%:** generated boilerplate, trivial `copyWith`/`toString`, pure UI layout with no logic, and code only reachable on real hardware. Aim for **high coverage of logic** (domain + application + mapping near 100%, per skill 12), not a vanity 100% that rewards testing getters.
- Coverage is a floor, not a target — a green 100% with no assertions proves nothing. Test **behavior and branches**, then read the number.

---

## What this skill produces

```
test/
├── support/
│   └── test_helpers.dart        # pumpApp wrapper + data builders + fakes
├── <feature>/
│   ├── domain/   *_test.dart     # pure-logic unit tests
│   ├── application/ *_test.dart   # notifier tests (pattern from skill 08)
│   └── presentation/
│       ├── *_widget_test.dart     # ProviderScope + pumpApp + interactions
│       └── goldens/ *_golden_test.dart + *.png
integration_test/
└── app_smoke_test.dart           # launch → navigate → core action
```

Test files mirror the source path under `test/` and end in `_test.dart` (CONVENTIONS §3).

---

## Anti-patterns

- **`pumpAndSettle` on a spinner** — times out; use `pump()` to observe an indefinite loading state.
- **Real network/clock/random in a test** — flaky and slow; override providers, inject a clock, seed randomness.
- **Goldens with the `Ahem` font** — boxes instead of text; load real fonts and pin the size.
- **Accepting `--update-goldens` blind** — hides the regression; review the PNG diff in the PR.
- **Integration-testing every path** — slow, flaky; smoke the spine, push logic down to unit tests.
- **Chasing 100% on generated code** — pad coverage; exclude it and test real behavior instead.
- **Asserting nothing** — `pumpWidget` then no `expect` is not a test; every test must assert an outcome.
- **One giant test** — split per behavior so a failure names the broken thing.

---

## Exit gate (must pass before stage 21)

- [ ] Domain logic unit-tested; application notifiers tested via `ProviderContainer` (skill 08 pattern); data layer covered (skill 12).
- [ ] Key screens have widget tests pumping a real tree in `ProviderScope` with fakes — loading→data **and** a core interaction.
- [ ] Golden tests exist for key components in **light + dark** at fixed sizes; fonts loaded; goldens committed and PR-reviewed.
- [ ] At least one `integration_test` smoke flow launches the app, navigates, and performs a core action.
- [ ] `flutter test --coverage` runs; threshold enforced; generated code excluded from the number.
- [ ] Whole suite is green and deterministic (no flaky/order-dependent tests) — **this, plus a green CI test job, is the gate.**

When green, record `test/` + `integration_test/` + the coverage threshold in `.flutter-pipeline/STATE.md` and hand the CI wiring to **stage 21 (CICD)**.
