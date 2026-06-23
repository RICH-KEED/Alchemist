# Package Recommendation Rubric

Scoring model for the Package Recommendation Engine (#57). Use it to turn a set
of candidate packages into a single ranked recommendation + fallback.

It **reuses** the #56 health score (don't recompute it) and adds the four
selection-only dimensions that only matter when *choosing* a package, not when
monitoring one you already have.

House stack reference: [`../../../references/CONVENTIONS.md`](../../../references/CONVENTIONS.md).
Health rubric reference: [`../../56_Dependency_Health_Monitor/templates/health_rubric.md`](../../56_Dependency_Health_Monitor/templates/health_rubric.md).

---

## Recommendation score (0–100)

| # | Dimension | Weight | How to score (0–100) |
|---|---|---:|---|
| 1 | **Health** (whole #56 score) | 45% | Take the package's #56 weighted health score (maintenance + popularity + pub points + modern-Dart + vulns + abandonment + breaking) directly. This carries the bulk of the evidence. |
| 2 | **License** | 15% | OSI-permissive (MIT/BSD/Apache/MPL) = 100; LGPL = 50; unknown/custom = 0 (and triggers a hard reject); GPL/AGPL = 0 (hard reject). |
| 3 | **Size impact** | 10% | Pure-Dart / small = 100; moderate native or assets = 70; heavy native SDK / large transitive tree (maps, ML, full video) = 30. |
| 4 | **Platform support** | 10% | Declares **Android** + needed platforms = 100; Android-only when cross-platform wanted = 60; missing a required platform = 0 (hard reject for that need). |
| 5 | **House-stack fit** | 20% | Composes cleanly with Riverpod/dio/freezed and is *not* an off-stack duplicate = 100; needs a thin adapter = 75; fights the stack or duplicates a house default = 25. First-party/Flutter-Favorite peer: +10 (cap 100). |

**Recommendation score** = Σ(dimension × weight). Round to integer. Rank
candidates by this; highest wins **unless a hard reject disqualifies it**.

> Why health is only 45% (not 100): a perfectly healthy package with a GPL
> license, no Android support, or that duplicates `dio` is still the **wrong**
> pick. Selection weighs fit and legality that monitoring ignores.

---

## Hard rejects (disqualify regardless of score)

Apply *before* ranking. A rejected candidate cannot be the recommendation even
if it scores highest — drop to the next candidate (the fallback).

- 🔴 **License**: GPL-3.0 / AGPL-3.0 / no-license / "all rights reserved" /
  unknown / non-commercial. (Custom → route to #58 first.)
- 🔴 **Open OSV advisory** with no fixed version.
- 🔴 **No null-safety** in a Dart-3 project.
- 🔴 **No Android support** (Android-first house rule).
- 🔴 **Discontinued** on pub.dev while a maintained peer exists.
- 🔴 **Off-stack duplicate** of a house default → recommend the house default.

---

## When to reject a *popular* package

Popularity (likes / downloads) is a signal, not a verdict. Reject or down-rank a
popular package when:

| Situation | Why reject / down-rank | Do instead |
|---|---|---|
| Popular but **last publish > 18mo** | Riding old goodwill; abandonment risk. | Prefer a maintained peer even with fewer likes. |
| Popular but **GPL/AGPL/unknown license** | Legal risk outweighs convenience. | Fallback to permissive-licensed peer. |
| Popular but **off-stack duplicate** (e.g. `GetX`, second HTTP client, `provider` beside Riverpod) | Two ways to do one thing; CONVENTIONS already chose. | Recommend the house default. |
| Popular but **heavy native SDK** for a light need | Pays app-size/build cost it doesn't need. | Prefer a pure-Dart option for the simple case. |
| Popular but **open advisory, no fix** | Active vulnerability. | Reject until patched; pick the secure peer. |
| Popular but **no null-safety / not Dart-3** | Won't compile clean under our targets. | Reject; pick a modern peer. |
| Popular **third-party** where a **first-party peer is equal** | Provenance lowers abandonment risk. | Prefer first-party (see SKILL "Prefer first-party"). |

A higher like-count never overrides a hard reject or the house stack.

---

## Tie-breakers (scores within ~5 points)

1. **First-party / Flutter Favorite** beats third-party.
2. **More permissive license** wins (MIT/BSD over MPL over LGPL).
3. **Smaller size / fewer native deps** wins.
4. **Better house-stack fit** (no adapter needed) wins.
5. **Fresher last-publish** wins.

---

## Output: the recommendation block

For each need, produce:

```
Need:        <capability, one line>
Recommend:   <package>  ^<version>     (score NN/100)
  why:       <2–4 sentences: cite last-publish, likes/points, license, platforms>
  stack-fit: <one line: how it sits with Riverpod/dio/freezed>
Fallback:    <runner-up>               (score NN/100)
  when:      <the condition under which you'd switch to it>
Rejected:    <candidate> — <hard-reject reason>   (if any)
Handoff:     add via #11/#06 (or swap via #32); license logged to #58
```

Always: one primary, one fallback, evidence cited, stack-fit stated, handoff named.
