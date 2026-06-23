# Threat Model Report — [App Name] v[Version]

**Report ID:** TM-[YYYY]-[NNN]
**Date:** [YYYY-MM-DD]
**Classification:** Internal / Confidential
**Author:** [Name / Role]
**Reviewers:** [Names]
**Status:** Draft / Reviewed / Approved

---

## 1. Executive Summary

[2-3 paragraphs summarising scope, methodology, top findings, and overall risk posture.]

- **Scope:** [e.g., v2.3 Android client, backend APIs, auth service, local storage]
- **Methodology:** STRIDE per data flow, ranked by impact x likelihood, mitigated per skill 13 controls
- **Top Risks:** [list 2-3 highest-ranked threats]
- **Overall Posture:** [Low / Medium / High risk — is the app ready for release?]

---

## 2. Scope

| Item | In Scope | Excluded / Notes |
|---|---|---|
| Android client (Flutter) | Yes | — |
| Backend REST APIs | Yes | Admin panel excluded |
| Auth service (OAuth 2.0) | Yes | Third-party IdP excluded |
| Local storage / DB | Yes | — |
| Third-party SDKs | Yes | SDKs vetted by vendor |
| Physical device security | No | Out of scope |

---

## 3. Findings Summary

| ID | Flow | Threat | Dimension | Risk | Mitigation Status |
|---|---|---|---|---|---|
| TM-01 | User Login | Phishing / fake login | Spoofing | High | Mitigated — biometric + crypto binding |
| TM-02 | API Requests | MITM / certificate spoof | Tampering | High | Mitigated — certificate pinning |
| TM-03 | Local Persistence | Token theft on rooted device | Info Disclosure | High | Mitigated — Keystore + root detection |
| TM-04 | API Requests | Retry storm / rate-limit bypass | DoS | Medium | Mitigated — exponential backoff |
| TM-05 | Third-Party Data | PII leak to analytics SDK | Info Disclosure | Medium | Mitigated — PII stripped, SDK audited |
| TM-06 | Gateway → Backend | No audit trail | Repudiation | Medium | Accepted — compensating control: API Gateway logs |
| TM-07 | Deep Links | Parameter injection | Elevation | Low | Deferred — allowlist validation planned v2.4 |

---

## 4. Detailed Findings

### TM-01: Phishing / Fake Login (Spoofing — High)

**Data Flow:** User Login (flow #1)
**Description:** Attacker presents a fake login UI (phishing page or repackaged app) to capture user credentials.
**Impact:** Full account compromise, credential reuse across services.
**Likelihood:** Medium — phishing is common; repackaging requires app-store bypass.
**Mitigation:** Biometric authentication with crypto binding (`local_auth` + `CryptoObject`). No credential fallback; if biometric fails, require full re-authentication via backend-verified OTP.
**Control:** Skill 13 — Biometric Auth.
**Status:** Mitigated.

*(Repeat per finding — expand the top High findings with full detail; High findings may be summarised in 1-2 lines.)*

---

## 5. Mitigation Roadmap

| Phase | Threat IDs | Mitigation | Owner | Target |
|---|---|---|---|---|
| Pre-launch (blocker) | TM-01, TM-02, TM-03 | Biometric auth, cert pinning, Keystore storage | Android Lead | v2.3 GA |
| Post-launch (fast-follow) | TM-04, TM-05 | Backoff policy, SDK PII audit | Android Lead | v2.3.1 |
| Backlog | TM-07 | Deep-link allowlist validation | Android Lead | v2.4 |

---

## 6. Accepted Risks

| ID | Threat | Risk | Rationale | Approver | Date |
|---|---|---|---|---|---|
| TM-06 | Gateway → Backend: No audit trail | Medium | API Gateway access logs provide sufficient audit trail for current threat model. Full per-request audit deferred to backend workstream. | [Name] | [date] |
| *(add rows as needed)* | | | | | |

---

## 7. Review & Sign-Off

| Role | Name | Date | Signature |
|---|---|---|---|
| Security Lead | | | |
| Android Lead | | | |
| Backend Lead | | | |
| Product Owner | | | |

---

**Next Review:** [date or trigger, e.g., "Before v2.4 release" or "After major arch change"]
**Archived:** [path to archive location]
