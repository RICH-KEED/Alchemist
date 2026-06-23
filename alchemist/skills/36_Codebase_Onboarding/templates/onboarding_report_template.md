# Onboarding Report — `<project_name>`

**Generated:** `<date>` | **Mode:** `<greenfield | brownfield>` | **Analyzed by:** Codebase Onboarding (#36)

---

## 1. Architecture Overview

```
%% Replace this placeholder with a real Mermaid diagram.
%% Use graph TD or flowchart LR. Show:
%%   - main.dart bootstrap
%%   - App widget (MaterialApp.router)
%%   - Router (go_router / auto_route / manual)
%%   - Feature layers: presentation → application → domain ← data
%%   - Core cross-cutting: errors, network, shared widgets, theme
%%   - External: API server, local DB, auth provider, analytics
%% Label edges with data types (e.g. "Result<User>").

graph TD
    main[main.dart] --> app[MaterialApp.router]
    app --> router[Router]
    app --> theme[ThemeData]
    router --> screens[Screens / Pages]

    subgraph Feature["Feature: <name>"]
        pres[Presentation] --> app_layer[Application]
        app_layer --> dom[Domain]
        dom <--> data[Data]
    end

    data --> api[API Server]
    data --> db[Local DB]

    subgraph Core["core/"]
        errors[Error / Failure]
        network[Dio Client]
        widgets[Shared Widgets]
    end

    errors --> pres
    network --> data
```

### Data flow (narrative)

<!-- Describe how a typical request flows: user taps → widget calls controller →
     controller invokes repository → repository calls data source → maps DTO → entity →
     returns Result → controller emits state → UI rebuilds. Adapt to the actual pattern found. -->

---

## 2. Dependency Inventory

| Package | Version | Concern | Status | Notes |
|---|---|---|---|---|
| `flutter` | `<version>` | SDK | — | Channel: `<stable/beta/master>` |
| `<state_mgmt>` | `<version>` | State management | `<current / outdated / deprecated>` | |
| `<router>` | `<version>` | Routing | | |
| `<http_client>` | `<version>` | Networking | | |
| `freezed` / — | `<version or N/A>` | Codegen | | |
| `<lint_package>` | `<version>` | Linting | | |
| `<test_package>` | `<version>` | Testing | | |
| `<db_package>` | `<version>` | Local storage | | |

<!-- Add rows for every significant dependency. Group by concern.
     Flag deprecated packages with ⚠️ and their recommended replacement. -->

---

## 3. Conventions Cross-Reference

| Concern | Pipeline Convention | This Project | Status |
|---|---|---|---|
| Dart SDK | Dart 3.x | | ✅ / ⚠️ / ❌ |
| Lints | `very_good_analysis` | | |
| State management | Riverpod 2.x + codegen | | |
| Models | freezed + json_serializable | | |
| Errors | sealed Failure + Result | | |
| Routing | go_router | | |
| Networking | dio | | |
| DI | Riverpod providers | | |
| Theming | Material 3, ColorScheme.fromSeed | | |
| Layout | feature-first (4 layers) | | |
| Assets | flutter_gen | | |
| Testing | mocktail + golden + integration_test | | |
| Crash/analytics | Sentry / Crashlytics | | |

### Notable divergences

<!-- For each ❌ or ⚠️ row, add a one-paragraph explanation:
     what the project does instead, why it matters, and whether it's worth migrating. -->

---

## 4. Risk Hotspots

| Risk | Location | Severity | Detail | Mitigation |
|---|---|---|---|---|
| | | 🔴 / 🟡 / 🟢 | | |

<!-- Common scans:
     - Zero tests → "test/ directory empty or missing"
     - Deprecated dependencies → list each from §2
     - No error boundaries → "no global error widget or runZonedGuarded"
     - Business logic in widgets → "setState / http calls in build methods"
     - Hardcoded strings/colors → "no Theme tokens; hex strings in widgets"
     - Missing null safety → "SDK constraint < 2.12 or // @dart=2.9"
     - >500-line files → list paths
     - Missing dark mode → "ThemeData.light only; no dark theme defined"
     - No CI → ".github/workflows/ missing"
     - No offline handling → "no connectivity checks; network calls fail silently"
-->

---

## 5. How to Add a Feature

<!-- Numbered walkthrough. Use real paths and real class names.
     Adapt to the actual architecture pattern found in the project. -->

1. **Create the feature folder**
   ```
   lib/features/<feature_name>/
   ├── data/
   ├── domain/
   ├── application/
   └── presentation/
   ```

2. **Define the domain entity** — create `lib/features/<feature_name>/domain/<entity>.dart`
   with a freezed model (or the project's actual model pattern).

3. **Add the repository interface** — `lib/features/<feature_name>/domain/<feature>_repository.dart`
   defining the abstract contract.

4. **Implement the data source** — `lib/features/<feature_name>/data/<feature>_data_source.dart`
   and `lib/features/<feature_name>/data/<feature>_repository_impl.dart`.

5. **Create the application layer** — `lib/features/<feature_name>/application/<feature>_notifier.dart`
   with the state management pattern this project uses.

6. **Build the screens** — in `presentation/`, one file per screen.
   Wire up async states: loading, data, empty, error.

7. **Register routes** — add to the router config file.

8. **Write tests** — unit tests for domain/data, widget tests for presentation.

---

## 6. How to Add a Screen

<!-- Specific to this project's router. Include the exact snippet they'd copy-paste. -->

1. Create the screen widget in the appropriate feature's `presentation/` folder.

2. Register the route:

```
<!-- Paste the actual route registration snippet from this project -->
```

3. Navigate to it:

```
<!-- Paste the actual navigation call pattern -->
```

4. If the screen needs data, wire the provider/notifier in the parent widget or via the route.

5. Add tests — at minimum, a smoke test that the screen builds with mock data.

---

## 7. Key Files to Know

| File | Purpose |
|---|---|
| `lib/main.dart` | App bootstrap — ProviderScope, error hooks, entry point |
| `lib/app/app.dart` | MaterialApp.router, theme, router wiring |
| `lib/app/router/<router_file>.dart` | Route definitions, guards, deep links |
| `lib/app/theme/<theme_file>.dart` | ThemeData, ColorScheme, tokens |
| `lib/core/error/<failure_file>.dart` | Failure hierarchy, Result type |
| `lib/core/network/<network_file>.dart` | Dio client, interceptors, base URL |
| `lib/features/<example>/domain/<entity>.dart` | Representative domain entity |
| `lib/features/<example>/application/<notifier>.dart` | Representative state management |
| `lib/features/<example>/presentation/<screen>.dart` | Representative screen |
| `test/<example_test>.dart` | Representative test pattern |
| `pubspec.yaml` | Dependencies, SDK constraints, assets |
| `analysis_options.yaml` | Lint rules |

<!-- Trim or expand to 10–15 entries. Choose the files a new dev will open most often. -->

---

## Appendix: Analysis Notes

<!-- Internal: what was scanned, what was skipped, sampling strategy for large projects,
     commands that failed, edge cases in the analysis. For the onboarding agent's use. -->

- **Scope:** `<N> Dart files in lib/; <M> test files`
- **Sampling:** `<strategy if project >200 files>`
- **Errors during analysis:** `<any failed commands or missing tools>`
- **Secrets redacted:** `<count or "none found">`
