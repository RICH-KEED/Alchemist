# STRIDE Threat Model — [App Name] v[Version]

**Date:** [YYYY-MM-DD]
**Author:** [Name / Role]
**Reviewers:** [Names]
**Status:** Draft / In Review / Final

---

## 1. Data Flow Diagram (Text-Based)

```
[User] ──(1)──▶ [App Client] ──(2)──▶ [API Gateway] ──(3)──▶ [Backend Services]
                     │                                         │
                     │ (4)                                     │ (5)
                     ▼                                         ▼
              [Local Storage]                           [Database / Cache]
                     │
                     │ (6)
                     ▼
              [Third-Party SDKs]
```

List all flows crossing trust boundaries:

| # | Flow Name | Source | Destination | Protocol | Data | Trust Boundary |
|---|---|---|---|---|---|---|
| 1 | User Login | User | App Client | UI input | Credentials, OTP | User → App |
| 2 | API Requests | App Client | API Gateway | HTTPS/REST | JWT, request body | Client → Server |
| 3 | API Gateway → Backend | API Gateway | Backend Services | Internal HTTPS/gRPC | JWT, payload | Gateway → Internal |
| 4 | Local Persistence | App Client | Local Storage | Keystore/SQLite/File | Tokens, PII, cache | App → OS |
| 5 | Backend → DB | Backend Services | Database | SQL over TLS | User data, secrets | Service → Data |
| 6 | Third-Party Data | App Client | Third-Party SDKs | HTTPS | Analytics, crash logs | App → External |

*(Add/remove flows to match your architecture.)*

---

## 2. STRIDE Table

**Legend:** X = Threat present (describe vector) — = Not applicable

| # | Flow | S (Spoofing) | T (Tampering) | R (Repudiation) | I (Info Disclosure) | D (DoS) | E (Elevation) | Risk |
|---|---|---|---|---|---|---|---|---|
| 1 | User Login | X — phishing / fake login UI | X — credential tamper via MITM | — | X — shoulder-surfing, keylogger | X — brute-force lockout bypass | — | **High** |
| 2 | API Requests | X — DNS spoof, fake API | X — request tamper via proxy | X — no request signing | X — log leakage, proxy sniff | X — retry storm, rate-limit bypass | — | **High** |
| 3 | Gateway → Backend | — (internal mTLS) | — (internal mTLS) | X — no per-request audit ID | — | X — resource exhaustion | X — compromised gateway pivots to backend | **Medium** |
| 4 | Local Persistence | — | X — rooted device reads DB directly | — | X — backup exposure, clipboard | X — storage exhaustion | X — root-access DB manipulation | **High** |
| 5 | Backend → DB | — | X — SQL injection via unvalidated input | X — no DB audit log | X — unencrypted DB backups | X — connection pool exhaustion | X — privileged DB credential theft | **Medium** |
| 6 | Third-Party Data | X — SDK impersonation | X — data tamper in transit | — | X — PII leak to analytics | — | — | **Medium** |

---

## 3. Mitigations Table

| # | Flow | Threat | Dimension | Risk | Control (Skill 13) | Implementation Notes |
|---|---|---|---|---|---|---|
| 1 | User Login | Phishing / fake login | S | High | Biometric auth + crypto binding | `local_auth` with `CryptoObject`; no fallback to weak unlock |
| 1 | User Login | Shoulder-surfing, keylogger | I | High | Input sanitization + screen shield | `FLAG_SECURE` on sensitive screens; clear fields on background |
| 2 | API Requests | DNS spoof, MITM | S/T | High | Certificate pinning | Pin against known CA; rotate pins via app update |
| 2 | API Requests | Log leakage, proxy sniff | I | High | No-sensitive-data-in-logs | Strip tokens/PII from `debugPrint`; disable verbose logs in release |
| 2 | API Requests | Retry storm, rate-limit bypass | D | Medium | Exponential backoff + jitter | `RetryPolicy` with `maxRetries=3`, `backoffFactor=2.0` |
| 3 | Gateway → Backend | No per-request audit ID | R | Medium | Audit logging | Inject correlation-ID at gateway; log all backend requests |
| 4 | Local Persistence | Rooted device reads DB | T/E | High | Keystore-backed storage + root detection | `flutter_secure_storage`; SafetyNet/Play Integrity check |
| 4 | Local Persistence | Backup exposure | I | Medium | Disable auto-backup | `android:allowBackup="false"` for sensitive files; encrypt backups |
| 5 | Backend → DB | SQL injection | T | Medium | Parameterized queries + input validation | Use ORM with bound params; validate all server-side input |
| 6 | Third-Party Data | PII leak to analytics | I | Medium | Data minimisation + audit SDK data sharing | Configure analytics SDK to strip PII; review SDK privacy docs |

---

## 4. DREAD Scoring (Formal Reviews — Optional)

| Threat | D (1-10) | R (1-10) | E (1-10) | A (1-10) | D (1-10) | Total (5-50) |
|---|---|---|---|---|---|---|
| *e.g., Token theft from local storage* | 8 | 7 | 5 | 9 | 4 | 33 |

Scoring guide:
- **Damage:** 1=none, 10=complete system compromise
- **Reproducibility:** 1=theoretical, 10=trivially reproducible
- **Exploitability:** 1=expert + custom tools, 10=script-kiddie level
- **Affected Users:** 1=single user, 10=all users
- **Discoverability:** 1=obscure, 10=documented in public

---

## 5. Open Items

| # | Item | Owner | Due | Status |
|---|---|---|---|---|
| 1 | Confirm backend supports certificate pinning key rotation | Backend Lead | [date] | Open |
| 2 | Audit all third-party SDK data sharing | Security Lead | [date] | Open |
| 3 | Verify Play Integrity API quota for user base | Android Lead | [date] | Open |
| 4 | Penetration test findings from external firm | Security Lead | [date] | Blocked |
