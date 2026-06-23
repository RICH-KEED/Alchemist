# Drift Report

## Contract under test

| Field | Value |
|---|---|
| Endpoint(s) | `{{ENDPOINT_PATH}}` |
| API version | `{{API_VERSION}}` |
| Pinned date | `{{PINNED_DATE}}` |
| Check date | `{{CHECK_DATE}}` |
| Pinned contract | `.flutter-pipeline/contracts/{{CONTRACT_FILE}}` |
| Golden(s) | `test/goldens/{{GOLDEN_DIR}}/` |

---

## Drift summary

| Severity | Count |
|---|---|
| Breaking | `{{BREAKING_COUNT}}` |
| Non-breaking | `{{NON_BREAKING_COUNT}}` |
| Unknown / needs investigation | `{{UNKNOWN_COUNT}}` |
| Cosmetic (no action) | `{{COSMETIC_COUNT}}` |

**Gate status:** `{{PASSED | BLOCKED | WARNING}}`

---

## Detailed diff

| # | Field path | Expected (golden) | Actual (live) | Classification | Severity | Action |
|---|---|---|---|---|---|---|
| 1 | `{{e.g. $.items[0].price}}` | `{{GOLDEN_VALUE}}` | `{{LIVE_VALUE}}` | `{{e.g. BREAKING regression — type changed}}` | `{{Critical/High/Medium/Low}}` | `{{File backend bug / Update golden / Investigate / Accept}}` |
| 2 | `{{e.g. $.items[0].discount_percent}}` | `(missing)` | `15` | `{{Backward-compatible — new optional field}}` | `Low` | `Update golden; regenerate DTOs` |
| 3 | `{{e.g. $.meta.pagination.next}}` | `"https://..."` | `null` | `{{Possibly intentional — value changed}}` | `Medium` | `Investigate` |

---

## Actions

### Update golden

- [ ] `{{FIELD_PATH}}`: `{{REASON}}` — regenerate DTOs (skill 49) after updating golden
- [ ] ...

### File backend bug

- [ ] `{{FIELD_PATH}}`: `{{REASON}}` — link to backend issue: `{{ISSUE_URL}}`
- [ ] ...

### Investigate

- [ ] `{{FIELD_PATH}}`: `{{REASON}}` — confirm with backend team before acting
- [ ] ...

### Accept change

- [ ] `{{FIELD_PATH}}`: `{{REASON}}` — change is intentional and does not affect client
- [ ] ...

---

## Metadata

| Field | Value |
|---|---|
| Report generated | `{{TIMESTAMP}}` |
| Reviewer | `{{REVIEWER_NAME}}` |
| Resolution | `{{OPEN | RESOLVED — <summary> | SUPERSEDED by <report>}}` |
| Related issues | `{{ISSUE_URLS}}` |
