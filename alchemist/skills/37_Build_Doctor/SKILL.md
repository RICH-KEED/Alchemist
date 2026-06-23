---
name: Build Doctor
description: Diagnose Flutter/Android build failures from raw logs and propose the exact fix. Use when a build breaks with Gradle/AGP/Kotlin/JDK version mismatches, "namespace not specified", "Could not resolve" deps, NDK/multidex/minSdk errors, R8/ProGuard failures, CocoaPods errors, or pub "version solving failed". Powers the version-compatibility triage that most Flutter engineers waste hours Googling.
when_to_use: Trigger on "build failed", "won't compile", "gradle error", "namespace not specified", "could not resolve", "version solving failed", "minSdk", "multidex", "R8/proguard", "pod install failed", "unsupported class file major version", or any paste of a red Gradle/Flutter build log. This is the engine behind Self-Healing CI (#33) — call it whenever a build/CI job fails and you need a ranked cause + exact fix.
---

# Build Doctor — Diagnose Build Failures, Propose the Exact Fix

A build log is a crime scene. Your job is to read it, identify which **failure family** broke the
build, find the **one config file** that's wrong, apply the **exact change**, and re-build. This
skill turns "47 lines of red Gradle output" into a named cause and a specific edit. House style:
[`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md).

Two assets do the heavy lifting and **must stay in sync**:
- [`templates/error_signatures.md`](templates/error_signatures.md) — the knowledge base: error
  string/regex → root cause → exact fix (which file, what change), grouped into families A–I.
- [`templates/version_matrix.md`](templates/version_matrix.md) — the Flutter ↔ AGP ↔ Gradle ↔ Kotlin
  ↔ JDK compatibility model and how to inspect/update each axis.
- [`scripts/diagnose.py`](scripts/diagnose.py) — a stdlib Python matcher that reads a log and prints
  the ranked cause(s) + fix(es). Its embedded `SIGNATURES` mirror the KB by id.

> **Powers Self-Healing CI (#33).** When a CI job fails, #33 pipes the job log through
> `diagnose.py --json`, gets the ranked cause, and either auto-applies a safe fix or opens a PR with
> the suggested edit. Keep the script's output machine-readable for that path.

---

## The triage flow

Run this loop for every broken build:

1. **Capture the FULL log** — not the screenshot, not the last line. The real cause sits *above*
   `BUILD FAILED` / `Execution failed for task`.
   ```bash
   flutter build apk --verbose 2>&1 | tee build.log
   # or for a run:  flutter run -v 2>&1 | tee build.log
   ```
2. **Classify the failure family** (A–I below) from the error strings. When unsure, run the script:
   ```bash
   python "${CLAUDE_SKILL_DIR}/scripts/diagnose.py" build.log
   # piped:  flutter build apk --verbose 2>&1 | python "${CLAUDE_SKILL_DIR}/scripts/diagnose.py"
   ```
3. **Locate the offending config** named in the fix (almost always under `android/`, `ios/`, or
   `pubspec.yaml`).
4. **Apply the known fix** from [`error_signatures.md`](templates/error_signatures.md). If it touches
   a version, resolve it through [`version_matrix.md`](templates/version_matrix.md) — never bump one
   axis alone.
5. **Clean & re-build** to confirm:
   ```bash
   flutter clean && cd android && ./gradlew clean && cd .. && flutter pub get && flutter build apk
   ```
6. **Repeat** — builds often fail in layers (fix the namespace, then the Gradle version surfaces).
   Re-run the script after each fix; the top match changes as you peel layers.

---

## How to read Gradle / pub output

Gradle and pub bury the cause; learn where they hide it.

**Gradle**
- The block that matters is `* What went wrong:` and `Caused by:` — read **upward** from
  `BUILD FAILED`. The last line is usually a symptom, not the cause.
- `Execution failed for task ':app:<task>'` names *which* task died: `:app:processDebugMainManifest`
  → manifest/namespace; `:app:mergeDexDebug` / `:app:minify...WithR8` → dex/R8; `:app:compileDebugKotlin`
  → Kotlin/JDK; `configureCMake...` → NDK.
- Re-run with `--stacktrace` or `--info` only when the cause is still ambiguous; usually `--verbose`
  on the Flutter command is enough.

**pub (`version solving failed`)**
- Read it **bottom-up**. The chain of "Because A depends on B…, and C depends on B…" ends with the
  **real** incompatible pair on the last line. That's the constraint to relax.
- `dart pub deps` (or `flutter pub deps`) shows who pins what, so you can see which package forces the
  bad version.

**The script's job** is to do this classification for you and rank candidates — but always confirm
against the actual log lines it matched (`--json` shows `matched_patterns`).

---

## The failure families (KB index)

Full table with exact fixes in [`templates/error_signatures.md`](templates/error_signatures.md):

| Family | Covers | Telltale string |
|---|---|---|
| **A — Namespace/Manifest** | `namespace not specified`, manifest `package` removed, merger conflicts, MainActivity not found | "Namespace not specified", "Manifest merger failed" |
| **B — Version mismatch** | AGP↔Gradle, JDK too new/old, Kotlin too old, jvm-target/source-release | "Minimum supported Gradle version", "Unsupported class file major version" |
| **C — Dependency resolution** | `Could not resolve`, missing repo, jcenter, network/proxy, SDK-not-found | "Could not resolve", "Could not find ...:...:..." |
| **D — SDK/Multidex/NDK** | minSdk too low for a plugin, target/compileSdk, 64K methods, NDK mismatch | "minSdkVersion ... cannot be smaller", "Cannot fit requested classes" |
| **E — Kotlin/Compose** | Compose-compiler↔Kotlin, kapt, duplicate class | "Compose Compiler requires Kotlin version" |
| **F — R8/ProGuard** | missing keep rules, R8 full-mode crash (release builds) | "Missing class ... referenced from", "minify...WithR8" |
| **G — Pub resolution** | `version solving failed`, SDK constraint, package not found, pubspec YAML | "version solving failed" |
| **H — Networking/Misc** | cleartext HTTP blocked, daemon OOM, plugin needs higher AGP | "Cleartext HTTP traffic ... not permitted" |
| **I — iOS/CocoaPods** | pod install, deployment target too low, arm64 simulator, Swift version | "Error running pod install" |

---

## The version-compatibility mindset

Most "mysterious" build failures (families B and E) are a **version-chain mismatch**. Five tools move
as a coupled set:

```
Flutter ──pins──► AGP ──requires──► Gradle ──runs on──► JDK
   └──templates──► Kotlin ──must match──► Compose compiler
```

- **AGP is the anchor.** It dictates the minimum **Gradle** and the required **JDK**. AGP 8.x ⇒
  **JDK 17** (running it on JDK 21+ throws `Unsupported class file major version 65`).
- Change versions in **sets**, one row at a time, then `flutter clean` and rebuild. Never bump a
  single axis in isolation — that's what creates the next error.
- Where each axis lives:
  - Gradle → `android/gradle/wrapper/gradle-wrapper.properties` (`distributionUrl`)
  - AGP + Kotlin → `android/settings.gradle[.kts]` `plugins { }` (or legacy `android/build.gradle`)
  - SDK levels → `android/app/build.gradle[.kts]` (`compileSdk`/`minSdk`/`targetSdk`)
  - JDK → `flutter doctor -v` to see it; `flutter config --jdk-dir` or `org.gradle.java.home`
- The known-good rows and the safe update playbook are in
  [`templates/version_matrix.md`](templates/version_matrix.md). The nuclear reset that guarantees a
  consistent chain: `flutter create --platforms=android .` against a fresh stable Flutter, then port
  your customizations into the regenerated `android/` files.

---

## Worked example (the triage in action)

Pasted log contains `Namespace not specified` **and** `Minimum supported Gradle version is 8.0`:

1. `diagnose.py` ranks `namespace-missing` (high) then `agp-requires-newer-gradle` (medium).
2. Fix #1: add `namespace "com.example.app"` to `android/app/build.gradle`'s `android { }`.
3. Rebuild → the Gradle-version error now leads. Resolve via the matrix: bump `distributionUrl` to
   `gradle-8.4-all.zip` and confirm AGP/JDK on the same row.
4. `flutter clean` + rebuild → green.

This is why step 6 loops: **fix the top match, rebuild, re-diagnose.**

---

## When to escalate (it's not a config you own)

Don't keep editing your `android/` files when the problem is upstream:

- **A plugin's own Android config is wrong** (e.g. it ships `namespace`-less, or pins a higher
  AGP/minSdk). Fix order: `flutter pub upgrade <plugin>` → check the plugin's issue tracker → pin a
  known-good plugin version in `pubspec.yaml` → as a last resort, patch via a `subprojects {}` /
  `pubspec_overrides.yaml`. Report the upstream issue.
- **An SDK regression** (a brand-new Flutter/AGP/Gradle release breaks a still-common plugin). Pin to
  the previous known-good row from the matrix and wait for the ecosystem to catch up.
- **Environment, not project** (corporate proxy blocking maven, missing NDK, wrong JDK on the
  machine). The fix is in `~/.gradle/gradle.properties` or the toolchain install, not the repo — say
  so explicitly so the user doesn't chase a code change.
- **Native/iOS toolchain** (Xcode/CocoaPods/Swift version): the fix often needs a tool update
  (`gem install cocoapods`, update Xcode) the user must run locally.

Always state which bucket you're in — "this is a plugin bug, not your code" saves more time than any
single edit.

---

## Keeping the KB and script in sync

The script's `SIGNATURES` list and `error_signatures.md` share signature **ids** (e.g.
`namespace-missing`, `agp-requires-newer-gradle`). When you add a new failure pattern:

1. Add a row to [`templates/error_signatures.md`](templates/error_signatures.md) with a new id.
2. Add a matching `Signature(...)` to [`scripts/diagnose.py`](scripts/diagnose.py) with the **same
   id** and the regex(es) that catch it.
3. Verify: `python scripts/diagnose.py --list` shows it, and a sample log matches it.

`diagnose.py` usage recap:
```bash
python scripts/diagnose.py build.log            # human-readable, ranked
python scripts/diagnose.py --json build.log     # for Self-Healing CI (#33)
python scripts/diagnose.py --top 5 build.log    # show more candidates
python scripts/diagnose.py --list               # every known signature id
```
Exit code is `0` when a signature matched, `1` when nothing matched (handy as a CI gate).

---

See the full fix tables in [`templates/error_signatures.md`](templates/error_signatures.md) and the
version logic in [`templates/version_matrix.md`](templates/version_matrix.md). House style:
[`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md).
