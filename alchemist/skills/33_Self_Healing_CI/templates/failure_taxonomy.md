# Failure Taxonomy — class → signals → fixer/action → escalation

The classification table for Self-Healing CI (#33). For each failed run, match the log to one (or
more, in peel order) of these families, route to the fixer/action, and apply the escalation rule when
the bounded action can't safely heal it. Families align with Build Doctor (#37) where build errors
are concerned. House style: [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md).

> **Free re-run rule:** `network` and `test-flake` get **one** automatic re-run before any code
> change (often transient). All others get a real fix on the first attempt. Hard cap: **N = 3** fix
> attempts per run, then escalate.

---

## build

- **Signals:** `Execution failed for task ':app:...'`; `Namespace not specified`; `Manifest merger
  failed`; `Minimum supported Gradle version is …`; `Unsupported class file major version 65`;
  `Could not resolve com.android...`; `Cannot fit requested classes` (multidex); `minSdkVersion …
  cannot be smaller`; `Missing class … referenced from` (R8). Build Doctor families A–F, H.
- **Fixer / action:** **Build Doctor #37** — pipe the log through `diagnose.py --json`, get the
  ranked cause + exact file/edit; apply only the LOW-risk edit it names (namespace add, a
  single-row-in-a-set version bump from its matrix).
- **Escalation rule:** Escalate immediately (no attempt burned) if Build Doctor's diagnosis is
  "plugin bug / upstream" or "environment, not project" (corporate proxy, missing NDK/JDK on the
  runner). Those are human/upstream fixes, not a repo edit. Escalate after N if the same task keeps
  failing post-fix.

## lint

- **Signals:** `flutter analyze` step exits non-zero; output lines like
  `warning • … • lib/foo.dart:8:3 • unused_field`; closing `N issues found.`; CI "Analyze" job red.
- **Fixer / action:** **Analyzer Auto-Fix #41** — run `analyze_fix.sh` (format + `dart fix --apply`
  loop, capped). It clears all SAFE/mechanical lints.
- **Escalation rule:** If #41 returns any **JUDGMENT** issue (`use_build_context_synchronously`,
  removing `dynamic`, `public_member_api_docs`, an `error`-severity bug), **stop and escalate** with
  `severity • rule • file:line` — these are decisions, never auto-fixed.

## format

- **Signals:** `dart format --output=none --set-exit-if-changed .` exits 1; "Changed lib/…" /
  "would change N files"; CI "Format" check red.
- **Fixer / action:** Run `dart format .` (a subset of #41), commit the whitespace-only diff.
- **Escalation rule:** Essentially never escalates — formatting is deterministic. If it still fails
  after `dart format .`, the Dart SDK version on the runner differs from local; escalate to align
  the pinned Flutter/Dart version.

## test-flake

- **Signals:** a test that **passes on isolated re-run**; intermittent timeouts in one test; timing
  / ordering / network dependence in the test body; failure not reproducible locally.
- **Fixer / action:** Re-run the single test (`flutter test path/to/foo_test.dart`). If it passes,
  it's flaky: quarantine it (`@Tags(['flaky'])` or a skip-with-issue) and **open an issue**. Never
  delete the test.
- **Escalation rule:** If the test fails **deterministically** on isolated re-run, it is a **real
  regression** — escalate as a bug (route to the owning feature), do not quarantine or silence it.

## version-solve

- **Signals:** `Because <pkg> depends on … and <pkg2> depends on …, version solving failed.`;
  `The current Dart SDK version is …`; pub resolution chain (read bottom-up). Build Doctor family G.
- **Fixer / action:** **Build Doctor #37 family G** — relax/pin the **one** incompatible constraint
  in `pubspec.yaml` named on the last line of the chain. Pin only; do not blanket-upgrade.
- **Escalation rule:** Escalate if the incompatibility is a mutually-exclusive pin (two packages
  require disjoint versions of a third) — that needs a human call on which package to drop/replace.

## signing

- **Signals:** `Keystore file … not found`; `key.properties (No such file or directory)`;
  `signingConfig … is null`; release build unsigned; missing `ANDROID_KEYSTORE_BASE64` /
  `ANDROID_KEY_ALIAS` env at the sign step.
- **Fixer / action:** **CI-config only** (skill 13 §5 / #21 §3): confirm the keystore-decode step
  and `key.properties`-from-secrets write exist in the release workflow. **Never** write a secret
  into source.
- **Escalation rule:** If a required **secret is absent**, escalate with the exact secret name to add
  (`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_PASSWORD`, `ANDROID_KEY_ALIAS`,
  `PLAY_SERVICE_ACCOUNT_JSON`) — the agent cannot create repo secrets.

## timeout

- **Signals:** `The job running on runner … has exceeded the maximum execution time`; step killed at
  the runner limit; build hung on a slow/cold cache.
- **Fixer / action:** One **bounded** mitigation per attempt: enable/repair pub+Gradle caching (#21
  §2), raise the job's `timeout-minutes` by a sane increment, or split a monolithic job. Re-run.
- **Escalation rule:** Don't chase the same timeout more than once. If a single step still exceeds
  the limit after caching + a reasonable bump, escalate — it likely needs a runner upgrade or a
  genuinely slow build investigated by a human.

## network

- **Signals:** `Could not resolve <artifact>`; `Connection reset by peer`; `502/503` from a pub or
  maven mirror; `Failed to fetch` from a package host; transient TLS/DNS errors.
- **Fixer / action:** **Re-run the run once** (mirrors flap). If it recurs, treat as a real
  resolution issue → **Build Doctor family C**: pin a repo, add a mirror, or check the proxy.
- **Escalation rule:** If resolution fails identically across re-runs and Build Doctor points to a
  proxy/firewall (`~/.gradle/gradle.properties`), escalate — that's an environment fix the agent
  can't make in the repo.

---

## Classification precedence (when a log matches several)

1. **signing / secrets** and **version-solve** may be *diagnosed* by Build Doctor, but signing is
   **never** healed by editing secrets — pin/configure only.
2. **network** and **test-flake** get **one** free re-run before any code change.
3. **build** and **lint** get a real fix on the first pass.
4. Re-classify after every re-run: failures peel in layers; the top family changes as you fix.
