# Stage Exit-Gate Checklist

A stage advances only when its gate is **objectively** met. Use this as the rubric.

## Universal gates (every stage)
- [ ] `flutter analyze` is clean under `very_good_analysis` (zero warnings)
- [ ] New/changed public APIs have doc comments
- [ ] Artifact written to its path and indexed in STATE.md
- [ ] No `TODO` without a linked issue

## Phase A — Plan & Design
- [ ] 02: PRD has problem, personas, MVP story list (MoSCoW), success metrics
- [ ] 03: every MVP story maps to a screen and a flow; nav map complete
- [ ] 04: design tokens compile; light + dark color schemes defined; component specs exist
- [ ] 05: mockups/preview approved by the user (look & feel sign-off)

## Phase B — Foundation
- [ ] 06: app boots; `lib/` matches CONVENTIONS layout; feature skeleton present
- [ ] 07: every screen in the inventory is reachable; deep links resolve
- [ ] 08: state wired via Riverpod; provider-override tests pass

## Phase C — Build
- [ ] 09: animations run 60fps (checked in profile mode)
- [ ] 10: assets typed via flutter_gen; adaptive icon + splash render
- [ ] 11: endpoints return mapped domain entities via `Result`
- [ ] 12: API tests green against a mock; contracts pinned
- [ ] 13: no secret in plaintext; MASVS-L1 checks pass
- [ ] 14: app degrades gracefully offline; retries are bounded
- [ ] 15: no uncaught errors; every failure has UX + a log entry
- [ ] 16: all four async states on every data surface
- [ ] 17: phone/tablet/foldable + both orientations verified

## Phase D — Quality
- [ ] 18: public APIs documented; ADRs for key decisions
- [ ] 19: PR/issue templates live; commit & branch conventions set
- [ ] 20: coverage gate met; CI test job green

## Phase E — Ship & Operate
- [ ] 21: build + test + sign automated on push/tag
- [ ] 22: internal-track release succeeds
- [ ] 23: crashes + events visible in dashboard
- [ ] 24: all gates 02–23 green; store compliance + privacy complete
