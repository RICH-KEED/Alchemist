---
name: Feature Flags
description: Type-safe feature flag system wrapping Firebase Remote Config with local overrides, feature gating, kill-switch, and experiment-ready variants — for controlled rollout, A/B testing, and emergency off-switches. Use when you need runtime feature toggles, staged rollouts, developer overrides, or server-side kill-switches.
when_to_use: Trigger on "add feature flags", "feature toggle", "Firebase Remote Config", "kill switch", "feature gate this screen", "roll out gradually", "set up A/B experiment flag", "local override for flag", "Remote Config defaults", or "gate a feature behind a flag". Pairs with #67 (AB Experiment) for experiment assignment and #66 (Analytics Taxonomy) for flag-evaluation events.
---

# Feature Flags (Roadmap #54)

A type-safe, compile-time-verified feature flag system that abstracts over Firebase Remote
Config (or a home-rolled REST endpoint) and exposes typed flags through Riverpod. Every flag
has a safe default, a local-override path for developers, and a kill-switch for emergencies.
House style: [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md).

> **Core principle**: a feature flag is **never** a raw string key looked up ad-hoc. Every
> flag is a typed constant — the compiler verifies that `flagProvider(FeatureFlags.newCheckout)`
> returns `bool`, not `dynamic`. There is no `getString("new_checkout")` call site in the app.

---

## 1. Flag definition — typed sealed hierarchy

Define each flag as a member of a `FeatureFlag<T>` sealed class (freezed). The type
parameter `T` locks in the return type; the key string stays private to the service.

| Variant | Dart type | Example use |
|---|---|---|
| `Flag<bool>` | `bool` | `enableNewCheckout`, `showBetaBadge` |
| `Flag<int>` | `int` | `searchDebounceMs`, `maxCartItems` |
| `Flag<double>` | `double` | `discountMultiplier`, `radiusScale` |
| `Flag<String>` | `String` | `apiBasePath`, `themeVariant` |
| `Flag<Map<String, dynamic>>` | JSON blob | `homeLayoutConfig`, `promoCardSchema` |

The sealed class lives in `lib/core/feature_flags/` (shared domain — no Firebase import).

---

## 2. Firebase Remote Config setup

Dependencies: `firebase_core: ^3.x`, `firebase_remote_config: ^5.x`.

Initialise once in `main()`:
```dart
await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
final rc = FirebaseRemoteConfig.instance;
await rc.setDefaults(const { 'enable_new_checkout': false, 'search_debounce_ms': 300 });
await rc.setConfigSettings(RemoteConfigSettings(
  fetchTimeout: const Duration(seconds: 10),
  minimumFetchInterval: kDebugMode ? Duration.zero : const Duration(minutes: 5),
));
await rc.fetchAndActivate();
```

Fetch intervals: **Dev** — zero (instant feedback); **Staging** — 1 min; **Prod** — 5–15 min.

For instant-on-kill-switch, use **real-time Remote Config** (`addOnConfigUpdateListener`)
in prod so a kill-switch toggle propagates in seconds without a fetch window.

---

## 3. Home-rolled fallback (no Firebase)

When Firebase isn't in the stack, swap for a REST endpoint + `SharedPreferences` cache:
```
app start → GET /api/flags?platform=android&version=1.2.3
         → merge into SharedPreferences
         → FlagService reads from prefs (baked-in defaults as fallback)
```
Defaults are still compiled into the app. Cache TTL is driven by a `fetchedAt` timestamp.
On fetch failure, return last-cached values — never an empty state.

---

## 4. Flag evaluation pipeline

```
Flag<T> instance
  → FeatureFlagService.get(flag)
    → 1. local override?        → return override value (dev menu / .env)
    → 2. Remote Config / cache? → return remote typed value
    → 3. baked-in default       → return compile-time default
```

Every `get<T>` call is **synchronous** after initialisation — no `await`, no `FutureBuilder`.

---

## 5. Feature gating

**Provider family** — evaluate a flag reactively via Riverpod:
```dart
final featureFlagProvider = FutureProvider.family<bool, FeatureFlag<bool>>((ref, flag) {
  final service = ref.watch(featureFlagServiceProvider);
  return service.get(flag);
});
```
For variant flags, map the string to an enum: `ExperimentVariant.control`, `.variantA`, `.variantB`.

**FeatureGate widget** — conditionally renders children:
```dart
FeatureGate(
  flag: FeatureFlags.enableNewCheckout,
  fallback: const OldCheckoutScreen(),
  child: const NewCheckoutScreen(),
)
```
Loading/error states render the fallback (safe default: hidden).

**Route guarding** — `go_router` redirect:
```dart
GoRoute(
  path: '/new-checkout',
  redirect: (context, state) async {
    return FeatureFlagGate.redirectIfDisabled(
      FeatureFlags.enableNewCheckout, fallbackPath: '/checkout',
    );
  },
  builder: (_, __) => const NewCheckoutScreen(),
)
```

---

## 6. Kill-switch pattern

A flag whose default is **true** (feature is on) but can be flipped to `false` server-side.

Rules:
- Name: `killSwitch_<featureName>`. Default = `true` in `setDefaults` — never default-off a kill switch.
- Evaluate **before** any expensive work (network calls, rendering).
- When tripped, show a non-disruptive fallback — never a crash or blank screen.

---

## 7. Local overrides

| Method | How | Scope |
|---|---|---|
| **Dev menu** | In-app drawer: list flags, toggle, save to `SharedPreferences` | persisted across sessions |
| **--dart-define** | `--dart-define=FF_ENABLE_NEW_CHECKOUT=true` read via `String.fromEnvironment` | per launch |

Overrides are checked **first** in the evaluation pipeline. `null` means "not set — fall through."

---

## 8. Experiment-ready flags

For A/B experiments (paired with #67):
- Define the flag as `Flag<String>` with values `control`, `variant-a`, `variant-b`.
- On evaluation, log `flag_evaluated { flag, variant, device_id }` (pair with #66).
- This skill provides the **delivery**; #67 handles experiment assignment (who gets what).

---

## 9. Safety contract

| Scenario | Behaviour |
|---|---|
| Remote Config fetch fails | Return last-cached values (or baked-in defaults) |
| Flag key missing from Remote Config | Return `FeatureFlag.defaultValue` |
| Network unavailable at startup | Render with defaults; background-fetch later |
| Kill switch tripped | Feature off; fallback UI; no network calls fire |
| Local override set | Override wins — Remote Config value ignored |
| Type mismatch | Log a warning; return compile-time default — never crash |

**Never block the UI on a Remote Config fetch.** The app renders with defaults
immediately; fetches happen in the background and values propagate via Riverpod.

---

## 10. Integration with other skills

| Skill | How it connects |
|---|---|
| **#67 AB Experiment** | Provides variant assignment; #54 delivers the variant to the app |
| **#66 Analytics Taxonomy** | #54 emits `flag_evaluated` events; #66 defines the event schema |
| **#08 Riverpod** | Provider wiring follows Riverpod skill patterns (family, select) |
| **#15 Error Handling** | Fetch failures become typed `Failure` values, not raw exceptions |
| **#13 Security** | Do not put sensitive logic behind a client-only flag — pair with a server-side check |

---

## 11. Testing

Override `featureFlagServiceProvider` with a fake that returns known values:

```dart
// Unit test
final container = ProviderContainer(overrides: [
  featureFlagServiceProvider.overrideWith((ref) =>
    FakeFeatureFlagService({ FeatureFlags.enableNewCheckout: false })),
]);
```

```dart
// Widget test
await tester.pumpWidget(ProviderScope(overrides: [
  featureFlagServiceProvider.overrideWithValue(
    FakeFeatureFlagService({ FeatureFlags.enableNewCheckout: false })),
], child: const FeatureGate(flag: FeatureFlags.enableNewCheckout, ...)));
// assert fallback renders; assert child does not
```

`FakeFeatureFlagService` is a simple in-memory map — no Firebase, no network.
For integration/E2E, use `--dart-define` overrides to force flags to known values.

---

Full template in [`templates/feature_flag_service.dart`](templates/feature_flag_service.dart).
