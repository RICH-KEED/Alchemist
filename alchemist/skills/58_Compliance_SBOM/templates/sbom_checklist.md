# SBOM & License Compliance Checklist

Use this checklist at every release gate (stage 24) and after any `pubspec.yaml` dependency change.

---

## Pre-Flight

- [ ] `flutter pub get` completed with exit code 0
- [ ] `pubspec.yaml` and `pubspec.lock` are committed and pushed
- [ ] No uncommitted changes in `pubspec.lock`

## License Classification

- [ ] Full transitive dependency tree extracted (`flutter pub deps --json`)
- [ ] Every package classified into one of: permissive, copyleft-weak, copyleft-strong, proprietary, unknown
- [ ] Classification uses SPDX identifiers as primary source
- [ ] Packages without SPDX identifiers have LICENSE files manually reviewed
- [ ] Any heuristic classification is tagged `low-confidence`

## Copyleft Risk Flagging

- [ ] All copyleft-weak deps noted in SBOM (MPL, LGPL, EPL, CDDL)
- [ ] LGPL deps verified for dynamic linking (Android FFI `.so` boundary)
- [ ] All copyleft-strong deps flagged (GPL-2.0, GPL-3.0, AGPL-3.0)
- [ ] For distribution/store tiers: zero GPL/AGPL deps present OR legal review approved
- [ ] Legal review ticket references recorded in `legal_reviews.json`

## NOTICE File

- [ ] `NOTICE.md` exists in repository root
- [ ] Project copyright statement is correct and current year
- [ ] Every non-proprietary dependency listed with: name, version, SPDX identifier, copyright, full license text or canonical URL
- [ ] Dependencies ordered alphabetically
- [ ] Proprietary dependencies listed with legal-team note
- [ ] CI NOTICE diff passes (generated matches committed)

## SBOM Generation

- [ ] SBOM generated in CycloneDX 1.5 format (`build/sbom.xml`)
- [ ] SBOM passes `cyclonedx-cli validate`
- [ ] SBOM includes all `component` entries (direct + transitive)
- [ ] Each component has `purl` (pkg:dart/...), `name`, `version`, `licenses`
- [ ] Metadata block contains timestamp and tool name

## CI Gate

- [ ] SBOM workflow runs in CI without errors
- [ ] License-policy script passes for the current tier
- [ ] NOTICE diff checker passes
- [ ] Gate blocks merge/release when any check fails

## Legal Review (if applicable)

- [ ] Legal-review ticket filed for each copyleft-strong dependency
- [ ] Ticket includes: package name, version, license, usage description, linking type
- [ ] Approval recorded in `legal_reviews.json`
- [ ] Approval reference in commit message

## Attribution

- [ ] All open-source attribution requirements met per each license's terms
- [ ] License texts bundled in APK assets where required
- [ ] About/Licenses screen in-app reflects current dependency list
