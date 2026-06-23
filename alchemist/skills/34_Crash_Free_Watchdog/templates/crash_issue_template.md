---
# This template is used by Crash Free Watchdog (#34) to file crash signals.
# The skill populates every section; a human or #38 picks up from "Proposed fix direction."
# Do not delete or reorder sections — downstream automation depends on the headings.
labels: ["crash-watchdog", "monitoring"]
assignees: []
---

## Crash Signature

**Exception type:** <!-- e.g. NullPointerException, MissingPluginException -->
**Exception message:** <!-- verbatim from the provider -->
**Top stack frame (project code):** <!-- file:line — or "No project frame" -->

## Stack Trace

```
<!-- Full stack trace from Sentry/Crashlytics. Paste verbatim, no trimming. -->
```

## Affected Versions

| App version | OS version | Device model | Event count |
|---|---|---|---|
| <!-- app version --> | <!-- Android/iOS version --> | <!-- device --> | <!-- count --> |

## Event Count & Trend

- **Total events in this sweep window:** <!-- N -->
- **First seen (provider timestamp):** <!-- ISO 8601 -->
- **Last seen (provider timestamp):** <!-- ISO 8601 -->
- **Rate trend:** <!-- "NEW" (first occurrence), "SPIKE" (×N above rolling average), "REGRESSION" (was resolved, now back) -->

## Classification

- **Family:** <!-- null-npe | platform | async-gap | widget-tree | unclassified -->
- **Severity:** <!-- P1 (data-loss/crash-loop) | P2 (feature-specific) | P3 (cosmetic/rare) -->
- **Classified by:** Crash Free Watchdog (#34), sweep `<timestamp>`

## Suspect Code (git blame)

<!-- Output of: git log --follow --format="%h %an %s" -n 5 -- <suspect-file.dart> -->

```
<!-- paste git blame output here -->
```

**Suspect file:** `<!-- relative path to the file -->`
**Recent authors:**

| Commit | Author | Message |
|---|---|---|
| <!-- sha --> | <!-- author --> | <!-- subject --> |
| <!-- sha --> | <!-- author --> | <!-- subject --> |
| <!-- sha --> | <!-- author --> | <!-- subject --> |
| <!-- sha --> | <!-- author --> | <!-- subject --> |
| <!-- sha --> | <!-- author --> | <!-- subject --> |

_If no project frame exists in the stack trace, state: "No project frame in stack trace — suspect platform or plugin bug."_

## Proposed Fix Direction

<!-- One-line suggestion based on crash family. Not a full fix — that's #38's job. -->

| Family | Suggested direction |
|---|---|
| null-npe | Add null guard or `?` operator; verify data source contract |
| platform | Wrap in `try/catch` with `MissingPluginException` handler; fallback if plugin unavailable |
| async-gap | Check `mounted` before `setState`; cancel subscriptions in `dispose`; use `AsyncValue` guards |
| widget-tree | Add `Flexible`/`Expanded`, constrain bounds, or wrap in `SingleChildScrollView` |
| unclassified | Manual investigation required — inspect stack trace for patterns |

**Direction for this crash:** <!-- write the one-liner -->

## Watchdog Metadata

- **Provider:** <!-- sentry | crashlytics -->
- **Sweep timestamp:** <!-- ISO 8601 -->
- **Config reference:** `watchdog_config.yaml` revision <!-- commit SHA or "local" -->

---

<!-- Hand-off comment: Crash Free Watchdog (#34) filed this issue. @runtime-exception-triage — #38, please deep-investigate. -->
