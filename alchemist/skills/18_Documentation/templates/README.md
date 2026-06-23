<!--
  App README template (flutter-android skill 18_Documentation).
  Replace every <PLACEHOLDER>. Delete sections that don't apply.
  Keep it skimmable — push depth into docs/ARCHITECTURE.md.
-->

# <App Name>

[![CI](https://github.com/<org>/<repo>/actions/workflows/ci.yml/badge.svg)](https://github.com/<org>/<repo>/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/<org>/<repo>/branch/main/graph/badge.svg)](https://codecov.io/gh/<org>/<repo>)
![Flutter](https://img.shields.io/badge/Flutter-stable-blue)
![License](https://img.shields.io/badge/license-<LICENSE>-green)

> One-line pitch: what the app does and for whom.

<A short paragraph: the problem it solves and the core value. 2–4 sentences.>

## Features

- <Feature one>
- <Feature two>
- <Feature three>

## Screenshots

<!-- Drop phone screenshots here — light and dark. -->

| Light | Dark |
|---|---|
| <img src="docs/screenshots/home_light.png" width="240"/> | <img src="docs/screenshots/home_dark.png" width="240"/> |

## Getting started

### Prerequisites

- **Flutter** `<X.Y.Z>` (stable channel) · **Dart** `<3.x>` — pinned in `.tool-versions` / `fvm`. Run `flutter --version` to check.
- Android SDK (minSdk 23 / Android 6) · a device or emulator.
- `<other tooling, e.g. a configured backend / .env file>`

### Setup

```bash
git clone https://github.com/<org>/<repo>.git
cd <repo>
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # freezed / json / riverpod codegen
```

### Run

```bash
flutter run                       # default flavor
flutter run --flavor dev   -t lib/main_dev.dart
flutter run --flavor staging -t lib/main_staging.dart
flutter run --flavor prod  -t lib/main_prod.dart
```

## Project structure

```
lib/
├── main.dart        # bootstrap (ProviderScope + error hooks)
├── app/             # MaterialApp.router, theme, router
├── core/            # errors, network, shared widgets
└── features/        # feature-first modules (data/domain/application/presentation)
```

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the layer model and data flow, and [`docs/adr/`](docs/adr/) for why key decisions were made.

## Testing

```bash
flutter analyze                                   # zero warnings (very_good_analysis)
flutter test                                      # unit + widget
flutter test --update-goldens                     # refresh golden files
flutter test --coverage                           # writes coverage/lcov.info
```

## Build & release

- **API docs:** `dart doc .` → `doc/api/`.
- **CI/CD & signing:** see the pipeline in `.github/workflows/` (skill 21_CICD).
- **Store deployment & tracks:** see the deployment runbook (skill 22_Deployment).

## License

Distributed under the <LICENSE> license. See [`LICENSE`](LICENSE).
