---
name: Compliance_SBOM
description: Resolve transitive licenses — flag GPL/AGPL risk, generate NOTICE + CycloneDX SBOM, gate release
when_to_use: before any release candidate build (stage 24), after pubspec.yaml dependency changes, or when legal review is requested
---

# 58 — Compliance: SBOM & License Gate

**Exit gate:** NO GPL/AGPL in transitive tree without legal review; SBOM current; NOTICE file complete.

Links: [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md) — Dart 3, Riverpod 2.x, freezed, go_router, Material 3 conventions apply to all generated artifacts.
Pipeline reference: [`../../references/PIPELINE.md`](../../references/PIPELINE.md) stage 24 (Production_Readiness).

---

## 1. License Classification

Every dependency (direct + transitive) is classified into one of five categories:

| Category | Examples | Action |
|---|---|---|
| **Permissive** | MIT, BSD-2/3, Apache-2.0, ISC, Unlicense | Proceed — no review needed |
| **Copyleft-Weak** | MPL-2.0, LGPL-2.1/3.0, EPL-2.0, CDDL-1.1 | Proceed — note in SBOM, verify library linkage (LGPL requires dynamic linking) |
| **Copyleft-Strong** | GPL-2.0, GPL-3.0, AGPL-3.0 | **BLOCK** — legal review mandatory before any distribution |
| **Proprietary** | Commercial, EULA, source-available non-OSS | Proceed only if license terms permit redistribution |
| **Unknown** | No SPDX identifier, missing LICENSE file | **BLOCK** — manual resolution required before release |

Only SPDX identifiers (`dart pub deps` output) are trusted for automated classification. Heuristic parsing of LICENSE file text is a fallback and must be flagged as `low-confidence` in the SBOM.

---

## 2. GPL / AGPL Risk Flagging

### What it blocks
- **Distribution** (store release, APK to external testers, enterprise MDM deployment) is blocked entirely until legal review signs off.
- **Internal development** builds may proceed with GPL/AGPL deps present, but the dependency list must be tagged `INTERNAL-ONLY — DO NOT DISTRIBUTE` in CI artifacts.

### What is OK
- AGPL for server-side code that the app never links against (build-tool-only deps) is acceptable after confirming no linkage.
- GPL in `dev_dependencies` (test frameworks, linters) does not trigger the gate if the dep is never shipped in the release APK — confirm via `pubspec.yaml` scope.
- LGPL with dynamic linking (Android `.so` via FFI) is acceptable under weak-copyleft rules.

### Verification procedure
1. Extract full transitive tree: `flutter pub deps --json`
2. Cross-reference each package name + version against its LICENSE file in the pub cache.
3. Flag every non-permissive hit in a review artifact.
4. If any GPL/AGPL hit exists, open a legal-review ticket with the full list and block the release pipeline.

---

## 3. CycloneDX SBOM Generation

### Command

```bash
flutter pub deps --json > deps.json
python3 scripts/generate_sbom.py deps.json --output sbom.xml --format cyclonedx-1.5
```

### generate_sbom.py requirements
- Parses `dart pub deps --json` output.
- Resolves each package's SPDX license identifier (read from pub.dev metadata or local LICENSE file).
- Emits CycloneDX 1.5 XML (or JSON with `--format cyclonedx-1.5-json`).
- Includes: `component` entries for every package, `name`, `version`, `purl` (pkg:dart/…), `licenses` block.
- Metadata block contains: timestamp, tool name (`sbom-generator`), project name from `pubspec.yaml`.

### Validation
```bash
cyclonedx-cli validate --input-file sbom.xml --input-format xml
```

The SBOM must pass CycloneDX schema validation before the CI gate allows progression past stage 24.

---

## 4. NOTICE File Template

Every release artifact MUST include a `NOTICE` file in the APK assets and repository root. Template:

```
[Project Name]
Copyright (c) [Year] [Copyright Holder]

This product includes software developed by third parties.
See below for full license texts and attribution.

===============================================================================
[Package Name] ([version]) — [SPDX Identifier]
Copyright (c) [Year] [Author]
License text: [full text or URL to license]

---
[Repeat for each dependency, ordered alphabetically by package name]
===============================================================================
```

### Required sections
- Project copyright statement (top).
- One entry per non-proprietary dependency with: package name, version, SPDX identifier, copyright line, and full license text (or link to canonical source).
- Proprietary dependencies: list name and version only, with note "License terms on file with legal team."

### Automation
The same `generate_sbom.py` script should produce a `NOTICE.md` alongside the SBOM. A CI diff-checker compares the generated NOTICE against the committed version and fails if they diverge.

---

## 5. CI Integration

### Stage 24 gate (Production_Readiness)

Runs as part of the stage 24 checklist in [`../../references/PIPELINE.md`](../../references/PIPELINE.md):

```yaml
# .github/workflows/sbom-check.yml (excerpt)
jobs:
  sbom-gate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'
      - run: flutter pub get
      - run: flutter pub deps --json > deps.json
      - run: python3 scripts/generate_sbom.py deps.json --output sbom.xml --format cyclonedx-1.5
      - run: cyclonedx-cli validate --input-file sbom.xml --input-format xml
      - name: License gate
        run: python3 scripts/check_licenses.py deps.json --policy templates/license_policy.yaml
      - name: NOTICE diff
        run: |
          python3 scripts/generate_sbom.py deps.json --notice NOTICE.generated.md
          diff -u NOTICE.md NOTICE.generated.md || (echo "NOTICE file out of date — regenerate and commit" && exit 1)
```

The gate blocks the release if:
- Any dependency has an unknown license.
- Any GPL/AGPL dependency exists without an approved legal-review issue reference in the commit message.
- SBOM fails CycloneDX validation.
- NOTICE file is out of date.

---

## 6. Policy Tiers

| Tier | Trigger | Copyleft-Strong Allowed? | Unknown License Allowed? | NOTICE Required? |
|---|---|---|---|---|
| **Internal Dev** | Every CI run on feature branches | Yes — flag only | Yes — flag only | No |
| **Distribution** | Beta/RC builds, APK to testers | No — block | No — block | Yes |
| **Store Release** | Production APK/AAB upload | No — block | No — block | Yes — verified current |

The tier is selected by CI context (branch name pattern + build trigger). Internal dev runs on `feature/*` and `fix/*` branches. Distribution runs on `release/*` and `beta/*`. Store release runs on `main` with a semver tag.

---

## 7. Review & Approval

For any copyleft-strong hit that reaches legal review:
1. Developer files a ticket with: package name, version, license, usage description (where in the codebase it is called), and linking type (static vs dynamic).
2. Legal team approves or rejects with conditions.
3. Approval reference (ticket URL) is recorded in `legal_reviews.json` at the repo root.
4. CI gate reads `legal_reviews.json` — only packages listed with an approved status pass.

---

## Outputs (per run)

| Artifact | Path | Notes |
|---|---|---|
| SBOM (CycloneDX) | `build/sbom.xml` | CycloneDX 1.5 XML |
| SBOM (JSON) | `build/sbom.json` | Optional, for tooling consumption |
| NOTICE file | `NOTICE.md` | Committed to repo root |
| License report | `build/license_report.txt` | Human-readable summary |
| Legal review manifest | `legal_reviews.json` | Persisted across runs |

---

## Related Skills

- `01_Master_Orchestrator` — triggers stage 24 gate.
- `55_Security_Audit` — security review runs before SBOM gate in stage 24.
- `56_Accessibility` — accessibility audit also runs in stage 24.
