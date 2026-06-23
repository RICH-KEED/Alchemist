# Production Readiness Checklist — <app name>

Date: <yyyy-mm-dd> · Reviewer: <name> · Target track: <internal | closed | open | production>

> Read-only audit. Tick an item only when you have **verified evidence** (artifact, config,
> dashboard). Each item notes its **owning stage** — route any gap back there. Unchecked = blocker
> or risk to record in the go/no-go report.

---

## A. Pipeline gates 02–23 (re-verify, don't trust the tick)

- [ ] 02 Product_Planning — `docs/PRD.md`: MVP scope + success metrics agreed *(stage 02)*
- [ ] 03 UI_UX_Planning — `docs/UX.md`: every story maps to a screen + flow *(stage 03)*
- [ ] 04 Premium_Design_System — tokens compile; light + dark defined *(stage 04)*
- [ ] 05 App_Preview — stakeholder sign-off on look & feel *(stage 05)*
- [ ] 06 Flutter_Architecture — `flutter analyze` clean; app boots *(stage 06)*
- [ ] 07 Navigation — all screens reachable; deep links resolve *(stage 07)*
- [ ] 08 Riverpod — state wired; provider override tests pass *(stage 08)*
- [ ] 09 Animation — motion 60fps; no jank in profile *(stage 09)*
- [ ] 10 Asset_Management — assets typed; adaptive icon + splash render *(stage 10)*
- [ ] 11 Backend_Integration — endpoints return mapped domain via `Result` *(stage 11)*
- [ ] 12 API_Testing — green against mock; contracts pinned *(stage 12)*
- [ ] 13 Security — MASVS-L1 checks pass; secrets never plaintext *(stage 13)*
- [ ] 14 Network_Resilience — degrades gracefully offline; retries bounded *(stage 14)*
- [ ] 15 Error_Handling — no uncaught errors; every error has UX + log *(stage 15)*
- [ ] 16 Loading_States — all four async states on every data surface *(stage 16)*
- [ ] 17 Responsive_UI — phone/tablet/foldable + both orientations OK *(stage 17)*
- [ ] 18 Documentation — public APIs documented; ADRs for key decisions *(stage 18)*
- [ ] 19 GitHub_Workflow — repo hygiene; PR/issue templates live *(stage 19)*
- [ ] 20 Testing — coverage gate met; CI test job green *(stage 20)*
- [ ] 21 CICD — build+test+sign automated on push/tag *(stage 21)*
- [ ] 22 Deployment — internal track release succeeded *(stage 22)*
- [ ] 23 Monitoring — events/crashes visible in dashboard *(stage 23)*

---

## B. Performance *(stages 06, 09, 10)*

- [ ] Cold **startup time** measured in release/profile mode within budget *(06)*
- [ ] **Jank**: frame build + raster < 16ms (60fps) on core flows *(09)*
- [ ] **App size**: release AAB inspected with `--analyze-size`; no bloat *(10)*
- [ ] **Memory**: no leaks on navigation churn; images sized/cached *(06)*
- [ ] Profiling done in **release mode**, not debug *(06)*

## C. Stability *(stages 15, 16)*

- [ ] **Crash-free rate target** defined and dashboard shows headroom *(23)*
- [ ] `runZonedGuarded` + `FlutterError.onError` wired; test crash captured *(15)*
- [ ] **No uncaught errors** in logs from a smoke run *(15)*
- [ ] **Error UX everywhere**: loading · data · empty · error on every surface *(16)*

## D. Security *(stage 13)*

- [ ] **MASVS-L1** checklist passes *(13)*
- [ ] **No secrets** in repo or binary (grep source + inspect strings) *(13)*
- [ ] **TLS** enforced; no cleartext; pinning where required *(13)*
- [ ] **Obfuscation + minification** on for release *(13)*
- [ ] **Mapping / symbols uploaded** so crashes deobfuscate *(13, 23)*

## E. Accessibility *(stages 04, 16, 17)*

- [ ] **Semantics** labels on interactive + image elements *(16)*
- [ ] **Contrast** meets WCAG AA in light and dark *(04)*
- [ ] **Text scaling** to ~200% does not clip or break layout *(17)*
- [ ] **Touch targets** ≥ 48dp *(04, 17)*
- [ ] **Screen-reader pass** (TalkBack) on core flows *(17)*

## F. Store compliance *(stage 22)*

- [ ] **Target API level** meets current Play requirement *(22)*
- [ ] **Permissions** each justified; no unused/dangerous ones *(22)*
- [ ] **Data safety form** completed and matches actual collection *(22, 23)*
- [ ] **Content rating** questionnaire submitted *(22)*
- [ ] **Privacy policy URL** live and reachable *(22)*

## G. Privacy *(stage 23)*

- [ ] **Consent** captured before non-essential data collection *(23)*
- [ ] **Data minimization**: only what features need *(23)*
- [ ] **Analytics opt-out** honored end-to-end *(23)*

## H. Observability *(stage 23)*

- [ ] **Crash reporting live** in prod config; verified test event *(23)*
- [ ] **Analytics live**: key funnel events appear in dashboard *(23)*
- [ ] Perf monitoring + structured logging wired; alert owner named *(23)*

## I. Release hygiene *(stage 22)*

- [ ] **Versioning**: `versionName` + increasing `versionCode` correct *(22)*
- [ ] **Staged rollout** planned (e.g. 5%→20%→50%→100%) *(22)*
- [ ] **Rollback plan** written: halt + previous-good build identified *(22)*

## J. Docs *(stage 18)*

- [ ] README runnable from clean checkout *(18)*
- [ ] ADRs cover key decisions; release notes drafted *(18)*
- [ ] Runbook: on-call, dashboards/alerts, crash-spike triage *(18, 23)*

---

**Result:** ___ / ___ verified · **Blockers:** ___ · **Recommendation:** GO / NO-GO / CONDITIONAL

See [`../../../references/CONVENTIONS.md`](../../../references/CONVENTIONS.md).
