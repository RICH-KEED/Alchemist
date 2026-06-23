---
name: 61_Secrets_Scanner
description: >-
  Pre-commit/CI scan for API keys, tokens, keystores, google-services.json, and
  base64 blobs — Flutter/Android-tuned. Catches Google API keys, Firebase configs,
  AWS keys, GitHub tokens, private keys, OAuth client secrets, keystore files, and
  suspicious base64 blobs.  Trigger: before every commit or CI run — scan secrets.
when_to_use: manual
---

# 61 — Secrets Scanner

**Exit gate:** scan runs clean; no secrets detected in staged or committed files.

Scan runs via `scripts/scan_secrets.py` (stdlib-only Python 3). For coding conventions see
`../../references/CONVENTIONS.md`.

---

## What this scanner catches

| Pattern | Regex / Check | Severity |
|---|---|---|
| Google API key | `AIza[0-9A-Za-z\-_]{35}` (case-insensitive) | HIGH |
| Firebase project_number / api_key / app_id in google-services.json fields | Field-level inspection of tracked `google-services.json` | HIGH |
| AWS access key | `AKIA[0-9A-Z]{16}` (case-insensitive) | HIGH |
| AWS secret key | `(?<![A-Z0-9])[A-Z0-9]{40}(?![A-Z0-9])` heuristic | MEDIUM |
| GitHub classic token | `gh[pousr]_[A-Za-z0-9_]{36,}` (case-insensitive) | HIGH |
| GitHub fine-grained token | `github_pat_[A-Za-z0-9_]{22,}` (case-insensitive) | HIGH |
| RSA private key | `-----BEGIN RSA PRIVATE KEY-----` | HIGH |
| EC private key | `-----BEGIN EC PRIVATE KEY-----` | HIGH |
| DSA private key | `-----BEGIN DSA PRIVATE KEY-----` | HIGH |
| OpenSSH private key | `-----BEGIN OPENSSH PRIVATE KEY-----` | HIGH |
| OAuth client secret | `client_secret\s*[:=]\s*["'][A-Za-z0-9\-_]{20,}["']` (case-insensitive) | HIGH |
| High-entropy base64 blob | `[A-Za-z0-9+/]{60,}={0,2}` heuristic | WARN |
| Java keystore file | Files ending in `.keystore` or `.jks` in tracked files | MEDIUM |
| google-services.json presence | Any tracked `google-services.json` not in allowlist | WARN |

---

## Android-specific patterns

- **google-services.json** — Firebase config file. If tracked in git, its contents are scanned
  for `project_number`, `api_key`, and `app_id` values. The scanner flags the file itself (WARN)
  and any exposed credential fields (HIGH).
- **Keystore files** — `.jks` and `.keystore` files should never be tracked. The scanner
  flags their presence as MEDIUM. These feed into skill 13 (Security) for remediation.
- **google_maps_api_key** — The scanner will catch this if it appears in `AndroidManifest.xml`
  or any Dart/config file via the Google API key pattern above.

---

## Pre-commit hook setup

Copy the hook template into your repo:

```bash
cp ${CLAUDE_SKILL_DIR}/templates/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

The hook calls `${CLAUDE_SKILL_DIR}/scripts/scan_secrets.py --staged` and aborts the
commit if the script exits non-zero (i.e., any HIGH finding). WARN/MEDIUM findings are
printed but do not block the commit.

To skip the hook in an emergency: `git commit --no-verify -m "..."`

---

## CI integration in GitHub Actions

Add this step to any workflow (usually in the PR check workflow orchestrated by skill 19):

```yaml
- name: Scan for secrets
  run: |
    python ${CLAUDE_SKILL_DIR}/scripts/scan_secrets.py --all --json > findings.json
    if [ $? -ne 0 ]; then
      cat findings.json
      exit 1
    fi
```

The `--json` flag produces machine-readable output suitable for CI annotations.

---

## False positive handling — .secrets-allowlist

Place a `.secrets-allowlist` file at the repository root. Format:

- One regex pattern per line.
- Blank lines and lines starting with `#` are ignored.
- Patterns are matched against each finding's matched text. If any pattern matches,
  the finding is suppressed.

The scanner loads this file automatically. See `templates/.secrets-allowlist` for
an annotated example with demo keys, test fixtures, and known-safe base64 patterns.

---

## Script usage reference

```
scripts/scan_secrets.py [--staged] [--diff] [--all] [--json]
```

| Flag | Behavior |
|---|---|
| `--staged` | Scan files staged for commit (`git diff --cached --name-only`) |
| `--diff` | Scan unstaged modified files (`git diff --name-only`) |
| `--all` | Scan all tracked files (respects `.gitignore` via `git ls-files`) |
| `--json` | Output findings as a JSON array instead of plain text |

Default (no flags): scans all tracked files, plain-text output.

Exit codes:
- `0` — no HIGH findings (WARN/MEDIUM may still be present).
- `1` — one or more HIGH findings detected.

---

## How rule — feeding the pipeline

| Downstream skill | What it receives |
|---|---|
| Skill 13 — Security | Findings report for hardening: rotate exposed keys, move secrets to `flutter_secure_storage`, add files to `.gitignore` |
| Skill 19 — GitHub Workflow | CI step configuration (see CI integration above); exits non-zero to fail PR checks on secret exposure |

After every scan the orchestrator (skill 01) should check whether any HIGH findings exist
and, if so, route them to skill 13 before allowing skill 19 to produce a green build.

---

## .secrets-allowlist format reference

```
# .secrets-allowlist — patterns that suppress scanner findings
# One regex per line. Blank lines and #-comments are ignored.

# Demo/test API keys used in unit tests
demo_key_1234567890abcdef

# Known-safe base64 blobs (e.g., embedded test PNG)
iVBORw0KGgo[A-Za-z0-9+/=]{20,}

# OAuth client secrets for local dev (non-prod)
not-a-real-secret-[a-z0-9]{10}

# Whitelist a specific google-services.json in a test fixtures directory
test/fixtures/google-services\.json
```
