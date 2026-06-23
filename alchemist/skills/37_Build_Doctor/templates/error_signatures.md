# Build error signatures — string/regex → root cause → exact fix

The knowledge base behind skill 37 (Build Doctor) and the `diagnose.py` matcher. Each row:
the **error string you actually see**, the **family** it belongs to, the **root cause**, and the
**exact fix** (which file, what line, what value). Keep this in sync with the patterns embedded in
[`../scripts/diagnose.py`](../scripts/diagnose.py) — the `SIGNATURES` list there mirrors the IDs in
this table.

> Read the *whole* failing task, not just the last line. Gradle prints the real cause a few lines
> **above** `BUILD FAILED` / `Execution failed for task`. `flutter run -v` and
> `flutter build apk --verbose` expose the underlying Gradle/Kotlin/AGP message. Paths below are
> relative to the app root (the Flutter project); Android files live under `android/`.

Conventions for "where": `android/app/build.gradle` (Groovy) or `android/app/build.gradle.kts`
(Kotlin DSL) — newer templates use `.kts`. `android/gradle/wrapper/gradle-wrapper.properties` sets
the Gradle version. `android/settings.gradle[.kts]` declares AGP/Kotlin plugin versions in the
`plugins { }` block (Flutter ≥ 3.16 declarative style). See [`version_matrix.md`](version_matrix.md)
for the compatible-version logic.

---

## A. Android Gradle namespace & manifest

| ID | Error (string / regex) | Root cause | Exact fix |
|---|---|---|---|
| `namespace-missing` | `Namespace not specified. Specify a namespace in the module's build file` | AGP 7+ requires every Android module to declare a `namespace`; an old plugin/module only had `package=` in its manifest. | In the module's `build.gradle`, add `namespace "com.example.app"` inside `android { }` (match the old manifest `package`). For a **plugin** you don't own: upgrade it (`flutter pub upgrade <plugin>`), or pin AGP < 8, or add a patch via a `subprojects {}` block in `android/build.gradle` that sets `project.android.namespace` if missing. |
| `manifest-package-removed` | `package="..." found in source AndroidManifest.xml: .* Setting the namespace via the package attribute .* is not supported` | AGP 8 removed `package` from the manifest; namespace must be in Gradle. | Delete `package="..."` from `android/app/src/main/AndroidManifest.xml`; ensure `namespace "..."` is set in `android/app/build.gradle`. |
| `manifest-merger-failed` | `Manifest merger failed : Attribute application@.* value=.* is also present at .* Suggestion: add 'tools:replace'` | Two manifests (app + a library) declare a conflicting `<application>` attribute. | In `AndroidManifest.xml` add `xmlns:tools="http://schemas.android.com/tools"` and `tools:replace="android:label"` (or the named attribute) on `<application>`. |
| `main-activity-missing` | `Unable to find explicit activity class .*MainActivity.* have you declared this activity in your AndroidManifest.xml` | `MainActivity` path/package doesn't match the manifest or the `namespace`/`applicationId`. | Verify `android/app/src/main/.../MainActivity.kt` package matches `namespace`, and `AndroidManifest.xml` `<activity android:name=".MainActivity">` resolves. After a package rename, move the Kotlin file to the matching folder. |

## B. AGP ↔ Gradle ↔ JDK ↔ Kotlin version mismatches

| ID | Error (string / regex) | Root cause | Exact fix |
|---|---|---|---|
| `agp-requires-newer-gradle` | `Minimum supported Gradle version is (\d+\.\d+). Current version is .*` / `Android Gradle plugin requires Java \d+` | The AGP version needs a newer Gradle (or JDK) than the wrapper provides. | Bump `distributionUrl` in `android/gradle/wrapper/gradle-wrapper.properties` to the required Gradle (e.g. `gradle-8.4-all.zip`). Cross-check the AGP↔Gradle row in [`version_matrix.md`](version_matrix.md). |
| `gradle-too-new-for-agp` | `The project is using an incompatible version .* of the Android Gradle plugin. Latest supported .* is` | Gradle was upgraded past what the pinned AGP supports. | Either lower the Gradle wrapper or raise the AGP version in `android/settings.gradle`'s `plugins { id "com.android.application" version "X" }`. Keep both on a compatible row. |
| `unsupported-class-file` | `Unsupported class file major version (\d+)` / `BUG! exception in phase 'semantic analysis'` | Gradle/AGP run on a JDK that is too new (or too old). Major 61=JDK17, 65=JDK21. | Point Flutter at a supported JDK: `flutter config --jdk-dir "<path-to-jdk17>"`, or set `org.gradle.java.home` in `android/gradle.properties`. AGP 8.x needs **JDK 17**; don't run it on JDK 21+ unless the matrix allows. |
| `invalid-source-release` | `error: invalid source release: (\d+)` / `Source/target value \d+ is no longer supported. Use \d+ or later` | `compileOptions`/`kotlinOptions` request a Java version the toolchain JDK can't honour. | In `android/app/build.gradle` set `compileOptions { sourceCompatibility JavaVersion.VERSION_17; targetCompatibility JavaVersion.VERSION_17 }` and `kotlinOptions { jvmTarget = "17" }` to match your JDK. |
| `jvm-target-mismatch` | `Inconsistent JVM-target compatibility detected .* 'compileJava' .* and 'compileKotlin'` | Java and Kotlin compile tasks target different bytecode versions. | Make them equal: `sourceCompatibility`/`targetCompatibility` = `JavaVersion.VERSION_17` **and** `kotlinOptions.jvmTarget = "17"` in `android/app/build.gradle`. |
| `kotlin-version-old` | `was compiled with an incompatible version of Kotlin. The binary version of its metadata is (\d+\.\d+\.\d+), expected version is` / `Module was compiled with .* Kotlin` | A dependency was built with a newer Kotlin than the project's Kotlin plugin. | Raise the Kotlin version in `android/settings.gradle` (`id "org.jetbrains.kotlin.android" version "X"`) — older Flutter pins it in `android/build.gradle` as `ext.kotlin_version`. Pick a Kotlin in [`version_matrix.md`](version_matrix.md). |

## C. Dependency resolution & repositories

| ID | Error (string / regex) | Root cause | Exact fix |
|---|---|---|---|
| `could-not-resolve` | `Could not resolve .*` / `Could not find .*:.*:.*` / `Could not HEAD '.*'` | Dependency coordinate/version doesn't exist, repo is missing, or the network/proxy blocked it. | Confirm the coordinate & version exist. Ensure `google()` and `mavenCentral()` are in `android/settings.gradle` `dependencyResolutionManagement { repositories { } }` (or legacy `allprojects { repositories {} }` in `android/build.gradle`). Behind a proxy, set proxy props in `~/.gradle/gradle.properties`. |
| `jcenter-gone` | `Could not resolve .* jcenter` / `repo1?\.maven .* 502` referencing `jcenter` | JCenter is shut down; an old config still points at it. | Replace `jcenter()` with `mavenCentral()` in every `repositories { }` block (`android/build.gradle`, `android/settings.gradle`). |
| `network-timeout` | `Connection timed out` / `Read timed out` / `Could not GET '.*'` during dependency download | Transient network, firewall, or stale Gradle cache. | Retry online; if behind a corporate proxy add `systemProp.https.proxyHost`/`Port` to `~/.gradle/gradle.properties`. As a reset: `cd android && ./gradlew --refresh-dependencies`. |
| `flutter-sdk-not-found` | `SDK location not found. Define a valid SDK location with an ANDROID_HOME` / `Flutter SDK not found` | `ANDROID_HOME`/`local.properties` not set, or the Flutter SDK path is wrong. | Create `android/local.properties` with `sdk.dir=<android-sdk>` and `flutter.sdk=<flutter-path>`. Or set `ANDROID_HOME`/`ANDROID_SDK_ROOT` env var. `flutter doctor` confirms. |

## D. SDK levels, multidex, NDK

| ID | Error (string / regex) | Root cause | Exact fix |
|---|---|---|---|
| `minsdk-too-low` | `uses-sdk:minSdkVersion (\d+) cannot be smaller than version (\d+) declared in library` / `Manifest merger failed .* minSdkVersion` | A plugin requires a higher `minSdk` than the app declares. | Raise `minSdkVersion` (or `minSdk` in `.kts`) in `android/app/build.gradle` to the required value (house default is 23 per CONVENTIONS; some plugins need 24/26). Use `flutter.minSdkVersion` if templated. |
| `targetsdk-required` | `Google Play requires that apps target API level (\d+)` / `targetSdkVersion .* is deprecated` | Play's target-API gate, or a build-tools requirement. | Set `targetSdkVersion`/`compileSdkVersion` in `android/app/build.gradle` to the required API (often `flutter.compileSdkVersion` / `flutter.targetSdkVersion`). |
| `compilesdk-too-low` | `.* is currently compiled against android-(\d+).* requires .* compiled against android-(\d+) or later` | A dependency needs a newer `compileSdk` than the project sets. | Raise `compileSdkVersion`/`compileSdk` in `android/app/build.gradle` to the required API level. |
| `multidex-required` | `Cannot fit requested classes in a single dex file` / `methods? count exceeds.* 65536` / `D8: Cannot fit requested classes` | The app exceeds the 64K method limit and multidex isn't enabled. | If `minSdk >= 21` multidex is automatic — enable it: in `android/app/build.gradle` `defaultConfig { multiDexEnabled true }`. For `minSdk < 21` also add `implementation "androidx.multidex:multidex:2.0.1"` and use a `MultiDexApplication`. |
| `ndk-version-mismatch` | `NDK at .* did not have a source.properties file` / `No version of NDK matched the requested version (\d+\..*)` / `Requested NDK version .* did not match` | A plugin pins an `ndkVersion` that isn't installed, or the installed NDK is corrupt. | Set `android { ndkVersion "<installed-version>" }` in `android/app/build.gradle`, and install it: `sdkmanager "ndk;<version>"`. Match the version the failing plugin requests. |
| `cmake-ndk-failed` | `Execution failed for task ':.*:configureCMakeRelWithDebInfo.*'` / `CMake Error` | Native (CMake/NDK) build failed — missing NDK, CMake, or ABI filter. | Install NDK + CMake via `sdkmanager`; confirm `ndkVersion`/`externalNativeBuild` in `build.gradle`; restrict ABIs with `ndk { abiFilters "arm64-v8a","armeabi-v7a" }` if a 16KB-page or ABI issue. |

## E. Kotlin / Jetpack Compose compiler

| ID | Error (string / regex) | Root cause | Exact fix |
|---|---|---|---|
| `compose-compiler-mismatch` | `This version (.*) of the Compose Compiler requires Kotlin version (.*) but you appear to be using Kotlin version (.*)` | The Compose compiler extension version is tied to a specific Kotlin version that doesn't match the project's. | Either align `kotlinCompilerExtensionVersion` (in `composeOptions`) with your Kotlin, or (Kotlin 2.0+) apply the `org.jetbrains.kotlin.plugin.compose` plugin which auto-matches. See the Compose↔Kotlin map in [`version_matrix.md`](version_matrix.md). |
| `kapt-failed` | `Execution failed for task ':app:kaptGenerateStubs.*'` / `kapt .* error` | Annotation-processing (kapt) failed — usually a Kotlin/JDK mismatch or a broken generated stub. | Align Kotlin & JDK (sections B). For Kotlin 2.0+, migrate kapt→KSP where the library supports it. `./gradlew clean` then rebuild to clear stale stubs. |
| `duplicate-class` | `Duplicate class .* found in modules .* and .*` | Two dependencies bundle the same class (e.g. an `android.support` + `androidx` collision). | Add `exclude group: '...', module: '...'` on the offending `implementation`, or enable Jetifier / fully migrate to AndroidX. Run `./gradlew :app:dependencies` to find the duplicate path. |

## F. R8 / ProGuard (release shrinking)

| ID | Error (string / regex) | Root cause | Exact fix |
|---|---|---|---|
| `r8-missing-class` | `Missing class .* referenced from` / `R8: Missing class` / `ERROR: R8: ` | R8 stripped or can't find a class referenced by reflection in a release build. | Add a keep rule in `android/app/proguard-rules.pro` (e.g. `-keep class com.example.** { *; }`) and reference it via `buildTypes.release { proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro' }`. Many plugins ship consumer rules — upgrading the plugin often fixes it. |
| `r8-execution-failed` | `Execution failed for task ':app:minify.*WithR8'` / `com.android.tools.r8.* CompilationFailedException` | R8 full-mode crashed shrinking the release build (common with Flutter deferred components / missing rules). | Add the missing keep rules; as a quick unblock set `android.enableR8.fullMode=false` in `android/gradle.properties`, or `minifyEnabled false` temporarily to confirm R8 is the cause, then add targeted keeps. |

## G. Pub (Dart dependency) resolution

| ID | Error (string / regex) | Root cause | Exact fix |
|---|---|---|---|
| `pub-version-solving` | `version solving failed` / `Because .* depends on .* which .*, version solving failed` | Two packages demand incompatible versions of a shared dependency, or a constraint excludes the SDK. | Read it bottom-up: the **last** "Because…" line is the real conflict. Relax the over-tight constraint in `pubspec.yaml`, run `flutter pub upgrade --major-versions`, or `dart pub deps` to see who pins what. If it's the Dart/Flutter SDK constraint, bump `environment.sdk`. |
| `pub-sdk-constraint` | `requires SDK version .* but the current SDK is` / `The current Dart SDK version is .*` | A package's `environment` requires a newer/older Dart than the active Flutter SDK ships. | Upgrade Flutter (`flutter upgrade`) to get the required Dart, or pin the package to a version compatible with your SDK in `pubspec.yaml`. |
| `pub-not-found` | `Could not find package .* (could not find package .* at .*)` / `pub get failed .* 404` | Package name typo, removed from pub.dev, or a private/git source is unreachable. | Fix the name/source in `pubspec.yaml`; for git/path deps confirm the URL/ref/path. `flutter pub get` to re-resolve. |
| `pubspec-yaml-error` | `Error on line \d+, column \d+ of pubspec.yaml` / `mapping values are not allowed here` | YAML syntax error (bad indentation, tabs, or duplicate keys) in `pubspec.yaml`. | Fix indentation (2 spaces, never tabs) at the reported line; remove duplicate keys. |

## H. Android networking & misc runtime-at-build

| ID | Error (string / regex) | Root cause | Exact fix |
|---|---|---|---|
| `cleartext-blocked` | `Cleartext HTTP traffic to .* not permitted` / `CLEARTEXT communication .* not permitted by network security policy` | Android 9+ blocks plain HTTP by default; the app hit an `http://` endpoint. | Use HTTPS. If plain HTTP is genuinely required (dev/local), add `android:usesCleartextTraffic="true"` to `<application>` in `AndroidManifest.xml`, or a scoped `res/xml/network_security_config.xml` allowing only the specific dev domain. Never ship cleartext to prod (skill 13). |
| `gradle-daemon-oom` | `Expiring Daemon because JVM heap space is exhausted` / `OutOfMemoryError: Java heap space` | Gradle daemon ran out of memory on a large build. | Raise heap in `android/gradle.properties`: `org.gradle.jvmargs=-Xmx4096m -XX:MaxMetaspaceSize=1024m`. |
| `lockfile-mismatch` | `because .* doesn't match any versions` / `The plugin .* requires a higher Android Gradle Plugin` (from `flutter pub get`) | Plugin's Android requirements outrun the project's Gradle/AGP after an upgrade. | Upgrade Gradle/AGP per [`version_matrix.md`](version_matrix.md), or pin the plugin lower in `pubspec.yaml`. |

## I. iOS / CocoaPods (cross-platform projects)

| ID | Error (string / regex) | Root cause | Exact fix |
|---|---|---|---|
| `pod-install-failed` | `Error running pod install` / `CocoaPods not installed` / `pod: command not found` | CocoaPods missing or `Podfile.lock` out of sync. | Install: `sudo gem install cocoapods` (or `brew install cocoapods`). Then `cd ios && pod install --repo-update`. If still broken: `pod repo update`, delete `ios/Pods` + `Podfile.lock`, re-run. |
| `pod-platform-too-low` | `The platform of the target .* is set to .* but the .* deployment target .* requires a higher minimum` / `Specs satisfying the .* dependency were found, but they required a higher minimum deployment target` | A pod needs a higher iOS deployment target than the `Podfile` sets. | Raise `platform :ios, 'X.0'` at the top of `ios/Podfile` to the required version; if needed bump the project's `IPHONEOS_DEPLOYMENT_TARGET` in Xcode, then `pod install`. |
| `pod-arch-arm64-sim` | `building for iOS Simulator, but linking .* built for iOS` / `Undefined symbols for architecture arm64` (simulator) | Apple-silicon simulator arch issue with some pods. | Add the standard `post_install` `EXCLUDED_ARCHS[sdk=iphonesimulator*] = arm64` block to `ios/Podfile`, then `pod install`. (Last resort for legacy pods only.) |
| `swift-version-pod` | `Module compiled with Swift .* cannot be imported by the Swift .* compiler` | A precompiled pod's Swift version doesn't match Xcode's. | Update the pod, or set `SWIFT_VERSION` in the `post_install` hook to match; update Xcode if the pod needs a newer Swift. |

---

## How to use this table

1. **Capture the full log** (`flutter build apk --verbose 2>&1 | tee build.log`).
2. **Classify** into a family (A–I) from the strings above.
3. **Locate** the offending config file named in the fix column.
4. **Apply** the exact change, cross-checking versions against [`version_matrix.md`](version_matrix.md).
5. **Clean & rebuild**: `flutter clean && cd android && ./gradlew clean && cd .. && flutter pub get && flutter build apk`.

When a fix touches a version, **never change one axis in isolation** — Flutter, AGP, Gradle, Kotlin,
and the JDK move as a set. See the matrix.

House style: [`../../../references/CONVENTIONS.md`](../../../references/CONVENTIONS.md).
