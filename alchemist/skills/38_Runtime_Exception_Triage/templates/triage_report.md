# Triage Report — <exception type @ top frame>

> Produced by skill 38 (Runtime Exception Triage). One report per crash *signature*
> (exception + top app-code frame), not per raw trace. Fill every section; "unknown"
> is a valid answer that tells the next person where to dig.

| Field | Value |
|---|---|
| **Signature** | `<NullCheck @ lib/features/profile/.../profile_controller.dart:42>` |
| **Source** | Sentry / Crashlytics issue `<id + link>` · or raw trace path |
| **First seen** | `<version / date>` · **Last seen** `<version / date>` |
| **Obfuscated?** | yes / no — if yes, symbolized with `build/symbols/<versionCode>` (skill 22) |
| **App version(s)** | `<versionName+versionCode>` affected |
| **Severity / Priority** | **P0 / P1 / P2** — `<one-line justification>` |

---

## 1. Signature & reach

- **Exception:** `<Null check operator used on a null value>`
- **Top app-code frame:** `<ProfileController.build @ profile_controller.dart:42>`
- **Reach (from #23 dashboard):** `<N sessions · M users · crash-free-users ▼ X%>`
- **Trend:** new / spiking / steady / decaying · **Regression?** yes (since `<version>`) / no

## 2. Symbolized top frames

> From `parse_trace.py` (framework frames filtered). Deepest app frame first.

```
#0  <Symbol>            -> lib/.../<file>.dart:<line>      <- prime suspect
#1  <Symbol>            -> lib/.../<file>.dart:<line>
#2  <Symbol>            -> lib/.../<file>.dart:<line>
```

## 3. Suspected location (via the #26 index)

| What | Value |
|---|---|
| **File:line** | `lib/.../<file>.dart:<line>` |
| **Owning entity** | provider / repository / screen — `<entity id from index>` |
| **Feature** | `<feature name>` |
| **Blast radius** (reverse deps) | `<files that dependOn this — also assert here>` |

## 4. Hypothesis (root cause)

State the exact triggering condition, not a vague guess:

> `<authProvider is null while loading / after sign-out; the `!` on line 42 throws.
> Surfaced this release because <the sign-out button added a new null path>.>`

- **Trigger condition:** `<a null / empty list / bad cast / race / off-by-one>`
- **Why now:** `<new code path, dependency bump, data shape change, device/OS>`
- **Reproduction:** `<the override/input that drives the condition in a test>`

## 5. Proposed fix

Fix at the **right layer** — guard at the data boundary / handle the state explicitly
(skill 15 / skill 16), not a `?.` band-aid in the widget.

```dart
// before  (lib/.../<file>.dart:<line>)
return ProfileView(name: user!.displayName);

// after
final user = ref.watch(authProvider).valueOrNull;
if (user == null) return const SignedOutView();   // explicit state, no `!`
return ProfileView(name: user.displayName);
```

- **Layer:** data boundary / controller / UI state — `<why here>`
- **Hands off to:** skill `<15 error path / NN feature stage>`

## 6. Regression test (must fail today, pass after)

```dart
test('<renders signed-out state when user is null — was: null-check crash>', () {
  final c = ProviderContainer(
    overrides: [authProvider.overrideWith(() => SignedOutAuth())],
  );
  expect(() => c.read(profileControllerProvider), returnsNormally);
  addTearDown(c.dispose);
});
```

- **File:** `test/features/<feature>/<file>_test.dart`
- **Asserts:** the prior triggering condition no longer throws / renders the correct state.

## 7. Severity / priority rationale

- **Severity:** `<data-loss? security? crash-on-launch? core-loop blocked? else recoverable>`
- **Frequency:** `<reach figures from §1>`
- **Decision:** **P<0/1/2>** — `<e.g. halt rollout & fix-forward (skill 22) / this sprint / backlog>`

## 8. Follow-up

- [ ] Fix merged: `<PR link>`
- [ ] Regression test green in CI (skill 20/21)
- [ ] Rollout action taken if P0 (halt / fix-forward, skill 22)
- [ ] **Recorded in skill 73 (Regression Memory):** signature → root cause → fix
- [ ] Dashboard issue resolved & version with fix noted (skill 23)
