#!/usr/bin/env python3
"""
changelog.py — Generate changelog + Play Store "What's New" from Conventional Commits.

Reads commits between two git tags, groups by Conventional Commit type,
and outputs a Markdown changelog plus a user-facing Play Store summary.

Usage:
    python3 changelog.py --from v1.2.0 --to v1.3.0
    python3 changelog.py --from v1.2.0 --to v1.3.0 --repo /path/to/project
    python3 changelog.py --from v1.2.0 --to v1.3.0 --output-dir ./release-notes
"""

import argparse
import json
import os
import re
import subprocess
import sys
from collections import defaultdict
from datetime import date

# Conventional Commit prefixes and their changelog section labels.
# Order matters: Features first, then Bug Fixes, then the rest.
TYPE_LABELS = {
    "feat": "Features",
    "fix": "Bug Fixes",
    "perf": "Performance",
    "refactor": "Refactoring",
    "docs": "Documentation",
    "test": "Testing",
    "ci": "CI & Build",
    "chore": "Chores",
    "style": "Style",
    "build": "Build System",
}

# These types are skipped for the Play Store "What's New" summary.
PLAY_SKIP_TYPES = {"docs", "ci", "chore", "test", "refactor", "style", "build"}

# Mapping from commit type to user-facing verb.
USER_FACING_VERBS = {
    "feat": "Added",
    "fix": "Fixed",
    "perf": "Improved",
}


def run_git_log(from_ref: str, to_ref: str, repo: str) -> list[str]:
    """Return non-merge commit messages between two refs."""
    cmd = [
        "git", "-C", repo, "log",
        "--no-merges",
        "--format=%H %s",
        f"{from_ref}..{to_ref}",
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"Error running git log: {result.stderr}", file=sys.stderr)
        sys.exit(1)
    return [line.strip() for line in result.stdout.strip().split("\n") if line.strip()]


def parse_commit(line: str) -> dict | None:
    """Parse a single 'hash message' line into {hash, type, scope, message, breaking}."""
    parts = line.split(" ", 1)
    if len(parts) < 2:
        return None
    commit_hash = parts[0]
    message = parts[1]

    breaking = "!" in message.split(":")[0] if ":" in message else False

    # Conventional Commit pattern: type(scope): description  or  type!: description
    match = re.match(
        r"^(feat|fix|perf|docs|refactor|test|ci|chore|style|build)"
        r"(?:\(([^)]+)\))?(!)?\s*:\s*(.+)$",
        message,
    )
    if not match:
        # Non-conventional commit — file under "Other"
        return {
            "hash": commit_hash,
            "type": "other",
            "scope": None,
            "message": message,
            "breaking": False,
        }

    return {
        "hash": commit_hash,
        "type": match.group(1),
        "scope": match.group(2),
        "message": match.group(4).strip(),
        "breaking": breaking or "BREAKING CHANGE:" in message,
    }


def format_commit_for_changelog(commit: dict) -> str:
    """Format a single commit as a changelog bullet."""
    scope_str = f"**{commit['scope']}:** " if commit["scope"] else ""
    msg = commit["message"][0].upper() + commit["message"][1:]
    if not msg.endswith("."):
        msg += "."
    line = f"- {scope_str}{msg}"
    if commit["breaking"]:
        line += " **[BREAKING]**"
    return line


def format_play_bullet(commit: dict) -> str:
    """Convert a commit to a user-facing Play Store bullet."""
    msg = commit["message"]
    # Try to make it user-facing
    verb = USER_FACING_VERBS.get(commit["type"], "Updated")
    if msg.endswith("."):
        msg = msg[:-1]
    return f"{verb} {msg[0].lower() + msg[1:]}."


def generate_changelog(
    from_ref: str,
    to_ref: str,
    repo: str = ".",
    version: str | None = None,
) -> str:
    """Generate full Markdown changelog and return it as a string."""
    lines = run_git_log(from_ref, to_ref, repo)
    commits = [c for line in lines if (c := parse_commit(line))]

    # Group by type
    grouped: dict[str, list[dict]] = defaultdict(list)
    for c in commits:
        grouped[c["type"]].append(c)

    # Build output
    parts = []
    version_str = version or to_ref.lstrip("v")
    parts.append(f"## [{version_str}] — {date.today().isoformat()}")
    parts.append("")

    # Breaking changes first
    breaking = [c for c in commits if c["breaking"]]
    if breaking:
        parts.append("### Breaking Changes")
        parts.append("")
        for c in breaking:
            scope_str = f"**{c['scope']}:** " if c["scope"] else ""
            parts.append(
                f"- {scope_str}"
                f"{c['message'][0].upper() + c['message'][1:].rstrip('.')}."
            )
        parts.append("")

    # Each type in order
    for typ, label in TYPE_LABELS.items():
        group = grouped.get(typ, [])
        if not group:
            continue
        parts.append(f"### {label}")
        parts.append("")
        for c in group:
            parts.append(format_commit_for_changelog(c))
        parts.append("")

    return "\n".join(parts).rstrip() + "\n"


def generate_play_whats_new(
    from_ref: str,
    to_ref: str,
    repo: str = ".",
    max_chars: int = 500,
) -> str:
    """Generate Play Store 'What's New' text (user-facing, ≤500 chars)."""
    lines = run_git_log(from_ref, to_ref, repo)
    commits = [c for line in lines if (c := parse_commit(line))]
    commits = [c for c in commits if c["type"] not in PLAY_SKIP_TYPES]

    # Sort: breaking first, then feat, fix, perf
    def sort_key(c: dict) -> int:
        order = {"feat": 0, "fix": 1, "perf": 2}
        return (0 if c["breaking"] else 1, order.get(c["type"], 3))

    commits.sort(key=sort_key)

    bullets = []
    total = 0
    for c in commits:
        bullet = format_play_bullet(c)
        # Truncate if adding this bullet exceeds max_chars
        prospective = total + len(bullet) + (1 if bullets else 0)  # +1 for newline
        if prospective > max_chars and bullets:
            bullets.append("…and more improvements.")
            break
        bullets.append(bullet)
        total = prospective

    return "\n".join(bullets)


def main():
    parser = argparse.ArgumentParser(
        description="Generate changelog from Conventional Commits between two tags."
    )
    parser.add_argument("--from", dest="from_ref", required=True, help="Base tag/ref")
    parser.add_argument("--to", dest="to_ref", required=True, help="Target tag/ref")
    parser.add_argument("--repo", default=".", help="Path to git repository")
    parser.add_argument("--version", default=None, help="Version string for heading")
    parser.add_argument(
        "--output-dir",
        default=None,
        help="Directory to write changelog.md and whats_new.txt to",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Output JSON with both changelog and whats_new fields",
    )
    args = parser.parse_args()

    changelog = generate_changelog(args.from_ref, args.to_ref, args.repo, args.version)
    whats_new = generate_play_whats_new(args.from_ref, args.to_ref, args.repo)

    if args.json:
        print(json.dumps({"changelog": changelog, "whats_new": whats_new}, indent=2))
    elif args.output_dir:
        os.makedirs(args.output_dir, exist_ok=True)
        with open(os.path.join(args.output_dir, "changelog.md"), "w") as f:
            f.write(changelog)
        with open(os.path.join(args.output_dir, "whats_new.txt"), "w") as f:
            f.write(whats_new)
        print(f"Written to {args.output_dir}/changelog.md and whats_new.txt")
    else:
        print("=== CHANGELOG ===")
        print(changelog)
        print("=== WHAT'S NEW (Play Store) ===")
        print(whats_new)


if __name__ == "__main__":
    main()
