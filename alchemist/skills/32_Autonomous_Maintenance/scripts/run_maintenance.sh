#!/usr/bin/env bash
#
# run_maintenance.sh — Autonomous Maintenance Agent (#32) sweep script.
#
# Pipeline:
#   1. Preflight: verify this is a Flutter project (has pubspec.yaml)
#   2. flutter pub upgrade (patch + minor only; no --major-versions by default)
#   3. dart fix --apply  +  dart format .
#   4. flutter analyze to gate quality
#   5. Report what changed (git diff --stat, pubspec.lock diff summary)
#
# Usage:   bash run_maintenance.sh [--major] [--dry-run]
#          --major       allow major-version upgrades (monthly sweep)
#          --dry-run     report what would change but don't apply
#
# Safety:  never auto-merges, never force-pushes, never touches secrets.
#          This script produces the diff — a human reviews and merges.
#
# House style: ../../references/CONVENTIONS.md

set -euo pipefail

# --- colours (disabled when not a TTY) ----------------------------------------
if [ -t 1 ]; then
  RED=$'\033[0;31m'; GRN=$'\033[0;32m'; YLW=$'\033[0;33m'
  BLU=$'\033[0;34m'; BLD=$'\033[1m';  RST=$'\033[0m'
else
  RED=""; GRN=""; YLW=""; BLU=""; BLD=""; RST=""
fi

info()  { printf '%s\n' "${BLU}==>${RST} $*"; }
warn()  { printf '%s\n' "${YLW}!! ${RST} $*" >&2; }
fail()  { printf '%s\n' "${RED}xx ${RST} $*" >&2; }
good()  { printf '%s\n' "${GRN}ok ${RST} $*"; }

# --- flags --------------------------------------------------------------------
MAJOR=false
DRY_RUN=false
for arg in "$@"; do
  case "$arg" in
    --major)    MAJOR=true ;;
    --dry-run)  DRY_RUN=true ;;
    *)          fail "Unknown argument: $arg"; exit 2 ;;
  esac
done

# --- 1. Preflight: is this a Flutter project? ---------------------------------
if [ ! -f "pubspec.yaml" ]; then
  fail "No pubspec.yaml found in $(pwd). This is not a Flutter/Dart project root."
  exit 2
fi
good "pubspec.yaml found — Flutter/Dart project confirmed."

if ! command -v flutter >/dev/null 2>&1; then
  fail "'flutter' not on PATH. Install the Flutter SDK and re-run."
  exit 127
fi
good "'flutter' is available."

# --- 2. Capture baseline ------------------------------------------------------
info "Capturing baseline state..."
BASELINE_LOCK_HASH="$(sha256sum pubspec.lock 2>/dev/null | awk '{print $1}' || echo "none")"
BASELINE_ISSUE_COUNT="$(flutter analyze 2>&1 | grep -Eo '[0-9]+ issue(s)? found' | grep -Eo '[0-9]+' | tail -n 1 || echo "0")"

# --- 3. Dependency upgrade ----------------------------------------------------
info "Running flutter pub upgrade..."
if [ "$MAJOR" = true ]; then
  warn "--major flag set: allowing major-version upgrades (monthly sweep)."
  if [ "$DRY_RUN" = false ]; then
    flutter pub upgrade --major-versions
  else
    info "[dry-run] Would run: flutter pub upgrade --major-versions"
  fi
else
  # Default: patch + minor only.  pub upgrade (without --major-versions) stays
  # within the caret / version constraint declared in pubspec.yaml, which by
  # semver convention means only patch and minor bumps for ^x.y.z constraints.
  if [ "$DRY_RUN" = false ]; then
    flutter pub upgrade
  else
    info "[dry-run] Would run: flutter pub upgrade (patch + minor only)"
  fi
fi

# --- 4. Format + bulk auto-fix ------------------------------------------------
if [ "$DRY_RUN" = false ]; then
  info "Running dart format ."
  dart format . >/dev/null 2>&1 || warn "dart format reported differences (this is expected)."

  info "Running dart fix --apply"
  dart fix --apply >/dev/null 2>&1 || warn "dart fix reported lint changes."
else
  info "[dry-run] Would run: dart format . && dart fix --apply"
fi

# --- 5. Analyze gate -----------------------------------------------------------
info "Running flutter analyze..."
if [ "$DRY_RUN" = false ]; then
  set +e
  ANALYZE_OUT="$(flutter analyze 2>&1)"
  ANALYZE_EXIT=$?
  set -e

  AFTER_ISSUE_COUNT="$(printf '%s' "$ANALYZE_OUT" | grep -Eo '[0-9]+ issue(s)? found' | grep -Eo '[0-9]+' | tail -n 1 || echo "0")"
  if [ "$ANALYZE_EXIT" -eq 0 ]; then
    good "flutter analyze: CLEAN (${AFTER_ISSUE_COUNT} issues)."
  else
    warn "flutter analyze: ${AFTER_ISSUE_COUNT} issue(s) found."
    printf '%s\n' "$ANALYZE_OUT" | grep ' • ' | sed 's/^/    /'
  fi
else
  AFTER_ISSUE_COUNT="$BASELINE_ISSUE_COUNT"
  info "[dry-run] Would run: flutter analyze"
fi

# --- 6. Report what changed ---------------------------------------------------
info "--- Maintenance Sweep Report ---"
echo ""

# pubspec.lock diff
if [ "$DRY_RUN" = false ]; then
  AFTER_LOCK_HASH="$(sha256sum pubspec.lock 2>/dev/null | awk '{print $1}' || echo "none")"
  if [ "$BASELINE_LOCK_HASH" != "$AFTER_LOCK_HASH" ]; then
    echo "pubspec.lock CHANGED (dependencies were bumped):"
    echo "  baseline sha256: ${BASELINE_LOCK_HASH}"
    echo "  after    sha256: ${AFTER_LOCK_HASH}"
    echo ""
    echo "Changed packages (top-level deps diff in pubspec.lock):"
    # Extract changed packages: lines that differ between the two lock files
    # showing only sdks + packages sections for readability.
    if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
      git diff -- pubspec.lock 2>/dev/null | grep '^[+-]' | grep -v '^[+-]\{3\}' | head -n 80 || true
    else
      # Not in a git repo; use a simple diff against /dev/null baseline
      # (pub upgrade already printed what it changed to stderr).
      warn "Not in a git repo — cannot produce a diff. Review 'flutter pub upgrade' output above."
    fi
  else
    echo "pubspec.lock UNCHANGED — no new dependency versions available."
  fi
else
  info "[dry-run] pubspec.lock hash was: ${BASELINE_LOCK_HASH}"
fi

echo ""
echo "Analyzer issues:"
echo "  Before: ${BASELINE_ISSUE_COUNT:-unknown}"
echo "  After:  ${AFTER_ISSUE_COUNT:-unknown}"

FIXED=$(( ${BASELINE_ISSUE_COUNT:-0} - ${AFTER_ISSUE_COUNT:-0} ))
if [ "$FIXED" -gt 0 ]; then
  good "dart fix resolved ${FIXED} analyzer issue(s)."
elif [ "$FIXED" -eq 0 ]; then
  good "No new issues introduced."
else
  warn "$(( -FIXED )) new analyzer issue(s) introduced — review the output above."
fi

echo ""
if [ "$DRY_RUN" = true ]; then
  info "Dry-run complete. Re-run without --dry-run to apply changes."
else
  good "Maintenance sweep complete."
  echo "Next: review the diff, commit, push, and open a maintenance PR."
  echo "      DO NOT auto-merge. A human must review before merging."
fi

exit 0
