# Version compatibility matrix — Flutter ↔ AGP ↔ Gradle ↔ Kotlin ↔ JDK

The single hardest class of build failures is a **version chain mismatch**. These five tools move as
a coupled set; changing one without the others is what produces "Minimum supported Gradle version
is X", "Unsupported class file major version", and Compose-compiler errors. This file is the mental
model plus a reference table and the exact commands to inspect/update each axis.

> Versions below are **representative compatible rows**, not the only valid combos. Always confirm
> against the official sources before pinning: the AGP release notes (Gradle + JDK requirements per
> AGP), the Kotlin↔Compose compiler map, and your Flutter version's bundled template. Treat the
> table as "known-good starting points"; the *relationships* (which axis forces which) are the
> durable part.

---

## 1. The dependency chain (who forces whom)

```
 Flutter SDK ──pins──► AGP version ──requires──► Gradle version ──runs on──► JDK
      │                   │                                              ▲
      └──templates──► Kotlin plugin ──must match──► Compose compiler ────┘
```

- **AGP is the anchor.** Each AGP version states a **minimum Gradle** and a **required JDK**. Pick
  AGP first, then satisfy Gradle and JDK.
- **Gradle** must be ≥ AGP's minimum. A *too-new* Gradle can also break an *old* AGP — keep them on
  the same row.
- **JDK**: AGP 8.x requires **JDK 17**. Running it on JDK 21+ or JDK 11 throws
  `Unsupported class file major version` or `requires Java 17`.
- **Kotlin** plugin version must be ≥ what your dependencies were compiled with, and (if you use
  Compose) must match the **Compose compiler** extension — unless you're on Kotlin 2.0+ with the
  `kotlin.plugin.compose` Gradle plugin, which pairs them automatically.
- **Flutter** bundles a template that sets defaults for all of the above; `flutter create` on a new
  Flutter version is the easiest way to get a self-consistent set.

**Rule:** change versions in *sets*, one row at a time, then `flutter clean` + rebuild. Never bump a
single axis in isolation.

---

## 2. Reference table (known-good rows)

| Flutter (≈) | AGP | Gradle wrapper | Kotlin | JDK | Notes |
|---|---|---|---|---|---|
| 3.32 / 3.29 | 8.7 | 8.12 | 2.1.x | 17 | Current declarative `settings.gradle` plugins block. Kotlin 2.x → use `kotlin.plugin.compose`. |
| 3.24 / 3.27 | 8.6 | 8.9 | 2.0.x | 17 | Kotlin 2.0 GA; KSP preferred over kapt. |
| 3.22 | 8.3 | 8.4 | 1.9.22 | 17 | AGP 8.x → **JDK 17 mandatory**. |
| 3.19 | 8.1 | 8.3 | 1.9.10 | 17 | Namespace required (AGP 8 removed manifest `package`). |
| 3.16 | 7.4 | 7.6 | 1.8.22 | 11 or 17 | First Flutter with declarative `settings.gradle` plugins. |
| 3.13 and older | 7.3 | 7.5 | 1.7.x | 11 | Legacy: AGP/Kotlin in `android/build.gradle` `ext`, not `settings.gradle`. |

**Compose compiler ↔ Kotlin** (when you use Jetpack Compose in the Android layer):

| Kotlin | Compose compiler extension |
|---|---|
| 2.0.0+ | use the `org.jetbrains.kotlin.plugin.compose` plugin (no manual version) |
| 1.9.22 | 1.5.10 |
| 1.9.10 | 1.5.3 |
| 1.8.22 | 1.4.8 |

> The pairing rule matters more than the exact numbers: a Compose-compiler error names the Kotlin it
> wants — set the project's Kotlin to that (or adopt the Kotlin 2.0 compose plugin).

---

## 3. Where each version lives, and how to check / update it

### Flutter & Dart
- **Check:** `flutter --version` (shows Flutter + bundled Dart + engine).
- **Update:** `flutter upgrade` (stay on `stable` per CONVENTIONS). To regenerate a self-consistent
  Android template after a big jump: `flutter create --platforms=android .` in the project root
  (review the diff — it touches `android/`).

### Gradle (wrapper)
- **File:** `android/gradle/wrapper/gradle-wrapper.properties`
- **Check:** the `distributionUrl` line, e.g.
  `distributionUrl=https\://services.gradle.org/distributions/gradle-8.4-all.zip`
- **Update:** edit `distributionUrl` to the target version, or
  `cd android && ./gradlew wrapper --gradle-version 8.4`.

### AGP (Android Gradle Plugin)
- **File (Flutter ≥ 3.16):** `android/settings.gradle[.kts]` →
  `plugins { id "com.android.application" version "8.3.0" apply false }`
- **File (legacy):** `android/build.gradle` → `dependencies { classpath 'com.android.tools.build:gradle:7.3.0' }`
- **Update:** change the version string; then satisfy Gradle + JDK from the table.

### Kotlin
- **File (Flutter ≥ 3.16):** `android/settings.gradle[.kts]` →
  `id "org.jetbrains.kotlin.android" version "1.9.22" apply false`
- **File (legacy):** `android/build.gradle` → `ext.kotlin_version = '1.9.10'`
- **Update:** bump the version; if using Compose, re-check the Compose-compiler row.

### JDK
- **Check what Flutter uses:** `flutter doctor -v` (shows the Java path AGP will run on).
- **Point Flutter at a specific JDK:** `flutter config --jdk-dir "/path/to/jdk-17"`.
- **Or per-project:** `org.gradle.java.home=/path/to/jdk-17` in `android/gradle.properties`.
- **Rule:** AGP 8.x ⇒ JDK **17**. Confirm with `java -version`.

### compile/min/target SDK
- **File:** `android/app/build.gradle[.kts]` → `compileSdkVersion`, `defaultConfig { minSdkVersion / targetSdkVersion }`
  (often templated as `flutter.compileSdkVersion`, etc.).
- **House default:** `minSdk 23` (CONVENTIONS). Raise only when a plugin forces it.

---

## 4. Update playbook (safe order)

1. **Decide the target Flutter** (usually latest `stable`). `flutter upgrade`.
2. **Read the AGP row** for that Flutter from the table; set AGP in `settings.gradle`.
3. **Set Gradle** ≥ AGP's minimum in `gradle-wrapper.properties`.
4. **Set the JDK** AGP requires (17 for AGP 8.x); point Flutter at it.
5. **Set Kotlin**; if Compose is used, align the Compose-compiler (or adopt the Kotlin 2.0 plugin).
6. **Clean & build:** `flutter clean && cd android && ./gradlew clean && cd .. && flutter pub get && flutter build apk`.
7. If a plugin still complains, it's the plugin's own Android requirements — upgrade the plugin
   (`flutter pub upgrade <plugin>`) or pin it; see `error_signatures.md` rows `lockfile-mismatch` /
   `namespace-missing`.

When in doubt, the most reliable reset is to `flutter create --platforms=android .` against a fresh
stable Flutter and port your customizations into the regenerated `android/` files — that yields a
guaranteed-consistent chain.

House style: [`../../../references/CONVENTIONS.md`](../../../references/CONVENTIONS.md).
