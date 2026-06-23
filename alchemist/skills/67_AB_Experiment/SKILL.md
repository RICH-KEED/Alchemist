---
name: AB Experiment
description: Wire A/B experiments on top of Remote Config — variant assignment, exposure logging, guardrail metrics, and a clean experiment harness. Use when you need to test a feature variant, measure conversion impact, or run a controlled rollout.
when_to_use: Trigger on "set up an A/B test", "run an experiment", "feature experiment", "variant test", "controlled rollout", "measure this change", "which version performs better", or when remote config (#54) is already in place and you want to add experimentation on top.
---

# A/B Experiment

You wire **safe, measurable A/B experiments** on top of the Remote Config infrastructure from [skill 54](../54_Remote_Config/SKILL.md). You provide the harness for variant assignment, exposure logging, guardrail metrics, and result analysis — so every feature change can be tested with real users before rolling out.

House style: [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md). The Remote Config layer ([skill 54](../54_Remote_Config/SKILL.md)) must exist before this skill can be used.

**Done when:** an experiment is wired with variant assignment, exposure logged, guardrails defined, and the control/variant branches are measurable.

---
## When to experiment (and when not to)

| Situation | Experiment? |
|---|---|
| New feature — unsure if it improves conversion | YES |
| UI redesign — want to measure engagement delta | YES |
| Algorithm change — want to compare relevance/quality | YES |
| Bug fix — just fix it | NO |
| Performance improvement — just ship it (measure with monitoring, not A/B) | NO |
| Trivial copy change — ship it, track with analytics | NO |

---
## Step 1 — Define the experiment

Before writing any code, document:

1. **Hypothesis:** "If we [change], then [metric] will [increase/decrease] because [reason]."
2. **Primary metric:** the one number that decides the winner (conversion rate, retention D7, time-to-value, etc.).
3. **Guardrail metrics:** metrics that must NOT degrade (crash rate, latency P95, error rate, core flow completion). If a guardrail degrades, the experiment is killed regardless of primary metric.
4. **Variants:** control (existing behavior) + 1-3 variant(s).
5. **Traffic split:** default 50/50 for 2 variants; adjust for risk (90/10 if the variant is high-risk).
6. **Duration / sample size:** how many users / how long before you can read a result. Use a sample-size calculator if the team has one; otherwise estimate and be honest about uncertainty.

---
## Step 2 — Variant assignment (deterministic + sticky)

Use the experiment harness template at [`templates/experiment_harness.dart`](templates/experiment_harness.dart). Core rules:

- **Remote Config is the source of truth** for experiment configuration (active/inactive, variant weights, targeting).
- **Deterministic assignment** — hash the user ID + experiment ID so the same user always gets the same variant (sticky across sessions, even if offline).
- **Fallback to control** — if Remote Config fetch fails or the experiment config is missing, the user gets the control variant. Never crash on missing experiment data.
- **Log the assignment** immediately after assignment (Step 3).

```dart
// Minimal assignment flow
final experiment = await ref.read(experimentServiceProvider).getExperiment('new_checkout');
final variant = experiment.assign(userId);  // deterministic hash
// variant is 'control', 'variant_a', 'variant_b', etc.
```

Never expose variant assignment to `BuildContext` directly — route it through a Riverpod provider so it's testable and overrideable.

---
## Step 3 — Exposure logging

An experiment is only valid if exposure is logged. Log once, immediately after assignment, before any variant code runs:

- **User ID** (hashed/anonymized per privacy policy).
- **Experiment ID** (e.g., `new_checkout_v1`).
- **Variant assigned** (`control`, `variant_a`).
- **Timestamp** (device time, UTC).
- **App version** + **platform** (Android/iOS).

Send to the project's analytics backend (Firebase Analytics, custom endpoint, etc.). If offline, queue and send on connectivity. If the analytics event fails to send, **still proceed with the variant** — never block UX on analytics delivery.

---
## Step 4 — Guardrail monitoring

Wire guardrail checks that fire **per session** or **per event**:

```dart
// After a guarded operation
experimentService.recordGuardrail(
  experimentId: 'new_checkout_v1',
  guardrail: 'checkout_error_rate',
  value: success ? 0.0 : 1.0,  // 0 = no error, 1 = error occurred
);
```

Guardrails to consider by default:
- Crash rate (per experiment variant, from crash reporting).
- Error rate on the affected flow.
- Latency P95 on the affected flow.
- Core flow completion rate (if the experiment touches a multi-step flow).

The harness collects these but does **not** kill the experiment automatically — that is a human decision (or a dashboard alert). The harness just ensures the data exists to make the decision.

---
## Step 5 — Ship the experiment config to Remote Config

Create the experiment definition in the Remote Config template. The config defines:
- Which experiments are active.
- Variant weights (for traffic split).
- Targeting rules (min app version, country, user percentage).

Use the Remote Config parameter format from skill 54. Load the experiment harness config on app start.

---
## Step 6 — Cleanup after the experiment

Every experiment must have a **sunset plan** defined at creation:

1. **Winner declared:** remove the experiment config from Remote Config, ship the winning variant as the permanent behavior, delete all variant code paths.
2. **Inconclusive:** extend duration, or promote to a larger sample, or kill and learn.
3. **Killed (guardrail degraded):** immediately set control to 100% in Remote Config, investigate.

After sunset, **remove the experiment wiring** — dead experiment code is tech debt. The harness reference stays, but the specific experiment (variant branches, config key, analytics events) must be cleaned up within one release cycle.

---
## Cross-references

- **54 Remote_Config** — prerequisite; provides the config infrastructure this skill layers on.
- **23 Monitoring** — receives exposure logs and guardrail metrics.
- **22 Deployment** — phased rollout (non-experiment) is a deployment concern; this skill is for controlled experiments.
- **59 Privacy_Data_Safety** — experiment logging must comply with privacy policy; user IDs must be anonymized.

See the Dart harness template in [`templates/experiment_harness.dart`](templates/experiment_harness.dart).
