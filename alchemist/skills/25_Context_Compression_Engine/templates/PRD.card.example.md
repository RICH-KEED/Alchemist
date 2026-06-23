---
card: PRD
source: docs/PRD.md
hash: sha256:3f9a7c0e21bb4d5f88a1c2e9d7460af31c5b9e02aa14d6f7c8b3902e1d4f0c1
stage: 02_Product_Planning
tokens_full: 3200
tokens_card: 820
compressed_at: 2026-06-23
schema: 1
---

# PRD card — FieldNotes (offline-first field inspection app)

> Example card. Compresses a ~3,200-token PRD to ~820 tokens (~74% smaller). Acceptance
> criteria, metrics, and constraints are kept verbatim; rationale and persona narrative dropped.

## Purpose
Product requirements for an Android-first app that lets field inspectors capture, sync, and
export site inspections offline. Read by UX (03), Architecture (06), Backend (11), Security (13),
Network Resilience (14), Testing (20), and Production Readiness (24).

## Key facts
- Android-first, Material 3; `minSdk 23`; offline-first is a core requirement, not a nice-to-have.
- MVP scope (locked): (1) create/edit inspection, (2) attach photos, (3) offline capture + queued sync,
  (4) export inspection as PDF, (5) auth via email + biometric unlock.
- Out of scope for MVP: multi-user collaboration, real-time updates, web client, custom report builder.
- Primary persona: field inspector on flaky cellular, gloves on, bright sunlight (a11y + large touch targets).
- Data sensitivity: inspections may contain site addresses + photos → treated as confidential (drives Security 13).

## Decisions
- Backend: Supabase (Postgres + storage). — ADR-0003, 2026-06-23.
- Sync model: local-write-first, background queue, last-write-wins per record. — ADR-0004.
- PDF export generated on-device (no server round-trip) for offline use. — ADR-0005.
- Auth: email/password + `flutter_secure_storage` token + biometric gate. — ADR-0006.

## Interfaces / Contracts
Acceptance criteria (verbatim — define "done"):
- AC1: An inspection created offline is persisted locally and visible after app restart with no network.
- AC2: When connectivity returns, queued inspections sync within 30s; conflicts resolve last-write-wins
  and the user sees a sync-status indicator (pending / synced / failed).
- AC3: Any inspection can be exported to a valid PDF that opens in a standard viewer, offline.
- AC4: After 5 min idle the app requires biometric (or PIN fallback) re-auth before showing data.
- AC5: All photo attachments are stored encrypted at rest.

Success metrics (PRD §Metrics, verbatim):
- ≥ 95% of offline-created inspections sync successfully without user retry.
- Median capture-to-saved time < 3s on a mid-range device.
- Crash-free sessions ≥ 99.5% in the first release.

Stage-02 exit gate (PIPELINE.md): "MVP scope + success metrics agreed." → met: scope locked above,
metrics signed off 2026-06-23.

## Open items
- Conflict UX beyond last-write-wins (manual merge) deferred to v2 — confirm acceptable for launch.
- Max attachment size / count per inspection: TBD (owner: PM) — blocks storage sizing in 11.
- PDF template branding not finalized — does not block MVP build, blocks 22 store assets.

## Expand-pointer
source: docs/PRD.md
- Key facts ← §Overview, §Scope, §Constraints (lines ~1–60)
- Decisions ← §Technical Decisions + linked ADRs in docs/adr/ (lines ~120–180)
- Interfaces/Contracts ← §Acceptance Criteria (lines ~190–230), §Success Metrics (lines ~240–260)
- Open items ← §Open Questions (lines ~270–300)
