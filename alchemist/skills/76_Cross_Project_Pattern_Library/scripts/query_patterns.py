#!/usr/bin/env python3
"""
query_patterns.py — Query the cross-project pattern library.

Searches ~/.flutter-pipeline/patterns.json (or a specified path) for
patterns matching a free-text query or context tags. Patterns are scored
by tag overlap + keyword match in the problem statement and description.

Usage:
    python3 query_patterns.py "optimistic toggle rollback"
    python3 query_patterns.py --tags state,network,mutation
    python3 query_patterns.py --file /path/to/patterns.json "offline sync"
    python3 query_patterns.py --list-all
    python3 query_patterns.py --list-tags
"""

import argparse
import json
import os
import sys

DEFAULT_STORE = os.path.expanduser("~/.flutter-pipeline/patterns.json")

SCORE_THRESHOLD = 3  # minimum score to recommend a pattern


def load_patterns(path: str) -> list[dict]:
    """Load patterns from the JSON store, returning an empty list if missing."""
    if not os.path.exists(path):
        return []
    with open(path, "r") as f:
        data = json.load(f)
    return data.get("patterns", [])


def normalize(s: str) -> str:
    """Lowercase and strip for comparison."""
    return s.lower().strip()


def tokenize(text: str) -> set[str]:
    """Split text into a set of lowercase word tokens."""
    return set(normalize(text).replace("-", " ").replace("_", " ").split())


def match_score(pattern: dict, query_tokens: set[str], tag_tokens: set[str]) -> int:
    """Score a pattern against query tokens and tag tokens. Higher = better match."""
    score = 0

    # Tag overlap — each matching tag is +3
    pattern_tags = {normalize(t) for t in pattern.get("context_tags", [])}
    for t in tag_tokens:
        if t in pattern_tags:
            score += 3

    # Problem match — each query token in the problem is +2
    problem_tokens = tokenize(pattern.get("problem", ""))
    for t in query_tokens:
        if t in problem_tokens:
            score += 2

    # Solution summary match — each query token is +1
    solution_tokens = tokenize(pattern.get("solution_summary", ""))
    for t in query_tokens:
        if t in solution_tokens:
            score += 1

    # When_not match — relevant for negative queries but still useful context
    when_not_tokens = tokenize(pattern.get("when_not", ""))
    for t in query_tokens:
        if t in when_not_tokens:
            score += 1

    return score


def format_pattern(pattern: dict, score: int, verbose: bool = False) -> str:
    """Format a single pattern for display."""
    confidence = pattern.get("confidence", "proposed")
    pid = pattern.get("id", "no-id")
    summary = pattern.get("solution_summary", "")
    when_not = pattern.get("when_not", "")
    projects = pattern.get("projects_used", [])

    lines = [
        f"  [{pid}]",
        f"  Score: {score}  |  Confidence: {confidence}  |  Used in: {len(projects)} project(s)",
    ]

    if summary:
        lines.append(f"  Solution: {summary}")

    if verbose:
        problem = pattern.get("problem", "")
        if problem:
            lines.append(f"  Problem: {problem}")
        full = pattern.get("full_solution", "")
        if full:
            if len(full) > 300:
                full = full[:300] + "..."
            lines.append(f"  Full solution: {full}")
        if when_not:
            lines.append(f"  When NOT to use: {when_not}")
        example = pattern.get("example_code", "")
        if example:
            lines.append(f"  Example code (snippet):\n```dart\n{example.strip()}\n```")

    lines.append("")
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(
        description="Query the cross-project pattern library."
    )
    parser.add_argument(
        "query",
        nargs="?",
        default="",
        help="Free-text query describing the task/problem",
    )
    parser.add_argument(
        "--tags",
        default="",
        help="Comma-separated context tags (state, network, mutation, etc.)",
    )
    parser.add_argument(
        "--file",
        default=DEFAULT_STORE,
        help=f"Path to patterns.json (default: {DEFAULT_STORE})",
    )
    parser.add_argument(
        "--threshold",
        type=int,
        default=SCORE_THRESHOLD,
        help=f"Minimum score to display a pattern (default: {SCORE_THRESHOLD})",
    )
    parser.add_argument(
        "--verbose", "-v", action="store_true", help="Show full pattern details"
    )
    parser.add_argument(
        "--list-all", action="store_true", help="List all patterns regardless of query"
    )
    parser.add_argument(
        "--list-tags", action="store_true", help="List all context tags in the library"
    )
    parser.add_argument(
        "--json", action="store_true", help="Output results as JSON"
    )
    args = parser.parse_args()

    patterns = load_patterns(args.file)

    if not patterns:
        if args.json:
            print(json.dumps({"patterns": [], "note": "Library is empty or not found"}))
        else:
            print("Pattern library is empty or not found at", args.file)
        return

    # List all patterns
    if args.list_all:
        results = [(p, 0) for p in patterns]
    else:
        query_tokens = tokenize(args.query)
        tag_tokens = {normalize(t) for t in args.tags.split(",") if t.strip()}

        # Score and filter
        scored = []
        for p in patterns:
            s = match_score(p, query_tokens, tag_tokens)
            if s >= args.threshold:
                scored.append((p, s))

        # Sort by score descending, then confidence
        confidence_order = {"established": 0, "emerging": 1, "proposed": 2}
        results = sorted(
            scored,
            key=lambda x: (
                -x[1],
                confidence_order.get(x[0].get("confidence", "proposed"), 3),
            ),
        )

    if args.json:
        output = {
            "patterns": [
                {
                    "id": p["id"],
                    "score": s,
                    "confidence": p.get("confidence", "proposed"),
                    "solution_summary": p.get("solution_summary", ""),
                    "context_tags": p.get("context_tags", []),
                }
                for p, s in results
            ]
        }
        print(json.dumps(output, indent=2))
    else:
        if not results:
            if not args.list_all:
                query_desc = args.query or "(no query)"
                print(
                    f"No patterns matched query '{query_desc}'"
                    + (f" tags={args.tags}" if args.tags else "")
                    + f" (threshold: {args.threshold})."
                )
                print("Try --list-all to browse, or check --file path.")
            return

        print(f"Found {len(results)} matching pattern(s):\n")
        for p, s in results:
            print(format_pattern(p, s, verbose=args.verbose))


if __name__ == "__main__":
    main()
