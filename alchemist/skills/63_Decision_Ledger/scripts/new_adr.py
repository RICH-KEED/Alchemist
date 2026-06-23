#!/usr/bin/env python3
"""new_adr.py — scaffold a new ADR and register it in the Decision Ledger.

For skill 63_Decision_Ledger. Given a decision's title (and optional trace
metadata), this:

  1. finds the next free ADR number under <root>/docs/adr/ (NNNN-*.md),
  2. scaffolds docs/adr/NNNN-<kebab-title>.md from the template, filling in
     title, number, date, stage, requirement, files and supersedes links, and
  3. appends an entry to <root>/.flutter-pipeline/decisions.json (creating it,
     and its schemaVersion, on first run) so the requirement -> ADR -> files
     trace is queryable.

If --supersedes NNNN is given, the prior ledger entry is flipped to
'superseded' and cross-linked (supersededBy), per the append-only lifecycle.

Stdlib only. Offline. Idempotent number allocation (re-running makes a new ADR;
it never overwrites an existing file).

Usage:
  python3 new_adr.py --title "Choose Supabase over custom backend" \
      --requirement STORY-12 \
      --files lib/features/auth/data/auth_repository.dart \
      --bucket stack --stage 11_Backend_Integration --root .

Options:
  --title STR        decision title (required)
  --requirement STR  upstream driver: PRD story id / UX flow / gate / issue
  --files STR ...    repo-relative paths the decision produced/changed (repeatable
                     or space/comma separated)
  --bucket B         one of: stack | library | architecture | tradeoff
  --stage STR        pipeline stage that made the call (e.g. 11_Backend_Integration)
  --status S         initial status (default: proposed)
  --supersedes N     ADR number this decision replaces (cross-links both ways)
  --date YYYY-MM-DD  decision date (default: today, local time)
  --root DIR         project root (default: cwd)
  --template PATH    ADR template (default: ../templates/decision_record.md)
  --json             print a machine-readable result instead of the human line

Exit codes: 0 ok · 2 bad args · 3 template not found · 4 ledger unreadable.
"""
from __future__ import annotations

import argparse
import datetime as _dt
import json
import re
import sys
from pathlib import Path
from typing import List, Optional

SCHEMA_VERSION = 1
VALID_STATUS = ("proposed", "accepted", "rejected", "deprecated", "superseded")
VALID_BUCKET = ("stack", "library", "architecture", "tradeoff")


def kebab(title: str) -> str:
    """Lowercase, hyphenated slug for the ADR filename."""
    slug = re.sub(r"[^a-z0-9]+", "-", title.strip().lower()).strip("-")
    return slug or "decision"


def split_multi(values: Optional[List[str]]) -> List[str]:
    """Flatten repeated --files and space/comma-separated blobs into a clean list."""
    out: List[str] = []
    for v in values or []:
        for part in re.split(r"[,\s]+", v.strip()):
            if part:
                out.append(part)
    # de-dupe, preserve order
    seen = set()
    return [p for p in out if not (p in seen or seen.add(p))]


def next_number(adr_dir: Path) -> int:
    """Lowest free ADR number = max existing NNNN + 1 (1-based)."""
    highest = 0
    if adr_dir.is_dir():
        for f in adr_dir.glob("*.md"):
            m = re.match(r"(\d+)", f.name)
            if m:
                highest = max(highest, int(m.group(1)))
    return highest + 1


def load_ledger(path: Path) -> dict:
    if not path.exists():
        return {"schemaVersion": SCHEMA_VERSION, "decisions": []}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        sys.stderr.write(f"error: cannot read ledger at {path}: {exc}\n")
        raise SystemExit(4)
    data.setdefault("schemaVersion", SCHEMA_VERSION)
    data.setdefault("decisions", [])
    return data


def fill_template(text: str, *, num: int, title: str, date: str, stage: str,
                  status: str, requirement: str, files: List[str],
                  supersedes: Optional[int]) -> str:
    """Replace the template's placeholder tokens with concrete values.

    Best-effort line replacement so the scaffold opens pre-filled; the author
    still edits Context / Decision / Alternatives prose by hand.
    """
    nnnn = f"{num:04d}"
    files_block = "\n".join(f"  - `{f}`" for f in files) or "  - <path>"
    sup = f"ADR-{supersedes:04d}" if supersedes else "none"
    repl = {
        r"^# NNNN\. .*$": f"# {num}. {title}",
        r"^- \*\*Status:\*\*.*$": f"- **Status:** {status.capitalize()}",
        r"^- \*\*Date:\*\*.*$": f"- **Date:** {date}",
        r"^- \*\*Stage:\*\*.*$": f"- **Stage:** {stage or '<stage>'}",
        r"^- \*\*Requirement:\*\* .*$": f"- **Requirement:** {requirement or '<requirement>'}",
        r"^- \*\*Supersedes:\*\* .*$": f"- **Supersedes:** {sup}",
    }
    lines = text.splitlines()
    for i, line in enumerate(lines):
        for pat, new in repl.items():
            if re.match(pat, line):
                lines[i] = new
                break
    out = "\n".join(lines)
    # Swap the placeholder files bullet line for the real list.
    out = re.sub(r"^  - `lib/features/<feature>/data/<x>_repository.dart`$",
                 files_block, out, flags=re.MULTILINE)
    return out + ("\n" if not out.endswith("\n") else "")


def main(argv: Optional[List[str]] = None) -> int:
    p = argparse.ArgumentParser(description="Scaffold an ADR and register it in the Decision Ledger.")
    p.add_argument("--title", required=True)
    p.add_argument("--requirement", default="")
    p.add_argument("--files", nargs="*", default=[])
    p.add_argument("--bucket", choices=VALID_BUCKET, default=None)
    p.add_argument("--stage", default="")
    p.add_argument("--status", choices=VALID_STATUS, default="proposed")
    p.add_argument("--supersedes", type=int, default=None)
    p.add_argument("--date", default=_dt.date.today().isoformat())
    p.add_argument("--root", default=".")
    p.add_argument("--template", default=None)
    p.add_argument("--json", action="store_true")
    args = p.parse_args(argv)

    if not args.title.strip():
        sys.stderr.write("error: --title must not be empty\n")
        return 2

    root = Path(args.root).resolve()
    adr_dir = root / "docs" / "adr"
    ledger_path = root / ".flutter-pipeline" / "decisions.json"
    template_path = (Path(args.template) if args.template
                     else Path(__file__).resolve().parent.parent / "templates" / "decision_record.md")

    if not template_path.exists():
        sys.stderr.write(f"error: template not found at {template_path}\n")
        return 3

    files = split_multi(args.files)
    num = next_number(adr_dir)
    nnnn = f"{num:04d}"
    adr_name = f"{nnnn}-{kebab(args.title)}.md"
    adr_path = adr_dir / adr_name
    adr_rel = f"docs/adr/{adr_name}"

    # 1) scaffold the ADR file
    adr_dir.mkdir(parents=True, exist_ok=True)
    body = fill_template(
        template_path.read_text(encoding="utf-8"),
        num=num, title=args.title, date=args.date, stage=args.stage,
        status=args.status, requirement=args.requirement, files=files,
        supersedes=args.supersedes,
    )
    adr_path.write_text(body, encoding="utf-8")

    # 2) append to the ledger (and cross-link supersession)
    ledger = load_ledger(ledger_path)
    if args.supersedes is not None:
        for d in ledger["decisions"]:
            if d.get("id") == args.supersedes:
                d["status"] = "superseded"
                d["supersededBy"] = num
                break

    entry = {
        "id": num,
        "title": args.title.strip(),
        "status": args.status,
        "date": args.date,
        "stage": args.stage or None,
        "bucket": args.bucket,
        "requirement": args.requirement or None,
        "adr": adr_rel,
        "files": files,
        "supersedes": args.supersedes,
        "supersededBy": None,
    }
    # drop the bucket key entirely if unset, to keep entries lean
    if entry["bucket"] is None:
        del entry["bucket"]
    ledger["decisions"].append(entry)
    ledger["schemaVersion"] = SCHEMA_VERSION
    ledger["generatedAt"] = _dt.datetime.now().astimezone().isoformat(timespec="seconds")

    ledger_path.parent.mkdir(parents=True, exist_ok=True)
    ledger_path.write_text(json.dumps(ledger, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    if args.json:
        print(json.dumps({"id": num, "adr": adr_rel, "ledger": str(ledger_path.relative_to(root))}, indent=2))
    else:
        print(f"ADR-{nnnn} created -> {adr_rel}")
        if args.supersedes is not None:
            print(f"  supersedes ADR-{args.supersedes:04d}")
        print(f"registered in {ledger_path.relative_to(root)} (requirement={entry['requirement']}, files={len(files)})")
        print("next: fill Context / Decision / Alternatives, then flip Status to Accepted")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
