#!/usr/bin/env python3
"""Build Doctor - diagnose Flutter/Android build failures from a raw log.

Reads a build log (file argument or stdin), matches it against the known error
signatures (mirrored from ../templates/error_signatures.md), and prints the most
likely cause(s) + exact fix(es), ranked by confidence.

Usage:
    python diagnose.py build.log
    flutter build apk --verbose 2>&1 | python diagnose.py
    python diagnose.py --json build.log        # machine-readable (for CI / skill 33)
    python diagnose.py --list                  # list every known signature id

Stdlib only - no third-party deps, runs anywhere Python 3.8+ is present.
Keep SIGNATURES in sync with templates/error_signatures.md (same ids).
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass, field
from typing import List


@dataclass
class Signature:
    sig_id: str
    family: str
    # regex patterns; each match adds to the score. Case-insensitive, multiline.
    patterns: List[str]
    cause: str
    fix: str
    # patterns that, if present, strongly confirm (boost score)
    confirm: List[str] = field(default_factory=list)
    # weight per primary-pattern hit
    weight: int = 10


# --- Knowledge base (mirrors templates/error_signatures.md, by id) ------------
SIGNATURES: List[Signature] = [
    # A. Namespace & manifest
    Signature(
        "namespace-missing", "A - Namespace/Manifest",
        [r"namespace not specified", r"specify a namespace in the module'?s build file"],
        "AGP 7+ requires every Android module to declare a `namespace`; an old module only had "
        "`package=` in its manifest.",
        "Add `namespace \"com.example.app\"` inside `android { }` in the module's build.gradle "
        "(match the old manifest `package`). For a plugin you don't own: `flutter pub upgrade "
        "<plugin>`, pin AGP < 8, or patch via a `subprojects {}` block that sets the namespace.",
        confirm=[r"could not (?:get|find) unknown property '?namespace"],
    ),
    Signature(
        "manifest-package-removed", "A - Namespace/Manifest",
        [r"setting the namespace via the package attribute.*is not supported",
         r"package=\".*\" found in source androidmanifest"],
        "AGP 8 removed `package` from the manifest; namespace must be in Gradle.",
        "Delete `package=\"...\"` from android/app/src/main/AndroidManifest.xml; ensure "
        "`namespace \"...\"` is set in android/app/build.gradle.",
    ),
    Signature(
        "manifest-merger-failed", "A - Namespace/Manifest",
        [r"manifest merger failed"],
        "Two manifests (app + a library) declare a conflicting <application> attribute.",
        "In AndroidManifest.xml add `xmlns:tools=\"http://schemas.android.com/tools\"` and "
        "`tools:replace=\"android:label\"` (or the named attribute) on <application>.",
        confirm=[r"suggestion:\s*add\s*'?tools:replace"],
    ),
    Signature(
        "main-activity-missing", "A - Namespace/Manifest",
        [r"unable to find explicit activity class.*mainactivity",
         r"have you declared this activity in your androidmanifest"],
        "MainActivity path/package doesn't match the manifest or namespace/applicationId.",
        "Verify the MainActivity.kt package matches `namespace`, and AndroidManifest.xml "
        "`<activity android:name=\".MainActivity\">` resolves. After a package rename, move the "
        "Kotlin file to the matching folder.",
    ),
    # B. AGP / Gradle / JDK / Kotlin mismatches
    Signature(
        "agp-requires-newer-gradle", "B - Version mismatch",
        [r"minimum supported gradle version is\s*(\d+\.\d+)",
         r"android gradle plugin requires java\s*(\d+)"],
        "The AGP version needs a newer Gradle (or JDK) than the wrapper provides.",
        "Bump `distributionUrl` in android/gradle/wrapper/gradle-wrapper.properties to the required "
        "Gradle (e.g. gradle-8.4-all.zip). Cross-check the AGP<->Gradle row in version_matrix.md.",
        weight=12,
    ),
    Signature(
        "gradle-too-new-for-agp", "B - Version mismatch",
        [r"incompatible version.*of the android gradle plugin",
         r"latest supported.*version is"],
        "Gradle was upgraded past what the pinned AGP supports.",
        "Lower the Gradle wrapper or raise the AGP version in android/settings.gradle's plugins "
        "block. Keep both on a compatible row (version_matrix.md).",
    ),
    Signature(
        "unsupported-class-file", "B - Version mismatch",
        [r"unsupported class file major version\s*(\d+)",
         r"bug!\s*exception in phase 'semantic analysis'"],
        "Gradle/AGP run on a JDK that is too new (or too old). Major 61=JDK17, 65=JDK21.",
        "Point Flutter at a supported JDK: `flutter config --jdk-dir \"<jdk17>\"`, or set "
        "`org.gradle.java.home` in android/gradle.properties. AGP 8.x needs JDK 17.",
        weight=12,
    ),
    Signature(
        "invalid-source-release", "B - Version mismatch",
        [r"invalid source release:\s*(\d+)",
         r"source/target value\s*\d+\s*is no longer supported"],
        "compileOptions/kotlinOptions request a Java version the toolchain JDK can't honour.",
        "In android/app/build.gradle set sourceCompatibility/targetCompatibility = "
        "JavaVersion.VERSION_17 and kotlinOptions.jvmTarget = \"17\" to match your JDK.",
    ),
    Signature(
        "jvm-target-mismatch", "B - Version mismatch",
        [r"inconsistent jvm-target compatibility detected",
         r"'compilejava'.*and 'compilekotlin'"],
        "Java and Kotlin compile tasks target different bytecode versions.",
        "Make them equal: sourceCompatibility/targetCompatibility = JavaVersion.VERSION_17 AND "
        "kotlinOptions.jvmTarget = \"17\" in android/app/build.gradle.",
    ),
    Signature(
        "kotlin-version-old", "B - Version mismatch",
        [r"was compiled with an incompatible version of kotlin",
         r"binary version of its metadata is\s*(\d+\.\d+\.\d+), expected version"],
        "A dependency was built with a newer Kotlin than the project's Kotlin plugin.",
        "Raise the Kotlin version in android/settings.gradle "
        "(`id \"org.jetbrains.kotlin.android\" version \"X\"`), or legacy `ext.kotlin_version` in "
        "android/build.gradle. Pick a Kotlin from version_matrix.md.",
    ),
    # C. Dependency resolution & repos
    Signature(
        "could-not-resolve", "C - Dependency resolution",
        [r"could not resolve\s+\S+:\S+:\S+", r"could not find\s+\S+:\S+:\S+",
         r"could not (?:get|head) '?https?://"],
        "Dependency coordinate/version doesn't exist, repo is missing, or network/proxy blocked it.",
        "Confirm the coordinate & version exist. Ensure google() and mavenCentral() are in "
        "android/settings.gradle dependencyResolutionManagement.repositories. Behind a proxy, set "
        "proxy props in ~/.gradle/gradle.properties.",
    ),
    Signature(
        "jcenter-gone", "C - Dependency resolution",
        [r"jcenter"],
        "JCenter is shut down; an old config still points at it.",
        "Replace jcenter() with mavenCentral() in every repositories { } block "
        "(android/build.gradle, android/settings.gradle).",
        weight=6,
    ),
    Signature(
        "network-timeout", "C - Dependency resolution",
        [r"connection timed out", r"read timed out",
         r"could not get '?https?://.*'?\b.*(?:timed out|timeout)"],
        "Transient network, firewall, or stale Gradle cache.",
        "Retry online; behind a proxy add systemProp.https.proxyHost/Port to "
        "~/.gradle/gradle.properties. Reset with `cd android && ./gradlew --refresh-dependencies`.",
        weight=6,
    ),
    Signature(
        "flutter-sdk-not-found", "C - Dependency resolution",
        [r"sdk location not found", r"define a valid sdk location with an android_home",
         r"flutter sdk not found"],
        "ANDROID_HOME/local.properties not set, or the Flutter SDK path is wrong.",
        "Create android/local.properties with `sdk.dir=<android-sdk>` and "
        "`flutter.sdk=<flutter-path>`, or set ANDROID_HOME/ANDROID_SDK_ROOT. `flutter doctor` confirms.",
    ),
    # D. SDK levels, multidex, NDK
    Signature(
        "minsdk-too-low", "D - SDK/Multidex/NDK",
        [r"minsdkversion\s*(\d+)\s*cannot be smaller than version\s*(\d+)",
         r"uses-sdk:minsdkversion.*cannot be smaller"],
        "A plugin requires a higher minSdk than the app declares.",
        "Raise minSdkVersion (or minSdk in .kts) in android/app/build.gradle to the required value "
        "(house default 23; some plugins need 24/26).",
        weight=12,
    ),
    Signature(
        "targetsdk-required", "D - SDK/Multidex/NDK",
        [r"google play requires that apps target api level\s*(\d+)",
         r"targetsdkversion.*is deprecated"],
        "Play's target-API gate, or a build-tools requirement.",
        "Set targetSdkVersion/compileSdkVersion in android/app/build.gradle to the required API "
        "(often flutter.compileSdkVersion / flutter.targetSdkVersion).",
    ),
    Signature(
        "compilesdk-too-low", "D - SDK/Multidex/NDK",
        [r"is currently compiled against android-(\d+).*requires.*android-(\d+) or later",
         r"requires libraries and applications that depend on it to compile against version\s*(\d+)"],
        "A dependency needs a newer compileSdk than the project sets.",
        "Raise compileSdkVersion/compileSdk in android/app/build.gradle to the required API level.",
    ),
    Signature(
        "multidex-required", "D - SDK/Multidex/NDK",
        [r"cannot fit requested classes in a single dex file",
         r"methods? count exceeds.*65536", r"d8:\s*cannot fit requested classes"],
        "The app exceeds the 64K method limit and multidex isn't enabled.",
        "If minSdk >= 21, enable multidex: defaultConfig { multiDexEnabled true } in "
        "android/app/build.gradle. For minSdk < 21 also add androidx.multidex:multidex:2.0.1 and a "
        "MultiDexApplication.",
        weight=12,
    ),
    Signature(
        "ndk-version-mismatch", "D - SDK/Multidex/NDK",
        [r"no version of ndk matched the requested version\s*(\d+\.\S+)",
         r"ndk at .* did not have a source\.properties file",
         r"requested ndk version.*did not match"],
        "A plugin pins an ndkVersion that isn't installed, or the installed NDK is corrupt.",
        "Set android { ndkVersion \"<installed>\" } in android/app/build.gradle and install it: "
        "`sdkmanager \"ndk;<version>\"`. Match the version the failing plugin requests.",
    ),
    Signature(
        "cmake-ndk-failed", "D - SDK/Multidex/NDK",
        [r"execution failed for task ':.*:configurecmake", r"cmake error"],
        "Native (CMake/NDK) build failed - missing NDK, CMake, or ABI filter.",
        "Install NDK + CMake via sdkmanager; confirm ndkVersion/externalNativeBuild in build.gradle; "
        "restrict ABIs with ndk { abiFilters \"arm64-v8a\",\"armeabi-v7a\" } if needed.",
    ),
    # E. Kotlin / Compose compiler
    Signature(
        "compose-compiler-mismatch", "E - Kotlin/Compose",
        [r"version.*of the compose compiler requires kotlin version.*but you appear to be using"],
        "The Compose compiler extension is tied to a Kotlin version that doesn't match the project.",
        "Align kotlinCompilerExtensionVersion (composeOptions) with your Kotlin, or on Kotlin 2.0+ "
        "apply the org.jetbrains.kotlin.plugin.compose plugin. See Compose<->Kotlin map in "
        "version_matrix.md.",
        weight=12,
    ),
    Signature(
        "kapt-failed", "E - Kotlin/Compose",
        [r"execution failed for task ':.*:kaptgeneratestubs", r"\bkapt\b.*error"],
        "Annotation-processing (kapt) failed - usually a Kotlin/JDK mismatch or a broken stub.",
        "Align Kotlin & JDK (family B). For Kotlin 2.0+, migrate kapt->KSP where supported. "
        "`./gradlew clean` then rebuild to clear stale stubs.",
        weight=6,
    ),
    Signature(
        "duplicate-class", "E - Kotlin/Compose",
        [r"duplicate class .* found in modules"],
        "Two dependencies bundle the same class (e.g. android.support + androidx collision).",
        "Add `exclude group:'...', module:'...'` on the offending implementation, or migrate fully "
        "to AndroidX. Run `./gradlew :app:dependencies` to find the duplicate path.",
    ),
    # F. R8 / ProGuard
    Signature(
        "r8-missing-class", "F - R8/ProGuard",
        [r"missing class .* referenced from", r"r8:\s*missing class"],
        "R8 stripped or can't find a class referenced by reflection in a release build.",
        "Add a keep rule in android/app/proguard-rules.pro (e.g. `-keep class com.example.** { *; }`) "
        "and reference it via buildTypes.release proguardFiles. Upgrading the plugin often fixes it.",
    ),
    Signature(
        "r8-execution-failed", "F - R8/ProGuard",
        [r"execution failed for task ':app:minify.*withr8",
         r"com\.android\.tools\.r8.*compilationfailedexception"],
        "R8 full-mode crashed shrinking the release build.",
        "Add the missing keep rules; as a quick unblock set `android.enableR8.fullMode=false` in "
        "android/gradle.properties, or minifyEnabled false to confirm R8 is the cause, then add "
        "targeted keeps.",
    ),
    # G. Pub
    Signature(
        "pub-version-solving", "G - Pub resolution",
        [r"version solving failed", r"because .* depends on .*version solving failed"],
        "Two packages demand incompatible versions of a shared dependency, or a constraint excludes "
        "the SDK.",
        "Read bottom-up: the LAST \"Because...\" line is the real conflict. Relax the over-tight "
        "constraint in pubspec.yaml, run `flutter pub upgrade --major-versions`, or `dart pub deps`. "
        "If it's the SDK constraint, bump environment.sdk.",
        weight=12,
    ),
    Signature(
        "pub-sdk-constraint", "G - Pub resolution",
        [r"requires sdk version .* but the current sdk is",
         r"the current dart sdk version is"],
        "A package's environment requires a different Dart than the active Flutter SDK ships.",
        "Upgrade Flutter (`flutter upgrade`) to get the required Dart, or pin the package to a "
        "version compatible with your SDK in pubspec.yaml.",
    ),
    Signature(
        "pub-not-found", "G - Pub resolution",
        [r"could not find package\s+\S+", r"pub get failed.*404"],
        "Package name typo, removed from pub.dev, or a private/git source is unreachable.",
        "Fix the name/source in pubspec.yaml; for git/path deps confirm URL/ref/path. "
        "`flutter pub get` to re-resolve.",
    ),
    Signature(
        "pubspec-yaml-error", "G - Pub resolution",
        [r"error on line\s*\d+,\s*column\s*\d+ of pubspec\.yaml",
         r"mapping values are not allowed here"],
        "YAML syntax error (bad indentation, tabs, or duplicate keys) in pubspec.yaml.",
        "Fix indentation (2 spaces, never tabs) at the reported line; remove duplicate keys.",
    ),
    # H. Networking & misc
    Signature(
        "cleartext-blocked", "H - Networking/Misc",
        [r"cleartext http traffic to .* not permitted",
         r"cleartext communication .* not permitted by network security policy"],
        "Android 9+ blocks plain HTTP by default; the app hit an http:// endpoint.",
        "Use HTTPS. If plain HTTP is required for dev, add android:usesCleartextTraffic=\"true\" to "
        "<application>, or a scoped res/xml/network_security_config.xml. Never ship cleartext to "
        "prod (skill 13).",
    ),
    Signature(
        "gradle-daemon-oom", "H - Networking/Misc",
        [r"expiring daemon because jvm heap space is exhausted",
         r"outofmemoryerror:\s*java heap space"],
        "Gradle daemon ran out of memory on a large build.",
        "Raise heap in android/gradle.properties: "
        "`org.gradle.jvmargs=-Xmx4096m -XX:MaxMetaspaceSize=1024m`.",
    ),
    Signature(
        "lockfile-mismatch", "H - Networking/Misc",
        [r"the plugin .* requires a higher android gradle plugin",
         r"requires android gradle plugin .* or higher"],
        "Plugin's Android requirements outrun the project's Gradle/AGP after an upgrade.",
        "Upgrade Gradle/AGP per version_matrix.md, or pin the plugin lower in pubspec.yaml.",
    ),
    # I. iOS / CocoaPods
    Signature(
        "pod-install-failed", "I - iOS/CocoaPods",
        [r"error running pod install", r"cocoapods not installed", r"pod: command not found"],
        "CocoaPods missing or Podfile.lock out of sync.",
        "Install: `sudo gem install cocoapods` (or brew). Then `cd ios && pod install --repo-update`. "
        "If broken: `pod repo update`, delete ios/Pods + Podfile.lock, re-run.",
    ),
    Signature(
        "pod-platform-too-low", "I - iOS/CocoaPods",
        [r"deployment target.*requires a higher minimum",
         r"required a higher minimum deployment target"],
        "A pod needs a higher iOS deployment target than the Podfile sets.",
        "Raise `platform :ios, 'X.0'` at the top of ios/Podfile; if needed bump "
        "IPHONEOS_DEPLOYMENT_TARGET in Xcode, then `pod install`.",
    ),
    Signature(
        "pod-arch-arm64-sim", "I - iOS/CocoaPods",
        [r"building for ios simulator, but linking.*built for ios",
         r"undefined symbols for architecture arm64"],
        "Apple-silicon simulator arch issue with some pods.",
        "Add the standard post_install `EXCLUDED_ARCHS[sdk=iphonesimulator*] = arm64` block to "
        "ios/Podfile, then `pod install`. (Legacy pods only.)",
    ),
    Signature(
        "swift-version-pod", "I - iOS/CocoaPods",
        [r"module compiled with swift .* cannot be imported by the swift .* compiler"],
        "A precompiled pod's Swift version doesn't match Xcode's.",
        "Update the pod, or set SWIFT_VERSION in the post_install hook to match; update Xcode if the "
        "pod needs a newer Swift.",
    ),
]


def scan(log: str) -> List[dict]:
    """Return matched signatures ranked by score (highest first)."""
    results = []
    for sig in SIGNATURES:
        score = 0
        hits = []
        for pat in sig.patterns:
            found = re.findall(pat, log, flags=re.IGNORECASE | re.MULTILINE)
            if found:
                score += sig.weight * len(found)
                hits.append(pat)
        if score == 0:
            continue
        for pat in sig.confirm:
            if re.search(pat, log, flags=re.IGNORECASE | re.MULTILINE):
                score += sig.weight * 2
                hits.append(pat + " (confirm)")
        results.append({
            "id": sig.sig_id,
            "family": sig.family,
            "score": score,
            "cause": sig.cause,
            "fix": sig.fix,
            "matched_patterns": hits,
        })
    results.sort(key=lambda r: r["score"], reverse=True)
    return results


def format_human(results: List[dict], top: int) -> str:
    if not results:
        return (
            "No known signature matched.\n"
            "Re-run the build with --verbose and pipe the full output here:\n"
            "    flutter build apk --verbose 2>&1 | python diagnose.py\n"
            "Then read the lines ABOVE 'BUILD FAILED' / 'Execution failed for task' - the real cause\n"
            "is usually a few lines up. Cross-check templates/error_signatures.md by hand."
        )
    out = ["Build Doctor - ranked diagnosis", "=" * 34, ""]
    shown = results[:top]
    for i, r in enumerate(shown, 1):
        confidence = "high" if r["score"] >= 20 else "medium" if r["score"] >= 10 else "low"
        out.append(f"#{i}  [{r['id']}]  family {r['family']}  (confidence: {confidence})")
        out.append(f"    Cause: {r['cause']}")
        out.append(f"    Fix:   {r['fix']}")
        out.append("")
    if len(results) > top:
        extra = ", ".join(r["id"] for r in results[top:])
        out.append(f"(+ {len(results) - top} lower-ranked: {extra})")
        out.append("")
    out.append("Next: apply the top fix, then  flutter clean && flutter pub get && flutter build apk")
    out.append("Reference: templates/error_signatures.md and templates/version_matrix.md")
    return "\n".join(out)


def main(argv: List[str]) -> int:
    ap = argparse.ArgumentParser(
        description="Diagnose Flutter/Android build failures from a build log.")
    ap.add_argument("logfile", nargs="?", help="path to a build log (omit to read stdin)")
    ap.add_argument("--json", action="store_true", help="emit JSON (for CI / skill 33)")
    ap.add_argument("--top", type=int, default=3, help="how many ranked causes to show (default 3)")
    ap.add_argument("--list", action="store_true", help="list all known signature ids and exit")
    args = ap.parse_args(argv)

    if args.list:
        for sig in SIGNATURES:
            print(f"{sig.sig_id:28s} {sig.family}")
        return 0

    if args.logfile:
        try:
            with open(args.logfile, "r", encoding="utf-8", errors="replace") as fh:
                log = fh.read()
        except OSError as exc:
            print(f"error: cannot read {args.logfile}: {exc}", file=sys.stderr)
            return 2
    else:
        if sys.stdin.isatty():
            print("error: no log file given and stdin is empty.\n"
                  "Usage: python diagnose.py build.log  |  ... | python diagnose.py",
                  file=sys.stderr)
            return 2
        log = sys.stdin.read()

    if not log.strip():
        print("error: empty log.", file=sys.stderr)
        return 2

    results = scan(log)

    if args.json:
        print(json.dumps({"matches": results, "count": len(results)}, indent=2))
    else:
        print(format_human(results, args.top))

    # exit 0 = matched something, 1 = no match (useful for CI gating)
    return 0 if results else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
