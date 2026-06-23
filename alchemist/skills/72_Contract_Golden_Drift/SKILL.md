---
name: Contract Golden Drift
description: Detect when backend responses drift from pinned contracts (OpenAPI) or golden snapshots — classify whether goldens need a legitimate update or signal a real regression. Use when a backend changes, API tests suddenly fail, or you need to audit live responses against the pinned spec.
when_to_use: Trigger on "check for drift", "did the API change", "compare live responses to goldens", "audit the contract", "update golden snapshots", "are these test failures real regressions", "validate against OpenAPI spec", or when CI contract-check job fails. For the pinned spec itself and generating DTOs see skill 49; for the API test suite machinery see skill 12; for the dio client and repositories under test see skill 11.
---

# Contract Golden Drift (Stage 72 — Quality guard)

Every contract divergence is classified as intentional update or unintentional regression; regressions flagged to team.

You sit between the pinned OpenAPI spec (skill 49), the API test suite (skill 12), and the live backend (skill 11). Your job: compare what the backend *actually* returns against what the spec and golden snapshots *expect*, then classify every diff so the team acts with precision — never ignores a regression, never wastes time on a benign schema expansion.

Single source of truth for stack and layout: [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md). When this skill and CONVENTIONS disagree, **CONVENTIONS wins.**

**Exit gate:** every contract divergence is classified as intentional update or unintentional regression; regressions flagged to team.

---

## Contract pinning

Contracts live in `.flutter-pipeline/contracts/` at the project root. This is the canonical home for everything the backend promises:

```
.flutter-pipeline/contracts/
├── openapi.yaml           # OpenAPI 3.x spec (the pinned contract)
├── openapi.json           # alternative: JSON format
└── versions/
    ├── v1.0.0.yaml        # tagged snapshot per API version
    └── v1.1.0.yaml
```

How to pin a contract:

1. **Generate from backend** — if the backend team ships an OpenAPI spec, copy it to `.flutter-pipeline/contracts/openapi.yaml` and commit it. This is the preferred path: the spec is the source of truth.
2. **Pin manually** — if no spec exists, craft a minimal OpenAPI 3.x document describing the endpoints, request/response schemas, and error codes the app depends on. Keep it focused on what the Flutter app actually consumes.
3. **Version-tag** — when the backend publishes a new API version, copy the current contract into `versions/` tagged with the version number before updating the main spec. This preserves the audit trail.

Contracts must be committed to the repo. They drive: DTO generation (skill 49), API test fixtures (skill 12), and the drift check you perform here.

---

## Golden snapshot storage

Per-endpoint golden responses live as JSON files under `test/goldens/`, mirroring the API test fixture layout:

```
test/
├── goldens/
│   ├── articles/
│   │   ├── get_articles_list.json    # GET /articles
│   │   └── get_article_by_id.json    # GET /articles/:id
│   └── auth/
│       └── get_profile.json          # GET /profile
└── fixtures/                         # skill 12 test fixtures
```

A golden is a **frozen real response** captured from the live backend at a known-good point in time. Unlike test fixtures (which may be simplified), goldens are verbatim: every field, every nesting level, every value. They are the reference for drift detection.

Capture a golden: hit the live endpoint, scrub secrets (tokens, PII), pretty-print the JSON, and save it. Re-capture when the team confirms a deliberate backend change.

---

## Drift detection workflow

Run the drift check as a discrete step, typically in CI or before a release:

1. **Select contracts.** Choose one or more pinned contracts from `.flutter-pipeline/contracts/` and the corresponding goldens from `test/goldens/`.
2. **Fetch live responses.** Hit each endpoint defined in the contract with valid auth (use a test account or CI credentials). Use the same request shape the app uses.
3. **Compare structurally.** Diff live response JSON against the golden, field by field. Ignore purely cosmetic differences (whitespace, key ordering) — compare semantics.
4. **Classify each diff.** Apply the classification rules below. Every diff gets a severity and a recommended action.
5. **Emit a drift report.** Fill [`templates/drift_report.md`](templates/drift_report.md) with the summary, diff table, and actions.
6. **Block or warn.** Breaking changes block CI; non-breaking changes warn; unknowns require human review.

---

## Diff classification

Classify every difference between the live response and the golden using this table:

| Change type | Classification | Severity | Action |
|---|---|---|---|
| Required field removed from response | BREAKING regression | Critical | File backend bug; block release |
| Field type changed (string→int, object→array, etc.) | BREAKING regression | Critical | File backend bug; block release |
| New required field added without default | BREAKING regression | High | File backend bug or add default handling |
| Existing field renamed | BREAKING regression | High | File backend bug; confirm not a migration |
| Value changed within same schema (same type, different content) | Possibly intentional | Medium | Investigate — backend logic change? If confirmed, update golden |
| New optional field added | Backward-compatible | Low | Update golden; regenerate DTOs (skill 49) |
| Enum value added (no existing values removed) | Backward-compatible | Low | Update golden; regenerate DTOs (skill 49) |
| Enum value removed | BREAKING regression | High | File backend bug; existing clients may break |
| Field order differs (same fields, same types) | Cosmetic | None | Ignore; JSON key order is not semantic |
| Nullable field now always non-null, or vice versa | Possibly intentional | Medium | Investigate backend intent; if deliberate, update golden |
| New endpoint added | Backward-compatible | None | No action on existing goldens; add new golden if app consumes it |
| Endpoint removed (app depends on it) | BREAKING regression | Critical | File backend bug; block release |
| Response status code changed (200→201, 200→404) | BREAKING regression | Critical | File backend bug; block release |
| Header removed that app depends on (pagination, rate-limit) | BREAKING regression | High | File backend bug; confirm intent |

When in doubt between "possibly intentional" and "regression," treat it as a regression until the backend team confirms otherwise. False-positive drift alerts are cheaper than silent data corruption.

---

## Drift report generation

Output a drift report using the template at [`templates/drift_report.md`](templates/drift_report.md). The report captures:

- **Contract under test** — endpoint path, API version, date the golden was pinned, date of the drift check.
- **Drift summary** — counts: breaking (N), non-breaking (N), unknown (N). A single breaking diff means the gate is blocked.
- **Detailed diff table** — one row per changed field: field path (JSONPath), expected golden value, actual live value, classification, and recommended action.
- **Actions section** — grouped by action type: Update golden / File backend bug / Investigate / Accept change.
- **Metadata** — timestamp, reviewer name, resolution (if already decided).

Generate the report as a Markdown file under `.flutter-pipeline/contracts/reports/` with a timestamped filename (e.g., `drift_2026-06-23T14_30_00.md`).

---

## Deep-diff comparison (beyond field-names)

A structural diff catches field additions/removals and type changes, but real drift is often subtler. Run these additional checks:

**Value constraints.** Compare constraint metadata from the OpenAPI spec against live values:
- `minLength`/`maxLength` on strings — does the live response violate declared bounds?
- `minimum`/`maximum` on numbers — has a new value exceeded the spec?
- `enum` membership — is a live value outside the declared enum?

**Array element counts.** If the spec declares a `minItems`/`maxItems`, verify the live array length falls within bounds. A single-element array that used to hold 20 items signals a backend query regression.

**Nullable drift.** Track whether a field that was always non-null in N consecutive golden snapshots suddenly returns null. A single null sample is a warning; consistent nulls are a regression.

**Timing changes.** If response time doubles between checks, flag it even if the payload is identical. A backend that got slower without a payload change may have a degraded query or missing index.

**Header contracts.** Verify pagination headers (`Link`, `X-Total-Count`, `X-Page`), rate-limit headers (`X-RateLimit-Remaining`), and content-type (`application/json`) match expectations. A missing pagination header causes infinite-loading bugs in the app.

---

## Tooling

The comparison itself can run in several modes:

1. **Scripted diff (preferred).** Use a Dart script under `tool/` that reads the goldens, fetches live responses via `dio`, and produces a structured diff. This reuses the project's own networking stack and `Failure` mapping — the same code that hits the backend in production.
2. **`deepdiff` / `jd` CLI.** For ad-hoc checks during development, pipe golden and live JSON through a semantic JSON diff tool. The `jd` tool (`jd golden.json live.json`) prints a compact JSON patch suitable for human review.
3. **CI artifact.** In CI (skill 21), the drift-check job runs the Dart script, writes a drift report artifact, and surfaces a summary comment. The script exits non-zero on breaking regressions.

---

## CI integration

Wire drift checks into CI (skill 21) with these triggers:

| Trigger | Behavior |
|---|---|
| `contracts/` or `test/goldens/` change in a PR | Run drift check against affected endpoints; fail PR on breaking diffs |
| Scheduled (nightly) | Full drift check against all pinned endpoints; open an issue on regressions, notify on unknowns |
| Pre-release tag | Full drift check; block release if any breaking regression is unaddressed |

The CI job:
1. Checks out the pinned contract and goldens.
2. Fetches live responses from the staging or production backend (using CI secrets for auth).
3. Runs the comparison and classification logic.
4. Emits a drift report artifact and posts a summary comment on the PR or issue.

---

## Version pinning strategy

Tag golden sets with the backend API version so you can cross-reference:

- Each API version (`v1`, `v2`) gets its own golden directory: `test/goldens/v1/`, `test/goldens/v2/`.
- The active version's goldens live at `test/goldens/` (no version prefix) for convenience; CI checks both the active version and the previous version to detect accidental breakage during migrations.
- When the app upgrades to a new API version, archive the old goldens into `test/goldens/archive/v1/` and populate new goldens from the new live responses after the team confirms they are correct.
- Never delete old goldens — archive them. They are the only proof of what the contract used to be.

---

## Resolution tracking

Every drift report must reach a resolution. Track outcomes so the team builds institutional knowledge about which backends drift and why:

- **Resolved — backend fixed.** The backend team acknowledged a regression and deployed a fix. Re-run the drift check to confirm; if green, close the report. Do not update goldens unless the fix intentionally changed behavior.
- **Resolved — golden updated.** The change was intentional and backward-compatible. Update goldens, regenerate DTOs (skill 49), update test fixtures (skill 12), and close the report.
- **Resolved — accepted.** The change was confirmed intentional even though it was breaking (e.g., a deprecated field removed on schedule). Update goldens and notify the mobile team to adapt consuming code.
- **Superseded.** A newer drift report covers the same endpoints. Link to the superseding report and close.
- **Stale.** The report is older than 30 days without resolution. Escalate to the engineering lead.

Store resolutions in the report file itself (update the `Resolution` field in the metadata table) and in a summary index at `.flutter-pipeline/contracts/reports/INDEX.md` that lists every report with its status.

---

## Workflow

1. Confirm `.flutter-pipeline/contracts/` exists with a pinned OpenAPI spec and `test/goldens/` has endpoint goldens. If not, pin the contract first (skill 49) and capture goldens from known-good responses.
2. Run the comparison: fetch live responses, diff against goldens, classify every delta.
3. If breaking regressions are found, block and notify the backend team immediately. Do not update goldens.
4. If only backward-compatible changes are found, update goldens, regenerate DTOs (skill 49), and note the change in the drift report.
5. Archive the report under `.flutter-pipeline/contracts/reports/`.
6. If this runs in CI, post the summary to the PR or create an issue.

---

## References

- **Skill 11 (Backend_Integration)** — the dio client, data sources, and repositories that call these endpoints.
- **Skill 12 (API_Testing)** — the mock-based test suite whose fixtures should mirror the goldens; a fixture change and a golden change should happen together.
- **Skill 49 (OpenAPI_Dart_Generator)** — generates DTOs from the pinned spec; regen after confirmed golden updates.
- **Skill 21 (CICD)** — where the drift-check job is configured and wired into PR/schedule/release triggers.
- **Skill 15 (Error_Handling)** — the `Failure`/`Result` types; a backend status-code change may need a new `Failure` subtype and mapper branch.
- [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md) — house style, stack, and project layout.
- [`../../references/PIPELINE.md`](../../references/PIPELINE.md) — stage 72 sits in Phase D (quality), gating on "contracts pinned and verified."
