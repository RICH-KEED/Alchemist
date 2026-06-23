#!/usr/bin/env bash
#
# analyze_fix.sh — drive `flutter analyze` toward ZERO under very_good_analysis.
#
# Pipeline:  dart format .  ->  dart fix --apply  ->  loop { analyze; dart fix } up to N
# Reports a colorized before/after issue count and exits non-zero if issues remain,
# so it doubles as a CI lint gate.
#
# Usage:   bash analyze_fix.sh [MAX_ITERATIONS]   (default 5)
#
# House style: ../../references/CONVENTIONS.md §7 (Definition of Done = analyze clean).
# Invoked by Analyzer Auto-Fix Loop (#41); reused by Maintenance (#32) and Self-Healing CI (#33).

set -u

# --- config -----------------------------------------------------------------
MAX_ITERS="${1:-5}"

# --- colors (disabled when not a TTY, e.g. CI logs) -------------------------
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

# --- preflight: tools must exist --------------------------------------------
have() { command -v "$1" >/dev/null 2>&1; }

if ! have flutter && ! have dart; then
  fail "Neither 'flutter' nor 'dart' is on PATH."
  fail "Install the Flutter SDK and ensure 'flutter'/'dart' are available, then re-run."
  exit 127
fi

# Prefer `flutter analyze`; fall back to `dart analyze` for pure-Dart packages.
if have flutter; then
  ANALYZE="flutter analyze"
elif have dart; then
  warn "'flutter' not found; using 'dart analyze' instead."
  ANALYZE="dart analyze"
fi

if ! have dart; then
  warn "'dart' not on PATH — cannot run 'dart format'/'dart fix'. Analyze-only mode."
  CAN_FIX=0
else
  CAN_FIX=1
fi

# Must be run from a Dart/Flutter package root.
if [ ! -f "pubspec.yaml" ]; then
  fail "No pubspec.yaml in $(pwd). Run this from the package (or app) root."
  exit 2
fi

# --- helper: count analyzer issues ------------------------------------------
# Echoes a single integer: the number of issues the analyzer reports.
# Stores the raw analyzer output in $LAST_ANALYZE for the caller to inspect.
LAST_ANALYZE=""
count_issues() {
  LAST_ANALYZE="$($ANALYZE 2>&1)"
  if printf '%s' "$LAST_ANALYZE" | grep -q "No issues found"; then
    echo 0
    return 0
  fi
  # very_good/flutter prints "N issue(s) found." — grab that N.
  local n
  n="$(printf '%s' "$LAST_ANALYZE" \
        | grep -Eo '[0-9]+ issue(s)? found' \
        | grep -Eo '[0-9]+' \
        | tail -n 1)"
  if [ -z "$n" ]; then
    # No summary line — count the bullet lines (" • " separates the fields).
    n="$(printf '%s' "$LAST_ANALYZE" | grep -c ' • ')"
  fi
  echo "${n:-0}"
}

# --- helper: severity breakdown from last analyze output --------------------
sev_breakdown() {
  local out="$1" e w i
  e="$(printf '%s' "$out" | grep -cE '^[[:space:]]*error ')"
  w="$(printf '%s' "$out" | grep -cE '^[[:space:]]*warning ')"
  i="$(printf '%s' "$out" | grep -cE '^[[:space:]]*info ')"
  printf 'error=%s warning=%s info=%s' "$e" "$w" "$i"
}

printf '%s\n' "${BLD}=== Analyzer Auto-Fix Loop (max ${MAX_ITERS} iterations) ===${RST}"

# --- baseline ---------------------------------------------------------------
info "Baseline analyze..."
BEFORE="$(count_issues)"
BEFORE_SEV="$(sev_breakdown "$LAST_ANALYZE")"
info "Before: ${BLD}${BEFORE}${RST} issues  (${BEFORE_SEV})"

# --- format + first bulk fix ------------------------------------------------
if [ "$CAN_FIX" -eq 1 ]; then
  info "dart format ."
  dart format . >/dev/null 2>&1 || warn "dart format reported a problem (continuing)."
  info "dart fix --apply"
  dart fix --apply >/dev/null 2>&1 || warn "dart fix reported a problem (continuing)."
else
  warn "Skipping format/fix (dart unavailable) — running analyze only."
fi

# --- loop -------------------------------------------------------------------
ITER=0
AFTER="$BEFORE"
PREV="$BEFORE"
while [ "$ITER" -lt "$MAX_ITERS" ]; do
  ITER=$((ITER + 1))
  AFTER="$(count_issues)"
  info "Iteration ${ITER}: ${AFTER} issues remaining."

  if [ "$AFTER" -eq 0 ]; then
    break
  fi

  if [ "$CAN_FIX" -eq 0 ]; then
    warn "Cannot auto-fix without 'dart'; stopping loop."
    break
  fi

  # Progress check: if a prior fix pass did not reduce the count, stop —
  # what's left is not automatable (escapes infinite loops).
  if [ "$ITER" -gt 1 ] && [ "$AFTER" -ge "$PREV" ]; then
    warn "No further progress (${PREV} -> ${AFTER}); remaining issues need human judgment."
    break
  fi
  PREV="$AFTER"

  info "dart fix --apply (pass ${ITER})"
  dart fix --apply >/dev/null 2>&1 || warn "dart fix reported a problem (continuing)."
done

# --- final recount + report -------------------------------------------------
AFTER="$(count_issues)"
AFTER_SEV="$(sev_breakdown "$LAST_ANALYZE")"
FIXED=$((BEFORE - AFTER))
[ "$FIXED" -lt 0 ] && FIXED=0

printf '%s\n' "${BLD}=== Result ===${RST}"
printf 'Before : %s issues  (%s)\n' "$BEFORE" "$BEFORE_SEV"
printf 'After  : %s issues  (%s)\n' "$AFTER" "$AFTER_SEV"
printf 'Fixed  : %s%s%s\n' "${GRN}" "$FIXED" "${RST}"

if [ "$AFTER" -eq 0 ]; then
  good "CLEAN — analyzer reports zero issues. §7 Definition of Done satisfied."
  exit 0
fi

fail "${AFTER} issue(s) remain — likely require human judgment."
fail "Remaining (severity • message • location • rule):"
# Show the bullet lines so the human sees exactly what to act on.
printf '%s\n' "$LAST_ANALYZE" | grep ' • ' | sed 's/^/    /'
fail "Categorize these via templates/lint_playbook.md and resolve the JUDGMENT ones."
exit 1
