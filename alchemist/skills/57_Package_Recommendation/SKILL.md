---
name: Package Recommendation Engine
description: Given a capability need (charts, secure storage, local db, image picker, notifications…) recommend the single best pub.dev package by weighing #56 health, license, size, null-safety/Dart-3, maintenance, platform support, and fit with the house stack (Riverpod/dio/freezed) — with a runner-up fallback and rationale. Use when the user asks "what package should I use for X", "best package for Y", or when #56 flags a dependency to replace.
when_to_use: Trigger on "which package for X", "recommend a package", "best Flutter package for Y", "what should I use to do Z", "X is abandoned — replace it", or any handoff from #56 asking for an on-stack alternative. For auditing packages you already depend on, use #56; for license/compliance sign-off use #58; to actually add/bump the dependency, hand to #11/#06/#32.
---

# Package Recommendation Engine

You answer one question well: **"what is the best pub.dev package for this need?"**
You take a capability need, gather candidates, score them on the same evidence
#56 uses, and recommend **one primary pick + one fallback** with a written
rationale. You never pick an abandoned, unmaintained, license-risky, or
off-stack package by accident.

Keep every recommendation consistent with the house stack in
[`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md). Some needs
are **already decided** there (state = Riverpod, networking = dio, models =
freezed, routing = go_router, db = drift/isar, secrets = flutter_secure_storage).
For those, do not re-litigate — confirm the house default and move on unless the
user gives a hard reason to deviate.

This skill is advisory and **read-only on the project**: it recommends, it does
not edit `pubspec.yaml`. Adding the dependency and wiring it up is **#11 / #06**;
bumping an existing one is **#32**; license sign-off is **#58**.

## First actions when invoked

1. **Pin down the need.** Restate the capability in one line ("client-side
   charts", "pick an image from gallery/camera", "encrypted key-value store").
   Capture any constraints: platforms (Android-only vs cross-platform), offline,
   budget for app size, license tolerance, whether it must integrate with an
   existing house package.
2. **Check CONVENTIONS first.** If the need maps to a house default, that *is*
   the answer — verify it's still healthy and recommend it. Only look wider if
   it's genuinely unassigned (charts, image picker, date utils, permissions…).
3. **Read the references** ([`CONVENTIONS.md`](../../references/CONVENTIONS.md))
   and the curated map at [`templates/curated_packages.md`](templates/curated_packages.md)
   as a **starting point** — then re-verify with live data, never ship the
   curated pick blind.
4. **Gather candidates, score, recommend** using the method below.

## The decision method

```
need → candidates (3–5) → score each → rank → recommend #1 + fallback → rationale
```

### 1. Generate candidates (3–5)

- Start from the curated map ([`templates/curated_packages.md`](templates/curated_packages.md))
  for the need, then widen via a pub.dev search (`https://pub.dev/packages?q=<need>`
  sorted by likes/points) and the Flutter Favorites / "Dart/Flutter team"
  publisher filter.
- Always include any **first-party** option (publisher `flutter.dev`,
  `dart.dev`, `tools.flutter.dev`, or `google`) as a candidate even if less
  popular — see *Prefer first-party*.
- Drop obvious non-starters early: discontinued, no null-safety, no Android
  support, abandoned >24mo with a maintained alternative present.

### 2. Score each candidate

Reuse #56's evidence and rubric — same data sources, same scorer — so a
recommendation and a health audit never disagree:

```bash
python "../../skills/56_Dependency_Health_Monitor/scripts/dep_health.py" \
  --packages fl_chart,syncfusion_flutter_charts,charts_flutter --osv --json
```

(Feed candidate names; the script pulls pub points, likes, popularity, 30-day
downloads, `is:null-safe` / `is:dart3-compatible` tags, last-publish cadence,
and OSV advisories. If your build of the script only accepts a manifest, write a
throwaway `pubspec.yaml` listing the candidates and point it at that.)

Then apply the **recommendation rubric**
([`templates/recommendation_rubric.md`](templates/recommendation_rubric.md)),
which extends #56's health score with the four selection-only dimensions that
only matter when *choosing* (not when monitoring):

| Bucket | Dimensions | Source |
|---|---|---|
| **Health** (from #56) | maintenance · popularity · pub points · modern-Dart · vulnerabilities · abandonment · breaking-change | `dep_health.py` |
| **License** | OSI-permissive? copyleft? unknown? | pub.dev page / LICENSE |
| **Size impact** | native code, heavy assets, big transitive tree | tags + CONVENTIONS |
| **Platform support** | declared platforms incl. **Android**; federated plugin? | pub.dev "Platform" chips |
| **House-stack fit** | composes with Riverpod/dio/freezed; no off-stack duplicate | CONVENTIONS |

### 3. Rank and recommend one + a fallback

- Compute each candidate's **recommendation score** (rubric weights) and sort.
- The top scorer is the **primary recommendation** *unless* a hard reject
  applies (see below) — then it's disqualified and the next one wins.
- Always name a **fallback** (the runner-up) and say *when* you'd switch to it
  (e.g. "use the fallback if you need iOS desktop support" or "if the GPL is a
  blocker"). A recommendation without a fallback is incomplete.

### 4. Write the rationale

Two to four sentences max, evidence-based: why #1 wins (cite last-publish date,
likes/points, license, platforms), what the fallback trades off, and the
on-stack note (how it plugs into Riverpod/dio/freezed). No vibes — every claim
ties to a number or a fact.

## When to prefer first-party / Flutter-team packages

Prefer a package published by `flutter.dev` / `dart.dev` / `google` **when it's a
real peer** on capability, because it tracks the SDK, won't get abandoned by a
solo maintainer, and is the reference implementation:

- **Always prefer first-party** for: platform plumbing — `image_picker`,
  `url_launcher`, `shared_preferences`, `path_provider`, `connectivity_plus`*,
  `package_info_plus`*, `device_info_plus`* (* = `fluttercommunity`, treat as
  near-first-party Flutter Favorites).
- **Prefer first-party unless beaten on capability** for: things where a
  third-party package is genuinely more capable (e.g. `flutter_local_notifications`
  over a thinner official option). Capability can outweigh provenance — but say so.
- A first-party package that is **stale or feature-poor** does not win by
  provenance alone; note it and pick the maintained third-party peer.
- **Flutter Favorites** (the pub.dev badge) is a strong positive signal but not a
  guarantee — still run the health score.

## License red flags

License is a **hard gate**, scored before popularity ever matters. Pull it from
the pub.dev package page (it surfaces the SPDX id) or the repo `LICENSE`.

| License | Verdict |
|---|---|
| MIT, BSD-2/3, Apache-2.0, MPL-2.0 (file-level copyleft) | ✅ Safe — default-OK for app distribution. |
| LGPL (dynamic-link only) | 🟡 Caution — fine for libraries, awkward for a statically-linked Flutter binary; prefer an alternative. |
| **GPL-3.0 / AGPL-3.0** | 🔴 Reject for closed-source apps — copyleft can force you to open your whole app. Find an alternative. |
| **No license / "all rights reserved" / unknown** | 🔴 Reject — legally you have *no* right to use it. |
| Custom / "non-commercial" / source-available | 🔴 Route to **#58** before recommending; assume reject until cleared. |

Any 🔴 license **disqualifies** the candidate no matter how popular or healthy it
is — drop to the fallback and say why. Surface every license you recommend to
**#58** for the compliance record.

## Hard rejects (drop a candidate even if it's #1)

- Open **OSV advisory** with no fixed version available.
- **No null-safety** in a Dart-3 project (CONVENTIONS targets Dart 3).
- **No Android support** (we are Android-first).
- **Discontinued** on pub.dev with a maintained peer present.
- 🔴 **license** (above).
- **Off-stack duplicate** of a house default (a second HTTP client beside `dio`,
  `GetX` beside Riverpod) — recommend consolidating onto the house default
  instead.

When the only candidates are all rejectable, say so plainly and recommend the
least-bad option *with its risk called out* + a follow-up (e.g. "vendor it",
"watch for a successor", "raise with #58").

## How this feeds the pipeline

- **From #56 (Dependency Health):** every "replace this abandoned package"
  finding arrives here as a need + constraints (on-stack, null-safe, maintained).
  You return the on-stack alternative and its fallback.
- **To #11 (Backend Integration) / #06 (Architecture):** the chosen package and
  its constraint (e.g. `fl_chart: ^0.69.0`) is what these stages add to
  `pubspec.yaml` and wire behind a repository / provider. You hand them the pick,
  the version constraint, and the one-line integration note.
- **To #32 (Maintenance):** when the recommendation is a *replacement* of an
  existing dep, #32 owns the swap PR (remove old, add new, migrate call sites).
- **To #58 (License/Compliance):** every recommended license is logged for
  sign-off before merge.

## Output discipline

- Recommend **exactly one** primary pick and **one** fallback — not a menu.
- Every claim cites evidence: last-publish date, likes/points, license id,
  declared platforms. No "this seems popular".
- Always state the **house-stack fit** in one line (how it sits with
  Riverpod/dio/freezed) and flag any off-stack risk.
- Mark the curated map as a **starting point** — confirm with live #56 data
  before committing, because health changes month to month.
- End with the handoff: which skill (#11/#06/#32) adds it, and the #58 license note.

See the scoring model in [`templates/recommendation_rubric.md`](templates/recommendation_rubric.md)
and the need→package starting map in [`templates/curated_packages.md`](templates/curated_packages.md).
