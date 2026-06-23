---
name: "Initialize"
description: Start an interactive, continuous app build loop. Triggered via /initialize — asks for app details (name, idea, platform, constraints), then runs the full Alchemist pipeline (stages 02→24) with self-testing and refinement passes until every gate is green. When complete, delivers a build-ready artifact map — what was built, where the APK/AAB is, and what manual steps remain (SHA fingerprints, Google services JSON, Play Console setup, signing keys). The autonomous build-and-refine loop that turns an idea into a shipped app.
when_to_use: Triggered exclusively by `/initialize` or when the user says "start a new app", "begin a new project", or "initialize the pipeline". This is the entry point command for Alchemist.
trigger: /initialize
argument-hint: "[app-name]"
---

# /initialize — Alchemist Interactive Build Loop

You are the Alchemist entry point. When a user types `/initialize`, you do NOT just start building — you first extract the app's DNA, then run a **continuous build-and-refine loop** across the full 24-stage pipeline. After building, you deliver a **completion report** with all artifacts and the **manual-steps checklist** the user must complete.

---
## Phase 1 — Extract the app DNA (interactive)

Ask 5–8 questions to spec the app. Do NOT ask all at once — ask 2–3, use the answers to ask better follow-ups. Target < 2 minutes of Q&A.

**Tier 1 — must ask:**
1. What does the app do? (one sentence elevator pitch)
2. Who is it for? (target user — skip if obvious from #1)
3. Platform targets? (default: Android-only MVP; expand to iOS/web if asked)

**Tier 2 — ask based on context:**
4. Does it need user accounts / sign-in? (→ stages 11, 13, 07 auth redirect)
5. Does it need a backend / API? (→ stage 11, 49 OpenAPI if they have a spec)
6. Offline-capable or online-only? (→ stage 14 Network Resilience)
7. Any special compliance needs? (GDPR, HIPAA — → stages 58, 59, 60)

**Tier 3 — visuals / quality:**
8. Any brand colors or a visual mood? (→ stage 04 seed color)
9. Target timeline / quality tier? (MVP quick vs production polished)

Record answers in `.flutter-pipeline/APP_DNA.md`.

---
## Phase 2 — Run the pipeline with feedback loops

Execute stages 02→24 per the Master Orchestrator (`skills/01_Master_Orchestrator/SKILL.md`), with three key additions:

### A. The refine loop (stages 04, 05, 09, 16, 17)
After each UI-facing stage, **capture a screenshot** (Pencil MCP or `flutter run` + adb), run the **Design Critic (skill 43)** against it, apply its top 3 fixes, and re-capture. Loop until the critic gives ≥4/5 across all dimensions or 3 iterations pass.

### B. The quality loop (stages 12, 15, 20)
After each testing stage, run the **Analyzer Auto-Fix (skill 41)** until zero warnings, then run the generated tests. If coverage gate fails, invoke **Test Generation (skill 70)** to fill gaps. Loop until the gate is green.

### C. The production-readiness check (stage 24)
Before declaring done, run the full **Production Readiness audit (skill 24)** plus **Accessibility Auditor (skill 45)** plus **Secrets Scanner (skill 61)**. Any critical finding → fix → re-run. Loop until pass or explicit user acceptance of remaining findings.

---
## Phase 3 — Deliver the completion report

After all 24 stages pass, produce `COMPLETION_REPORT.md` with:

### What was built
- App scaffolding (project structure, flavors, analysis_options)
- Theme (Material 3 light/dark with AppTokens)
- Features implemented (list with file paths)
- State management (providers, controllers)
- Navigation (routes, deep links)
- Testing (unit/widget/golden/integration counts, coverage %)
- CI/CD (workflow files, automation)
- Release artifacts (AAB path, version info)

### Manual steps for the user
A **checked-off-as-you-go** checklist of things the AI CANNOT do:

| Step | Why it's manual | Instructions |
|---|---|---|
| Generate upload keystore | Requires human to store passwords | `keytool -genkey -v -keystore ~/upload-keystore.jks ...` |
| Add SHA-256 fingerprint to Firebase/Google | Firebase Console requires owner login | Keytool command to get SHA, then link to Firebase Console |
| Download `google-services.json` | Requires Firebase project owner | Link to Firebase Console → Project Settings → download |
| Play Console app creation | Requires Play Console account | Link to play.google.com/console → Create app |
| Play App Signing enrollment | Requires upload key + console access | Upload the PEPK/JAR from keytool |
| Data Safety form final review | Legal requirement — human must verify | Link to Play Console Data Safety section |
| Privacy policy hosting | Needs a URL | Draft provided in `publish/privacy_policy.md` |
| Content rating questionnaire | Requires Play Console login | Link to questionnaire |
| Play Store listing screenshots | Policy requires REAL device screenshots | Capture via `flutter run --release` on a real device |
| OAuth client secrets | Requires cloud console OAuth setup | Link to Google Cloud Console |
| Apple Developer account (if iOS) | Requires paid account | Link to developer.apple.com |

### Artifact map
```
lib/                          ← app source
docs/                         ← PRD, UX, ADRs, ARCHITECTURE
test/                         ← unit + widget + golden tests
publish/                      ← Play Store copy, images, privacy policy
build/app/outputs/bundle/release/app-release.aab  ← signed AAB
.github/workflows/            ← CI/CD pipelines
.flutter-pipeline/STATE.md    ← pipeline progress
```

---
## Phase 4 — Hand off

End with:
```
🎉 Alchemist pipeline complete.

📱 APK: build/app/outputs/flutter-apk/app-release.apk
📦 AAB: build/app/outputs/bundle/release/app-release.aab

📋 9 manual steps remain before Play Store submission.
   See COMPLETION_REPORT.md for the checklist.

🔁 To continue iterating, say "refine [feature]" or "/initialize [change]".
```

---
## How Alchemist differs from invoking skill 01 directly

| Aspect | Skill 01 (Master Orchestrator) | /initialize (this skill) |
|---|---|---|
| Mode | Runs one stage at a time | Continuous loop with auto-refine |
| Gate failure | Stops and waits | Auto-fixes and re-runs |
| UI quality | Builds what's spec'd | Captures + critiques + fixes |
| Delivery | STATE.md tracking | Full completion report + manual-steps map |
| Start | "build me an app" | `/initialize` |
