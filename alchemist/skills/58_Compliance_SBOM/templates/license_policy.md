# License Policy

This document defines the allowed license categories, review processes, and approval chains for third-party dependencies. It applies to all tiers: internal dev, distribution, and store release.

---

## 1. Definitions

| Term | Definition |
|---|---|
| **Permissive** | Licenses that allow use, modification, and redistribution with minimal conditions (attribution, notice preservation). No copyleft trigger. |
| **Copyleft-Weak** | Licenses that require modified versions of the library itself to be shared under the same license, but do not extend to the larger work (file-level or library-level scope). |
| **Copyleft-Strong** | Licenses that require the entire combined/derivative work to be distributed under the same license (project-level scope). |
| **Proprietary** | Commercial or closed-source licenses with explicit terms. |
| **Unknown** | No SPDX identifier found; no recognizable LICENSE file in the package. |

## 2. Allowed Categories by Tier

### Internal Dev (`feature/*`, `fix/*`)
| Category | Allowed | Notes |
|---|---|---|
| Permissive | Yes | No review |
| Copyleft-Weak | Yes | Flag in CI output |
| Copyleft-Strong | Yes | Flag in CI output; artifact tagged `INTERNAL-ONLY` |
| Proprietary | Conditional | Only if build does not redistribute |
| Unknown | Yes | Flag for investigation |

### Distribution (`release/*`, `beta/*`)
| Category | Allowed | Notes |
|---|---|---|
| Permissive | Yes | No review |
| Copyleft-Weak | Yes | Record in SBOM; LGPL must be dynamically linked |
| Copyleft-Strong | No | Legal review mandatory; blocked until approved |
| Proprietary | Conditional | Must have redistribution rights on file |
| Unknown | No | Must be resolved before distribution |

### Store Release (`main` + semver tag)
| Category | Allowed | Notes |
|---|---|---|
| Permissive | Yes | No review |
| Copyleft-Weak | Yes | Full attribution in NOTICE; LGPL dynamic link verified |
| Copyleft-Strong | No | No exceptions without legal sign-off |
| Proprietary | Conditional | Redistribution terms verified by legal |
| Unknown | No | Blocked |

## 3. Review Process for Flagged Dependencies

1. **Identification:** CI script (`check_licenses.py`) flags any dependency matching the blocked category for the current tier.
2. **Ticket creation:** Developer opens a legal-review issue in the project tracker. Required fields:
   - Package name and version
   - SPDX license identifier
   - Usage description (which modules call it, how it is linked)
   - Linking type (static, dynamic, or interpreted)
   - Proposed mitigation (replace, isolate behind interface, seek approval)
3. **Legal review:** Designated legal contact reviews within SLA (target: 5 business days for distribution, 10 for store release).
4. **Approval or rejection:** Outcome recorded in `legal_reviews.json`. Approved packages include any conditions (e.g., attribution language, notice placement).
5. **CI gate update:** The gate reads `legal_reviews.json`; only packages with `status: approved` pass.

## 4. Approval Chains

| Tier | Approval Required | Authority |
|---|---|---|
| Internal Dev | None | Developer self-service |
| Distribution | Copyleft-Strong + Proprietary | Engineering lead + legal |
| Store Release | Copyleft-Strong + Proprietary + Unknown | Engineering lead + legal + release manager |

## 5. Emergency Exceptions

In time-critical situations (security patch, hotfix), the engineering lead may grant a temporary 72-hour waiver. A retroactive legal review must be filed within that window. The waiver is recorded in `legal_reviews.json` with `status: temporary-waiver` and an expiration timestamp. CI gate allows temporary waivers but logs a warning.

## 6. Policy Updates

This policy is reviewed quarterly. Changes require sign-off from engineering lead and legal. Historical policy versions are preserved in git history.
