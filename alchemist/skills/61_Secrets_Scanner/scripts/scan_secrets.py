#!/usr/bin/env python3
"""Secrets scanner for Flutter/Android projects — stdlib-only Python 3.

Scans staged, unstaged, or all tracked files for API keys, tokens, private
keys, keystore files, google-services.json, and suspicious base64 blobs.
"""

import argparse
import json
import os
import re
import sys
from pathlib import Path


# ---------------------------------------------------------------------------
# Pattern definitions — (regex, name, severity)
# All regex are case-insensitive.
# ---------------------------------------------------------------------------
PATTERNS = [
    (re.compile(r"AIza[0-9A-Za-z\-_]{35}", re.IGNORECASE), "Google API key", "HIGH"),
    (re.compile(r"AKIA[0-9A-Z]{16}", re.IGNORECASE), "AWS access key", "HIGH"),
    (
        re.compile(r"(?<![A-Z0-9])[A-Z0-9]{40}(?![A-Z0-9])"),
        "Possible AWS secret key heuristic",
        "MEDIUM",
    ),
    (
        re.compile(r"gh[pousr]_[A-Za-z0-9_]{36,}", re.IGNORECASE),
        "GitHub classic token",
        "HIGH",
    ),
    (
        re.compile(r"github_pat_[A-Za-z0-9_]{22,}", re.IGNORECASE),
        "GitHub fine-grained token",
        "HIGH",
    ),
    (
        re.compile(r"-----BEGIN (RSA|EC|DSA|OPENSSH) PRIVATE KEY-----", re.IGNORECASE),
        "Private key header",
        "HIGH",
    ),
    (
        re.compile(
            r"client_secret\s*[:=]\s*[\"'][A-Za-z0-9\-_]{20,}[\"']", re.IGNORECASE
        ),
        "OAuth client secret",
        "HIGH",
    ),
    (
        re.compile(r"[A-Za-z0-9+/]{60,}={0,2}"),
        "Suspicious base64 blob",
        "WARN",
    ),
]


def load_allowlist(root: Path) -> list[re.Pattern]:
    """Load .secrets-allowlist from repo root.  Returns compiled patterns."""
    allowlist_path = root / ".secrets-allowlist"
    if not allowlist_path.is_file():
        return []
    patterns = []
    with open(allowlist_path, encoding="utf-8") as fh:
        for raw in fh:
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            try:
                patterns.append(re.compile(line))
            except re.error as exc:
                print(f"WARNING: bad allowlist pattern skipped: {line!r} ({exc})",
                      file=sys.stderr)
    return patterns


def is_allowlisted(match_text: str, allowlist: list[re.Pattern]) -> bool:
    """Return True if match_text is matched by any allowlist pattern."""
    return any(p.search(match_text) for p in allowlist)


def run_git_command(root: Path, args: list[str]) -> list[str]:
    """Run a git command and return stdout lines (stripped)."""
    import subprocess

    try:
        result = subprocess.run(
            ["git"] + args,
            cwd=str(root),
            capture_output=True,
            text=True,
            check=True,
        )
        return [line.strip() for line in result.stdout.splitlines() if line.strip()]
    except subprocess.CalledProcessError as exc:
        print(f"ERROR: git command failed: {' '.join(args)}\n{exc.stderr}",
              file=sys.stderr)
        return []


def find_project_root() -> Path:
    """Locate the git repository root.  Falls back to CWD."""
    import subprocess

    try:
        result = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True,
            text=True,
            check=True,
        )
        return Path(result.stdout.strip())
    except subprocess.CalledProcessError:
        return Path.cwd()


def get_file_list(root: Path, staged: bool, diff: bool, all_files: bool) -> list[str]:
    """Return the list of files to scan based on flags."""
    if staged:
        return run_git_command(root, ["diff", "--cached", "--name-only"])
    if diff:
        return run_git_command(root, ["diff", "--name-only"])
    # Default / --all: use git ls-files (respects .gitignore)
    return run_git_command(root, ["ls-files"])


def is_binary(filename: str) -> bool:
    """Quick heuristic for binary files based on extension."""
    suffixes = Path(filename).suffix.lower()
    return suffixes in {
        ".png", ".jpg", ".jpeg", ".gif", ".ico", ".bmp", ".webp",
        ".mp3", ".mp4", ".wav", ".avi", ".mov",
        ".zip", ".tar", ".gz", ".bz2", ".7z", ".rar",
        ".pdf",
    }


def scan_file(
    filepath: str,
    root: Path,
    allowlist: list[re.Pattern],
) -> list[dict]:
    """Scan a single file and return list of finding dicts."""
    full_path = root / filepath
    if not full_path.is_file():
        return []

    findings = []

    # Keystore detection
    if filepath.lower().endswith((".keystore", ".jks")):
        if not is_allowlisted(filepath, allowlist):
            findings.append({
                "file": filepath,
                "line": 0,
                "severity": "MEDIUM",
                "name": "Keystore file",
                "match": filepath,
            })
        return findings

    # google-services.json detection
    if full_path.name == "google-services.json" and not is_allowlisted(
        filepath, allowlist
    ):
        findings.append({
            "file": filepath,
            "line": 0,
            "severity": "WARN",
            "name": "google-services.json tracked",
            "match": filepath,
        })
        # Attempt deep JSON field inspection
        try:
            with open(full_path, encoding="utf-8") as fh:
                data = json.load(fh)
            # Flutter-style google-services.json
            project_info = data.get("project_info", {})
            for field in ("project_number", "api_key", "project_id"):
                val = project_info.get(field)
                if val and not is_allowlisted(str(val), allowlist):
                    findings.append({
                        "file": filepath,
                        "line": 0,
                        "severity": "HIGH",
                        "name": f"Firebase {field} in google-services.json",
                        "match": str(val)[:40],
                    })
            # Check client arrays
            for client_entry in data.get("client", []):
                client_info = client_entry.get("client_info", {})
                app_id = client_info.get("mobilesdk_app_id")
                if app_id and not is_allowlisted(str(app_id), allowlist):
                    findings.append({
                        "file": filepath,
                        "line": 0,
                        "severity": "HIGH",
                        "name": "Firebase app_id in google-services.json",
                        "match": str(app_id)[:40],
                    })
        except (json.JSONDecodeError, UnicodeDecodeError, OSError):
            pass
        return findings

    # Skip binary files
    if is_binary(filepath):
        return findings

    # Content scan
    try:
        with open(full_path, encoding="utf-8", errors="ignore") as fh:
            lines = fh.readlines()
    except OSError:
        return findings

    for line_num, line in enumerate(lines, start=1):
        for regex, name, severity in PATTERNS:
            for m in regex.finditer(line):
                match_text = m.group()
                if is_allowlisted(match_text, allowlist):
                    continue
                findings.append({
                    "file": filepath,
                    "line": line_num,
                    "severity": severity,
                    "name": name,
                    "match": match_text[:40],
                })
    return findings


def format_plain(findings: list[dict]) -> str:
    """Format findings as plain-text lines."""
    lines = []
    for f in findings:
        lines.append(
            f"{f['file']}:{f['line']}: "
            f"{f['severity']}: "
            f"{f['name']}: "
            f"{f['match']}"
        )
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser(description="Secrets scanner — Flutter/Android")
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--staged", action="store_true",
                       help="Scan staged files only")
    group.add_argument("--diff", action="store_true",
                       help="Scan unstaged modified files only")
    group.add_argument("--all", action="store_true",
                       help="Scan all tracked files (default)")
    parser.add_argument("--json", action="store_true",
                        help="Output findings as JSON array")
    args = parser.parse_args()

    root = find_project_root()
    file_list = get_file_list(root, args.staged, args.diff, args.all)

    allowlist = load_allowlist(root)

    all_findings: list[dict] = []
    for filepath in file_list:
        all_findings.extend(scan_file(filepath, root, allowlist))

    if args.json:
        print(json.dumps(all_findings, indent=2))
    else:
        if all_findings:
            print(format_plain(all_findings))

    # Exit code 1 if any HIGH finding
    if any(f["severity"] == "HIGH" for f in all_findings):
        sys.exit(1)
    sys.exit(0)


if __name__ == "__main__":
    main()
