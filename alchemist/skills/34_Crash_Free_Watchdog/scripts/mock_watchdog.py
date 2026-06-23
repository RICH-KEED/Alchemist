#!/usr/bin/env python3
"""
mock_watchdog.py — Crash Free Watchdog (#34) mock/polling agent.

Reads a watchdog_state.json file (mock crash data: signatures, counts, trends),
applies thresholds, and prints ALERT lines for any actionable signal.

Usage:
    python mock_watchdog.py [--state watchdog_state.json] [--threshold-crash-free 98.0] [--spike-factor 2.0]

Exit codes:
    0 — clean (no alerts)
    1 — one or more alerts fired (signals above threshold)

This is a mock until a real Sentry/Crashlytics MCP is connected. The state file
mirrors the structure defined in SKILL.md §4 (State persistence).

Stdlib only — no third-party deps.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from typing import Dict, List


# --- defaults ----------------------------------------------------------------
DEFAULT_STATE_FILE = "watchdog_state.json"
DEFAULT_CRASH_FREE_THRESHOLD = 98.0   # % below which crash-free drop triggers alert
DEFAULT_SPIKE_FACTOR = 2.0            # count increase factor to trigger spike alert
DEFAULT_MIN_EVENTS_NEW = 5            # min events for a new signature to be actionable


def load_state(path: str) -> dict:
    """Load the watchdog state JSON file, or return a minimal stub."""
    if not os.path.isfile(path):
        print(f"!! {path} not found — using empty state.", file=sys.stderr)
        return {
            "provider": "mock",
            "last_sweep": None,
            "crash_free_pct": 99.5,
            "signatures": {},
        }
    with open(path, "r", encoding="utf-8") as fh:
        return json.load(fh)


def check_alerts(
    state: dict,
    crash_free_threshold: float,
    spike_factor: float,
    min_events_new: int,
) -> List[str]:
    """Return a list of ALERT strings for any actionable signal."""
    alerts: List[str] = []

    # --- 1. Crash-free % check ---
    crash_free = state.get("crash_free_pct", 100.0)
    previous_crash_free = state.get("previous_crash_free_pct", crash_free)
    drop = previous_crash_free - crash_free

    # Threshold from SKILL.md §2: configured crash_free_drop_pct
    # We use the configured threshold (default 2.0 pp) from state if present,
    # else fall back to CLI arg.
    configured_drop = state.get("thresholds", {}).get("crash_free_drop_pct", None)
    effective_drop_threshold = (
        configured_drop
        if configured_drop is not None
        else (100.0 - crash_free_threshold)
    )
    # For the CLI arg approach: crash_free_threshold is the absolute % floor.
    # Re-interpret: drop = previous - current; alert if drop >= effective_threshold.

    if configured_drop is not None:
        # Config-driven: alert if drop >= configured_drop
        if drop >= configured_drop:
            alerts.append(
                f"ALERT: crash-free dropped from {previous_crash_free:.1f}% to "
                f"{crash_free:.1f}% (drop of {drop:.1f}pp, threshold {configured_drop}pp)"
            )
    else:
        # CLI-arg driven: alert if crash_free < crash_free_threshold
        if crash_free < crash_free_threshold:
            alerts.append(
                f"ALERT: crash-free dropped to {crash_free:.1f}% "
                f"(below threshold {crash_free_threshold:.1f}%)"
            )

    # --- 2. Signature checks ---
    signatures = state.get("signatures", {})
    previous_signatures = state.get("previous_signatures", {})

    for sig_name, sig_data in signatures.items():
        event_count = sig_data.get("event_count", 0)
        rate_per_hour = sig_data.get("rate_per_hour", 0.0)
        trend = sig_data.get("trend", "stable")       # "stable", "rising", "falling", "new"
        first_seen = sig_data.get("first_seen")

        # 2a. New signatures
        if trend == "new":
            if event_count >= min_events_new:
                alerts.append(
                    f"ALERT: NEW crash signature '{sig_name}' — "
                    f"{event_count} events, first seen {first_seen}"
                )
            elif event_count > 0:
                # Below threshold — log but don't alert
                print(
                    f"  (noise) New signature '{sig_name}' has {event_count} events "
                    f"(below min_events_new={min_events_new}) — not filing issue.",
                    file=sys.stderr,
                )

        # 2b. Spike on existing signatures
        prev = previous_signatures.get(sig_name, {})
        prev_count = prev.get("event_count", 0)
        if prev_count > 0 and event_count >= spike_factor * prev_count:
            alerts.append(
                f"ALERT: '{sig_name}' spiked — "
                f"{prev_count} -> {event_count} events ({event_count / prev_count:.1f}x, "
                f"threshold {spike_factor}x)"
            )

    return alerts


def main(argv: List[str]) -> int:
    ap = argparse.ArgumentParser(
        description="Crash Free Watchdog (#34) — mock polling agent."
    )
    ap.add_argument(
        "--state",
        default=DEFAULT_STATE_FILE,
        help=f"Path to watchdog state JSON (default: {DEFAULT_STATE_FILE})",
    )
    ap.add_argument(
        "--threshold-crash-free",
        type=float,
        default=DEFAULT_CRASH_FREE_THRESHOLD,
        help=f"Crash-free % threshold (default: {DEFAULT_CRASH_FREE_THRESHOLD})",
    )
    ap.add_argument(
        "--spike-factor",
        type=float,
        default=DEFAULT_SPIKE_FACTOR,
        help=f"Spike factor for existing signatures (default: {DEFAULT_SPIKE_FACTOR})",
    )
    ap.add_argument(
        "--min-events-new",
        type=int,
        default=DEFAULT_MIN_EVENTS_NEW,
        help=f"Min events for new signature to be actionable (default: {DEFAULT_MIN_EVENTS_NEW})",
    )
    args = ap.parse_args(argv)

    state = load_state(args.state)

    print(f"=== Crash Free Watchdog (#34) — Mock Sweep ===")
    print(f"State file : {args.state}")
    print(f"Provider   : {state.get('provider', 'unknown')}")
    print(f"Project    : {state.get('project', 'unknown')}")
    print(f"Last sweep : {state.get('last_sweep', 'never')}")
    print(f"Crash-free : {state.get('crash_free_pct', '?')}%")
    print(f"Signatures : {len(state.get('signatures', {}))}")
    print()

    alerts = check_alerts(
        state,
        args.threshold_crash_free,
        args.spike_factor,
        args.min_events_new,
    )

    if alerts:
        print(f"=== {len(alerts)} ALERT(S) ===")
        for a in alerts:
            print(a)
        print()
        print("Next: triage each alert via Runtime Exception Triage (#38).")
        print("      File a GitHub issue per actionable signature using templates/crash_issue_template.md.")
        return 1
    else:
        print("CLEAN — no crash signals above threshold.")
        print("Crash-free rate is stable and within the target window.")
        return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
