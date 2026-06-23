---
name: Crash Free Watchdog
description: Watch Sentry/Firebase Crashlytics for new crash signatures or crash-free % drops — triage and open a GitHub issue with suspect code from git blame for every actionable signal. Use when "crash-free rate dropped", "a new crash signature appeared in prod", "Sentry shows a spike", "Crashlytics is lighting up", or any dashboard/alert paste. Feeds into Runtime Exception Triage (#38) for deep investigation.
when_to_use: Trigger on crash dashboard reports, Sentry/Crashlytics alert copy-paste, user reports of crashes in the wild ("users are crashing on Android"), or periodic monitoring sweeps scheduled by #32. This skill detects and files — never deep-investigates. For deep root-cause investigation, hand the filed issue to Runtime Exception Triage (#38).
---

# Crash Free Watchdog (Roadmap #34)

Production crashes are the highest-severity signal your monitoring stack can emit. Your job is to
**watch the crash dashboard for new signatures and crash-free % drops, classify each signal, git-blame
the suspect code, and open a precise GitHub issue** so that #38 (Runtime Exception Triage) can
deep-investigate with full context. You are detection + filing, not investigation — you feed #38.
House style: [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md).

> Safety first: this skill **never auto-closes issues**, never suppresses a crash silently, never
> dismisses a signal as "probably fine", and never commits a fix directly. It files — a human
> (or #38) decides what to do next.

---

## 1. How it works

```
1. FETCH    Query the crash provider API (Sentry or Firebase Crashlytics) for the project.
2. PARSE    Extract crash groups/issues, their event counts, affected versions, and first/last-seen timestamps.
3. COMPARE  Diff against the last known baseline (stored state file) to find *new signatures* and
            *rate changes* on existing signatures.
4. THRESHOLD  Apply the gates from §2 — ignore noise below threshold.
5. CLASSIFY   Categorize each actionable signal (§3) so the issue carries a severity + family tag.
6. BLAME      git log --follow -n 5 <suspect-file> to surface recent commits touching the crash site.
7. FILE       Open a GitHub issue using the template (§5), tagged and assigned.
8. UPDATE     Persist the new baseline (event counts + signatures) so the next sweep diffs correctly.
```

The scheduled sweep is defined by the config in [`templates/watchdog_config.yaml`](templates/watchdog_config.yaml).
On each interval, fetch fresh data from the provider; compare against the state file stored in the repo
at `.crash_watchdog/state.json`.

---

## 2. Thresholds — what is actionable

Configurable in [`templates/watchdog_config.yaml`](templates/watchdog_config.yaml); defaults:

| Parameter | Default | Meaning |
|---|---|---|
| `crash_free_drop_pct` | 2.0 | Crash-free % declining by >= this much vs. the last period triggers a rate-change alert. |
| `min_events_for_new_signature` | 5 | A crash group must hit this many events in the current period to be treated as a new *actionable* signature. Fewer events are logged but not file-issued (prevents noise). |
| `rate_spike_factor` | 3.0 | An existing signature must spike to >= `rate_spike_factor` times its rolling-average event rate to trigger a spike alert. |
| `check_interval` | 3600 | Time in seconds between sweeps (1 hour). |

- **New signature with < min_events:** record in the state file as `triaged: false, noise: true` for
  future reference but do not file an issue.
- **Existing signature that increased but below the spike factor:** note in state, no issue.
- **Crash-free % is improving (increase):** no action — celebrate silently.

---

## 3. Triage flow — detect, classify, blame, file

Every signal that passes the thresholds moves through this pipeline.

### 3.1 Classify the crash family

| Family | Signals | Severity |
|---|---|---|
| **null / NPE** | `NullPointerException`, `Null check operator used on a null value`, `LateInitializationError` | `P1` |
| **platform-specific** | `MissingPluginException`, Android/iOS-only stack frames, `PlatformException` | `P2` |
| **async gap** | `Concurrent modification`, disposed-widget use, `Bad state: Future already completed`, `StateError` in async context | `P1` |
| **widget tree** | `RenderFlex overflow`, `A RenderFlex overflowed`, `BoxConstraints forces an infinite width`, `AssertionError` in build | `P2` |
| **unclassified** | None of the above; stack trace doesn't match known patterns | `P3` |

### 3.2 Git-blame the suspect code

From the stack trace, extract the topmost project-frame (skip framework/engine/plugin frames). Then:

```bash
git log --follow --format="%h %an %s" -n 5 -- <suspect-file.dart>
```

Include the blame output in the issue's "Suspect code" section. If no project frame appears in
the stack trace (pure platform/crash), note "No project frame in stack trace — suspect platform or
plugin bug" and escalate to #38 with severity `P2`.

### 3.3 Open the GitHub issue

Use [`templates/crash_issue_template.md`](templates/crash_issue_template.md). Always include:

- **Crash signature** (exception type + message + top frame)
- **Stack trace** (full, from the provider)
- **Affected versions** (app version + OS version)
- **Event count** and trend
- **Suspect code** from git blame (or "no project frame" note)
- **Proposed fix direction** (if the family suggests one — e.g. null guard, platform check, dispose pattern)
- **Severity** label from the classification table

Assign the issue to `auto_assign` from config; label with `crash-watchdog`, severity, and family.

---

## 4. Integration with Sentry / Firebase Crashlytics

### Sentry

```bash
# Fetch new issues in the last period (check_interval window)
curl -H "Authorization: Bearer $SENTRY_AUTH_TOKEN" \
  "https://sentry.io/api/0/projects/${SENTRY_ORG}/${SENTRY_PROJECT}/issues/?query=is:unresolved+firstSeen:-${CHECK_INTERVAL}s&statsPeriod=${CHECK_INTERVAL}s"
```

- API key: `SENTRY_AUTH_TOKEN` env var (org-level auth token with `event:read` scope).
- Env var naming: `${PROVIDER}_AUTH_TOKEN`, `${PROVIDER}_ORG`, `${PROVIDER}_PROJECT` (config-driven).
- Paginate with cursor `&cursor=` param; Sentry returns up to 100 issues per page.

### Firebase Crashlytics

Use the Firebase Admin SDK (REST) or the `firebase` CLI with the Crashlytics Issues API.

```bash
# Requires GOOGLE_APPLICATION_CREDENTIALS pointing to a service-account JSON
firebase crashlytics:issues:list --app <app-id> --duration 1h --format json
```

- Auth: service account JSON with Firebase Crashlytics Viewer role (read-only).
- Env var: `GOOGLE_APPLICATION_CREDENTIALS` for the SDK path, or `FIREBASE_SERVICE_ACCOUNT_JSON` (inline).

### State persistence

After each sweep, write the digest to `.crash_watchdog/state.json`:

```json
{
  "provider": "sentry",
  "last_sweep": "2026-06-23T14:00:00Z",
  "project": "my-app-android",
  "crash_free_pct": 98.3,
  "signatures": {
    "NullPointerException_at_HomeScreen.build": {
      "event_count": 12,
      "rate_per_hour": 1.2,
      "first_seen": "2026-06-22T08:00:00Z",
      "last_updated": "2026-06-23T14:00:00Z"
    }
  }
}
```

---

## 5. Feeding into #38 (Runtime Exception Triage)

This skill and #38 share the crash pipeline but have clean separation:

| Concern | #34 Crash Free Watchdog | #38 Runtime Exception Triage |
|---|---|---|
| Trigger | Dashboard sweep (scheduled or manual) | GitHub issue filed by #34 |
| Scope | Detect + classify + file | Deep root-cause analysis |
| Output | GitHub issue with blame + classification | Diagnosed fix, PR, or escalation |
| Git | git-blame read-only | May produce a fix commit |
| Closes issues | Never | Yes, when the fix lands |

Hand-off: when you file the issue, add a comment `@runtime-exception-triage — #34 filed this from
watchdog sweep <timestamp>.` The #38 skill picks it up from the issue tracker.

---

## 6. Safety rails

These are non-negotiable.

- **Never auto-close issues.** A crash issue stays open until a human or #38 explicitly links a fix
  commit and closes it. Don't close because "it hasn't happened again."
- **Never suppress crashes silently.** Every signal that crosses threshold gets an issue. The state
  file tracks noise patterns but does not hide them.
- **No code changes from this skill.** You file. You do not fix. (That's #38's job.)
- **Read-only API tokens.** The provider API token must be scoped to `event:read` (Sentry) or Viewer
  (Firebase). Never use write/admin tokens in an automated sweep.
- **Rate-limit your polling.** Default check every 60 minutes (see config). Do not hammer the API —
  use the cursor/pagination the provider returns.
- **Escalate unknowns.** A crash in `unclassified` family is still filed. Do not guess a family.

---

## 7. The unattended workflow

[`templates/watchdog_config.yaml`](templates/watchdog_config.yaml) carries the full provider + threshold
configuration. The scheduled sweep can be wired into:

- **GitHub Actions:** `schedule` trigger running `check_interval` minutes, calling this skill.
- **Codemagic / external cron:** POST to a webhook that triggers the sweep.
- **Manual:** run `skill: crash-free-watchdog` on-demand with a pasted alert or dashboard URL.

In scheduled mode, the sweep opens issues on the repo — set `auto_assign` to the on-call engineer
or the team handle.

---

See [`templates/watchdog_config.yaml`](templates/watchdog_config.yaml) for thresholds and provider
config, [`templates/crash_issue_template.md`](templates/crash_issue_template.md) for the issue shape,
and house style in [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md).
