---
name: 60_Threat_Modeling
description: STRIDE over app data flows — ranked threats + mitigations mapping to skill 13
when_to_use: When security review is needed — new feature, architecture change, pre-release audit, or threat-landscape update
---

# 60 — Threat Modeling

**Exit gate:** every data flow has STRIDE threats enumerated; top threats have mitigations mapped to skill-13 controls; report filed.

Threat modeling applies STRIDE (Spoofing, Tampering, Repudiation, Info Disclosure, Denial of Service, Elevation of Privilege) to every data flow crossing trust boundaries in the Flutter/Android application. Outputs feed directly into **skill 13 (Security)** which provides the actual control implementations (Keystore, certificate pinning, biometric auth, etc.). This skill is defensive posture — find the cracks before adversaries do.

## Data Flow Inventory

Before STRIDE, enumerate every flow where data crosses a trust boundary. Walk through the app architecture (PRD + UX spec) and list:

| Flow Category | Examples |
|---|---|
| **Auth tokens** | JWT/refresh token issuance, storage, refresh cycle, logout invalidation |
| **API traffic** | REST/GraphQL requests, WebSocket streams, file uploads/downloads — both cleartext and TLS |
| **Local storage** | SharedPreferences, SQLite/Drift, Hive/Isar, secure storage (Keystore-backed), file system cache |
| **Deep links** | Custom URL scheme handlers, universal/verified app links, intent filters, redirect chains |
| **IPC / Intents** | Android intents (explicit + implicit), ContentProvider exposure, BroadcastReceiver registration |
| **WebView / In-app browser** | JavaScript bridges, custom headers, cookie injection, navigation interception |
| **Clipboard** | Copied sensitive text (tokens, passwords, PII), paste interception by other apps |
| **Background services** | WorkManager jobs, foreground services, push notification payloads, data sync workers |
| **Biometric / PIN flows** | Biometric prompt, fallback to device credential, crypto object binding |
| **Third-party SDK data** | Analytics, crash reporting, ad networks — what data they receive and transmit |

## STRIDE Per Flow

For each enumerated flow, assess all six STRIDE dimensions:

| Dimension | Guiding Question |
|---|---|
| **S**poofing | Can an attacker impersonate a user, service, or component? (fake auth, DNS spoof, repackaged app) |
| **T**ampering | Can data be modified in transit, at rest, or during processing? (MITM, SQL injection, intent tampering) |
| **R**epudiation | Can a user deny an action without audit trail? (missing logs, unsigned transactions, untraceable deletions) |
| **I**nfo Disclosure | Can data leak to unauthorized parties? (log leakage, screen capture, backup exposure, clipboard sniffing) |
| **D**enial of Service | Can the app or backend be made unavailable? (resource exhaustion, deep-link bombs, infinite retry loops) |
| **E**levation of Privilege | Can an attacker gain higher privileges? (intent redirection, deeplink-to-rce, WebView JS bridge abuse) |

Apply the STRIDE table from the template (`templates/stride_model_template.md`) — one row per flow, mark each threat as present (X) or not applicable (—) with a brief note on the exploitation vector.

## Threat Ranking

Rank threats by risk level. Use a simplified High / Medium / Low scale based on **impact x likelihood**:

- **High:** Likely exploitable + severe impact (credential theft, data exfiltration, remote code execution). Must mitigate before release.
- **Medium:** Possible exploit + moderate impact (limited data leak, DoS with workaround). Mitigate in next iteration or apply compensating controls.
- **Low:** Unlikely or low impact (theoretical, requires physical device access). Accept or defer.

For formal reviews, apply DREAD (Damage, Reproducibility, Exploitability, Affected Users, Discoverability) with scores 1-10 per axis, summing to a 5-50 risk score.

## Mitigation Mapping

Each identified threat maps to a specific control from **skill 13 (Security)**. This table shows common mappings:

| Threat Pattern | Control (Skill 13) | Notes |
|---|---|---|
| Cleartext API traffic | Certificate pinning | Pin against known CA or leaf cert; rotate pins in-app |
| Token theft from storage | Keystore-backed secure storage | `flutter_secure_storage` on Android; encrypt with device-bound key |
| Repackaged app | Code obfuscation + root detection | R8/ProGuard, `flutter_obfuscate`, SafetyNet/Play Integrity |
| Biometric bypass | Biometric + crypto binding | `local_auth` with `CryptoObject` — no fallback to weak unlock |
| Deep link injection | Input validation + allowlist | Validate all deep-link params against schema; no data-bearing GET params |
| Clipboard leak | Clear clipboard after timeout | `Clipboard.setData` with auto-clear; disable for sensitive fields |
| Log leakage | No-sensitive-data-in-logs rule | Strip tokens, PII from `debugPrint`; strip in release builds |
| WebView JS bridge abuse | Disable JS unless needed; validate bridge messages | `javascriptMode: JavascriptMode.disabled`; message schema check |
| Intent spoofing | Explicit intents only for internal comms | Never use implicit intents for sensitive actions; signature-level permissions |
| Backup exposure | Disable auto-backup for sensitive data | `android:allowBackup="false"` or exclude files; encrypt backups |

## How To Run

1. **Read inputs:** PRD (skill 02), UX spec (skill 03), architecture decisions, API contracts.
2. **Trace data flows:** Walk user journeys end-to-end — login, data sync, payment, logout, deep-link navigation. Draw a text-based DFD in the template.
3. **Fill STRIDE table:** One flow per row, mark each dimension. Document exploitation vectors.
4. **Rank threats:** Apply High/Medium/Low (or DREAD scores for formal reviews).
5. **Map mitigations:** Each High/Medium threat gets a control from skill 13 with implementation notes.
6. **File report:** Generate the threat report from the template (`templates/threat_report.md`).
7. **Review with team:** Security lead, Android lead, backend lead review findings. Sign off on accepted risks.

## Relationships

- **Skill 13 (Security):** Consumer of threat mitigations — each mitigation turns into a security control task.
- **Skill 58 (SBOM):** License and dependency risks feed threat model (known-vulnerable dependencies are threats).
- **Skill 61 (Secrets Scan):** Scanned secrets findings feed threat model (hardcoded secrets = Info Disclosure / Elevation risks).
- **Skill 01 (Master Orchestrator):** Threat model is a gating input for the Security phase in the pipeline.

## Pipeline Position

In the 24-stage pipeline (see `../../references/PIPELINE.md`), threat modeling executes at stage 16-17 (Security Architecture Review), producing the threat catalogue that skill 13 consumes at stages 17-18 (Security Implementation). The threat report is archived with the release for audit compliance.

## References

- `../../references/CONVENTIONS.md` — Dart 3, Riverpod 2.x, freezed, go_router, Material 3, sealed Failure/Result patterns used in all Flutter/Dart code.
- `../../references/PIPELINE.md` — 24-stage pipeline; this skill feeds security controls into stages 17-18.
- `../13_Security/SKILL.md` — Security control implementations (Keystore, pinning, obfuscation, biometrics, input validation).
- `../58_SBOM/SKILL.md` — Software bill of materials; known-vulnerable dependencies flagged here.
- `../61_Secrets_Scan/SKILL.md` — Hardcoded secret detection; findings escalate to threat model.
- STRIDE methodology: Microsoft, "The STRIDE Threat Model" (2005).
- OWASP Mobile Top 10 (current year).
