#!/usr/bin/env python3
"""card_index.py — index context cards and detect staleness.

Part of the flutter-android skill `25_Context_Compression_Engine`.

This helper is DETERMINISTIC and STDLIB-ONLY. It does NOT compress anything
(LLM-driven compression is the agent's job). It scans the cards directory,
reads each card's YAML-ish front-matter, resolves the source file, and
writes/updates `<root>/cards/index.json` with:

    source, hash, stage, tokens_full, tokens_card, savings_pct,
    card_mtime, source_mtime, stale (source changed after card was built),
    source_missing.

Staleness signal: a card is `stale` when its source file's mtime is newer
than the card file's mtime (the source was edited after the card was built),
or when the source file is missing. Recompress stale cards before trusting them.

Usage:
    python card_index.py --root .flutter-pipeline
    python card_index.py --root .flutter-pipeline --stale-only
    python card_index.py --cards-dir .flutter-pipeline/cards --json-only

Exit code is 0 normally, 2 if any stale/missing cards were found (handy for CI).
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import datetime, timezone

FRONT_MATTER_KEYS = (
    "card", "source", "hash", "stage",
    "tokens_full", "tokens_card", "compressed_at", "schema",
)


def parse_front_matter(text: str) -> dict:
    """Parse a leading `---` ... `---` YAML-ish block (flat key: value only).

    Stdlib-only, so we do a tiny line parser instead of importing PyYAML.
    Values are returned as strings; ints are coerced where the key expects one.
    """
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return {}
    fm: dict = {}
    for line in lines[1:]:
        if line.strip() == "---":
            break
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if ":" not in line:
            continue
        key, _, value = line.partition(":")
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        fm[key] = value
    # coerce known integer fields
    for int_key in ("tokens_full", "tokens_card", "schema"):
        if int_key in fm:
            try:
                fm[int_key] = int(fm[int_key])
            except (TypeError, ValueError):
                pass
    return fm


def find_cards(cards_dir: str) -> list[str]:
    if not os.path.isdir(cards_dir):
        return []
    out = []
    for name in sorted(os.listdir(cards_dir)):
        if name.endswith(".card.md"):
            out.append(os.path.join(cards_dir, name))
    return out


def resolve_source(project_root: str, source: str) -> str:
    """Source paths in cards are relative to the PROJECT root.

    project_root is the parent of `.flutter-pipeline` when --root points at
    `.flutter-pipeline`; otherwise we treat the given root's parent as project root.
    """
    if not source:
        return ""
    if os.path.isabs(source):
        return source
    return os.path.normpath(os.path.join(project_root, source))


def savings_pct(full, card) -> float | None:
    try:
        full = float(full)
        card = float(card)
    except (TypeError, ValueError):
        return None
    if full <= 0:
        return None
    return round((1.0 - card / full) * 100.0, 1)


def build_index(root: str) -> dict:
    """root points at the `.flutter-pipeline` dir (or any dir containing `cards/`)."""
    root = os.path.abspath(root)
    # allow --root to be either .flutter-pipeline or the cards dir itself
    if os.path.basename(root) == "cards":
        cards_dir = root
        pipeline_dir = os.path.dirname(root)
    else:
        cards_dir = os.path.join(root, "cards")
        pipeline_dir = root
    project_root = os.path.dirname(pipeline_dir)

    entries = []
    for card_path in find_cards(cards_dir):
        try:
            with open(card_path, "r", encoding="utf-8") as fh:
                fm = parse_front_matter(fh.read())
        except OSError as exc:
            entries.append({
                "card_file": os.path.basename(card_path),
                "error": f"unreadable: {exc}",
                "stale": True,
            })
            continue

        source = fm.get("source", "")
        source_abs = resolve_source(project_root, source)
        card_mtime = os.path.getmtime(card_path)
        source_mtime = None
        source_missing = True
        if source_abs and os.path.exists(source_abs):
            source_missing = False
            source_mtime = os.path.getmtime(source_abs)

        stale = source_missing or (
            source_mtime is not None and source_mtime > card_mtime
        )

        entries.append({
            "card_file": os.path.basename(card_path),
            "card": fm.get("card", ""),
            "source": source,
            "hash": fm.get("hash", ""),
            "stage": fm.get("stage", ""),
            "tokens_full": fm.get("tokens_full"),
            "tokens_card": fm.get("tokens_card"),
            "savings_pct": savings_pct(fm.get("tokens_full"), fm.get("tokens_card")),
            "compressed_at": fm.get("compressed_at", ""),
            "schema": fm.get("schema"),
            "card_mtime": _iso(card_mtime),
            "source_mtime": _iso(source_mtime) if source_mtime else None,
            "source_missing": source_missing,
            "stale": stale,
        })

    totals = _totals(entries)
    return {
        "generated_at": _iso(datetime.now(tz=timezone.utc).timestamp()),
        "cards_dir": cards_dir,
        "count": len(entries),
        "stale_count": sum(1 for e in entries if e.get("stale")),
        "totals": totals,
        "cards": entries,
    }


def _totals(entries: list[dict]) -> dict:
    full = sum(e["tokens_full"] for e in entries if isinstance(e.get("tokens_full"), int))
    card = sum(e["tokens_card"] for e in entries if isinstance(e.get("tokens_card"), int))
    return {
        "tokens_full": full,
        "tokens_card": card,
        "tokens_saved": full - card,
        "savings_pct": savings_pct(full, card),
    }


def _iso(ts) -> str | None:
    if ts is None:
        return None
    return datetime.fromtimestamp(ts, tz=timezone.utc).isoformat()


def write_index(index: dict) -> str:
    cards_dir = index["cards_dir"]
    os.makedirs(cards_dir, exist_ok=True)
    out_path = os.path.join(cards_dir, "index.json")
    with open(out_path, "w", encoding="utf-8") as fh:
        json.dump(index, fh, indent=2, ensure_ascii=False)
        fh.write("\n")
    return out_path


def print_table(index: dict, stale_only: bool) -> None:
    cards = index["cards"]
    if stale_only:
        cards = [c for c in cards if c.get("stale")]
    if not cards:
        print("No cards found." if not stale_only else "No stale cards.")
    else:
        print(f"{'CARD':<14} {'SAVE%':>6} {'FULL':>7} {'CARD':>7} {'STALE':>6}  SOURCE")
        print("-" * 72)
        for c in cards:
            sp = c.get("savings_pct")
            sp_s = f"{sp:.0f}%" if isinstance(sp, (int, float)) else "  -"
            stale_s = "STALE" if c.get("stale") else "ok"
            print(
                f"{str(c.get('card') or c.get('card_file')):<14} "
                f"{sp_s:>6} {str(c.get('tokens_full') or '-'):>7} "
                f"{str(c.get('tokens_card') or '-'):>7} {stale_s:>6}  "
                f"{c.get('source', '')}"
            )
    t = index["totals"]
    if t.get("tokens_full"):
        print("-" * 72)
        print(
            f"TOTAL saved {t['tokens_saved']} tokens "
            f"({t['savings_pct']}%) across {index['count']} cards; "
            f"{index['stale_count']} stale."
        )


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Index context cards and detect staleness.")
    ap.add_argument(
        "--root", default=".flutter-pipeline",
        help="Pipeline dir containing cards/ (default: .flutter-pipeline). "
             "May also point directly at a cards/ dir.",
    )
    ap.add_argument(
        "--cards-dir", default=None,
        help="Explicit path to the cards directory (overrides --root).",
    )
    ap.add_argument("--stale-only", action="store_true", help="Only list stale cards.")
    ap.add_argument("--json-only", action="store_true", help="Print the JSON, no table.")
    ap.add_argument("--no-write", action="store_true", help="Do not write index.json.")
    args = ap.parse_args(argv)

    root = args.cards_dir if args.cards_dir else args.root
    index = build_index(root)

    if not args.no_write:
        out_path = write_index(index)
    else:
        out_path = None

    if args.json_only:
        print(json.dumps(index, indent=2, ensure_ascii=False))
    else:
        print_table(index, args.stale_only)
        if out_path:
            print(f"\nWrote {out_path}")

    return 2 if index["stale_count"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
