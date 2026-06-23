<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)">
    <img src="https://img.shields.io/badge/Alchemist-turns%20ideas%20into%20gold-0D9488?style=for-the-badge&logo=data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCI+PHBhdGggZmlsbD0iI2ZmZiIgZD0iTTEyIDJDNi41IDIgMiA2LjUgMiAxMnM0LjUgMTAgMTAgMTAgMTAtNC41IDEwLTEwUzE3LjUgMiAxMiAyem0wIDE4Yy00LjQgMC04LTMuNi04LThzMy42LTggOC04IDggMy42IDggOC0zLjYgOC04IDh6Ii8+PC9zdmc+" alt="Alchemist">
  </picture>
</p>

<p align="center">
  <a href="https://github.com/RICH-KEED/Alchemist/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License"></a>
  <a href="#"><img src="https://img.shields.io/badge/skills-77-0D9488.svg" alt="Skills"></a>
  <a href="#"><img src="https://img.shields.io/badge/platform-Flutter%20%7C%20Android%20First-02569B.svg?logo=flutter" alt="Platform"></a>
  <a href="#"><img src="https://img.shields.io/badge/stack-Dart%203%20%7C%20M3%20%7C%20Riverpod-0175C2.svg?logo=dart" alt="Stack"></a>
  <a href="#"><img src="https://img.shields.io/badge/claude%20code-plugin-6B46C1.svg?logo=claude" alt="Claude Code"></a>
</p>

<br>

> **⚗️ Alchemist** is a Claude Code plugin that turns raw app ideas into shipped gold.<br>
> 77 skills. 24-stage pipeline. 140+ visual styles. Autonomous agents. One command: `/initialize`

---

<p align="center">
  <b>🗣️</b>&nbsp; <i>"Build me a habit tracker"</i> &nbsp;→&nbsp; <b>📱</b>&nbsp; APK + AAB + Play Store assets + CI + docs
</p>

---

## 🧬 What it does

<table>
<tr><td width="50%">

### 🎨 Design
- **140+ visual styles** — Material You, Cyberpunk, Glassmorphism, Bento, Swiss Design, Fintech…
- Premium M3 theming with `ColorScheme.fromSeed` + custom `ThemeExtension` tokens
- Design critic: screenshot → adversarial critique → fix → re-capture
- Visual regression testing across themes × screen sizes
- Figma → token-mapped Flutter widgets

</td><td width="50%">

### 🏗️ Build
- **Feature-first Clean architecture** with Riverpod DI
- go_router typed routes + deep links + auth guards
- OpenAPI → dio client + freezed DTOs + typed repositories
- Forms, push notifications, background sync, feature flags
- 4-state async UI: loading · data · empty · error on every surface

</td></tr>
<tr><td width="50%">

### 🛡️ Quality
- Dependency health scoring against pub.dev + OSV advisories
- Secrets scanner · threat modeling (STRIDE) · SBOM generation
- Accessibility audit: semantics, contrast, touch targets, TalkBack
- Mutation testing: survive our mutants, not just coverage %
- Build Doctor: Gradle/AGP/Kotlin failure diagnosis

</td><td width="50%">

### 🚀 Ship
- **Signed AAB** with Play App Signing enrollment guide
- Feature graphic + listing screenshots + Play Store copy generator
- Privacy policy + Data Safety form auto-draft
- GitHub Actions CI · Fastlane lanes · Firebase Test Lab matrix
- Changelog from Conventional Commits · ASO checklist

</td></tr>
</table>

---

## ⚡ Install

```text
/plugin marketplace add https://github.com/RICH-KEED/Alchemist
/plugin install alchemist@android-skills
```

<details>
<summary>Or clone locally</summary>

```bash
git clone https://github.com/RICH-KEED/Alchemist.git
claude --plugin-dir ./Alchemist/alchemist
```
</details>

<details>
<summary>Validate</summary>

```bash
claude plugin validate ./alchemist
# ✔ Validation passed — 77 skills discovered
```
</details>

---

## 🪄 Quick start

```
/initialize
```

Alchemist asks 5-8 questions — *"What does the app do? Who is it for? Any brand colors?"* — then runs the full pipeline with **three feedback loops**:

| Loop | What happens |
|---|---|
| 🎨 **Design** | Build → screenshot → Design Critic scores it → apply top fixes → repeat until ≥4/5 |
| 🧪 **Quality** | Generate tests → run → coverage gate → Test Generation fills gaps → repeat until green |
| 🚢 **Production** | Audit accessibility + secrets + performance → fix → re-audit → pass or escalate |

**You get back:** signed APK/AAB · CI pipeline · Play Store graphics + copy · privacy policy · architecture docs · a **10-step manual checklist** of the things only a human can do (SHA fingerprint, Play Console, signing keys).

---

## 📦 Skill clusters

| # | Cluster | Skills |
|---|---|---|
| 01–24 | **Pipeline** | Orchestrator · Product/UX Planning · Premium Design System · Architecture · Navigation · Riverpod · Animation · Backend · Security · Error Handling · Loading States · Responsive UI · Testing · CI/CD · Deployment · Monitoring |
| 25–31 | **Token Economy** | Semantic Index · Context Compression · Diff-Scoped Loader · Skill Router · Budget Governor |
| 32–36 | **Autonomy** | Autonomous Maintenance · Self-Healing CI · Crash-Free Watchdog · Telemetry · Onboarding |
| 37–42 | **Correctness** | Build Doctor · Exception Triage · Performance Profiler · State Leak Auditor · Analyzer Auto-Fix · Architecture Debate |
| 43–48 | **UI Intelligence** | Design Critic · Visual Regression · Accessibility Auditor · Figma Bridge · Screenshot→Widget · Motion Critic |
| 49–55 | **Codegen** | OpenAPI Generator · i18n · DB Migrations · Push Notifications · Background Sync · Feature Flags · Forms |
| 56–63 | **Enterprise** | Dependency Health · Package Rec · SBOM · Privacy/Data Safety · Threat Model · Secrets Scanner · White-Label · Decision Ledger |
| 64–69 | **Product** | ASO · Changelog · Analytics Taxonomy · A/B Experiments · Performance Budget · Device Matrix |
| 70–74 | **Reliability** | Test Generation · Mutation Testing · Contract Drift · Regression Memory · Chaos Testing |
| 75–80 | **UX & Delivery** | Onboarding & Coach Marks · Cross-Project Patterns · Store & Docs Publisher · App Icon Generator · Initialize |

---

## 🎨 Visual style range

The [UI Style Taxonomy](alchemist/references/UI_STYLE_TAXONOMY.md) maps 140+ aesthetics to Material 3 tokens:

`Material You` · `Cyberpunk` · `Glassmorphism` · `Neo-Brutalism` · `Bento` · `Swiss Design` · `Bauhaus` · `Neumorphism` · `Claymorphism` · `Vaporwave` · `Y2K` · `Memphis` · `Fintech UI` · `SaaS UI` · `Dashboard` · `Luxury` · `VisionOS` · `Spatial` · `Conversational` · `Zero-UI` … and 120 more.

Every style compiles to `ThemeData` + `AppTokens`. No custom renderer — just the right tokens for the aesthetic.

---

## 🏛️ Architecture

```
alchemist/
  .claude-plugin/plugin.json         # plugin manifest
  references/
    CONVENTIONS.md                    # house style (law)
    PIPELINE.md                       # 24-stage flow + exit gates
    UI_STYLE_TAXONOMY.md              # 140+ visual styles
  skills/
    NN_Name/
      SKILL.md                        # skill definition + instructions
      templates/                      # copy-pasteable Dart / YAML / config
      scripts/                        # runnable Python / Bash tooling
```

Every skill ships **instructions + compilable templates + deterministic scripts** — not just prose.

---

## 🔧 Stack

| Concern | Choice |
|---|---|
| Language | Dart 3 — sealed classes, records, pattern matching |
| State | Riverpod 2.x (`riverpod_generator`, `riverpod_lint`) |
| Routing | go_router — typed routes, deep links, auth guards |
| Models | freezed + json_serializable |
| Networking | dio — interceptors, retry, circuit breaker |
| Theming | Material 3 — `ColorScheme.fromSeed` + `ThemeExtension` tokens |
| Lints | very_good_analysis |
| Testing | flutter_test · mocktail · golden · integration_test |
| CI/CD | GitHub Actions · Fastlane · Firebase Test Lab |

---

## 🤝 Contributing

This is `v1.0.0` — fresh out of the forge. The [roadmap](docs/SKILL_EXPANSION_ROADMAP.md) has the full expansion plan. PRs, issues, and new skill proposals welcome.

---

## 📄 License

MIT — build whatever you want.

---

<p align="center">
  <sub>⚗️ Built with Claude Code · 77 skills · 3 memory systems · 2 autonomous agents · 1 command</sub>
</p>
