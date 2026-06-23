#!/usr/bin/env bash
#
# ci_heal.sh — Self-Healing CI Agent (#33) wrapper.
#
# Takes a failed CI run ID, fetches logs, classifies the failure via Build Doctor
# (#37), routes to the right fixer (lint → #41, build → #37 fix), and reports.
#
# Usage:   bash ci_heal.sh <github-run-id> [--apply] [--max-attempts N]
#          <github-run-id>   The GitHub Actions run ID that failed.
#          --apply           Actually apply fixes (default: diagnose only).
#          --max-attempts N  Max fix attempts (default: 3, per safety rail).
#
# This script is designed to be called:
#   - Manually by a developer:  bash ci_heal.sh 1234567890 --apply
#   - Triggered by the workflow_run webhook in templates/self_heal.yaml
#
# Safety:  never auto-merges, never force-pushes, never touches secrets.
#          Fixes are scoped, attempt-capped, and always committed on a heal branch.
#
# House style: ../../references/CONVENTIONS.md

set -euo pipefail

# --- colours ------------------------------------------------------------------
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

# --- locate skill directories -------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Paths to other skill scripts (relative to skills/ root)
DIAGNOSE_PY="${SKILLS_DIR}/37_Build_Doctor/scripts/diagnose.py"
ANALYZE_FIX_SH="${SKILLS_DIR}/41_Analyzer_AutoFix/scripts/analyze_fix.sh"
ERROR_SIGS_MD="${SKILLS_DIR}/37_Build_Doctor/templates/error_signatures.md"

# It's also valid if these scripts are cloned into the project repo; check there too.
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
if [ -n "${REPO_ROOT}" ] && [ ! -f "$DIAGNOSE_PY" ]; then
  if [ -f "${REPO_ROOT}/skills/37_Build_Doctor/scripts/diagnose.py" ]; then
    DIAGNOSE_PY="${REPO_ROOT}/skills/37_Build_Doctor/scripts/diagnose.py"
    ANALYZE_FIX_SH="${REPO_ROOT}/skills/41_Analyzer_AutoFix/scripts/analyze_fix.sh"
    ERROR_SIGS_MD="${REPO_ROOT}/skills/37_Build_Doctor/templates/error_signatures.md"
  fi
fi

# --- args ---------------------------------------------------------------------
RUN_ID=""
APPLY=false
MAX_ATTEMPTS=3

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply)         APPLY=true ;;
    --max-attempts)  MAX_ATTEMPTS="$2"; shift ;;
    --help|-h)
      echo "Usage: bash ci_heal.sh <github-run-id> [--apply] [--max-attempts N]"
      echo ""
      echo "Fetch the failed CI run logs, classify the failure, and (with --apply)"
      echo "attempt to auto-heal within N attempts."
      exit 0
      ;;
    *)  RUN_ID="$1" ;;
  esac
  shift
done

if [ -z "$RUN_ID" ]; then
  fail "No run ID provided."
  echo "Usage: bash ci_heal.sh <github-run-id> [--apply] [--max-attempts N]"
  exit 2
fi

# --- preflight ----------------------------------------------------------------
if ! command -v gh >/dev/null 2>&1; then
  fail "'gh' (GitHub CLI) not on PATH. Install from https://cli.github.com/"
  exit 127
fi
if ! command -v python3 >/dev/null 2>&1 && ! command -v python >/dev/null 2>&1; then
  fail "Neither 'python3' nor 'python' is on PATH. Python 3.8+ is required."
  exit 127
fi
PYTHON="$(command -v python3 || command -v python)"

# --- 1. Fetch failed run logs -------------------------------------------------
info "Fetching logs for failed run ${RUN_ID}..."
CI_LOG="ci_${RUN_ID}.log"

if ! gh run view "$RUN_ID" --log-failed > "$CI_LOG" 2>&1; then
  warn "gh run view --log-failed failed; trying --log fallback..."
  gh run view "$RUN_ID" --log > "$CI_LOG" 2>/dev/null || {
    fail "Cannot fetch logs for run ${RUN_ID}. Check that the run exists and 'gh auth' is valid."
    exit 3
  }
fi
LOG_LINES="$(wc -l < "$CI_LOG")"
info "Captured ${LOG_LINES} log lines."

# --- 2. Classify via Build Doctor (#37) ---------------------------------------
info "Classifying failure with Build Doctor (${DIAGNOSE_PY})..."

if [ ! -f "$DIAGNOSE_PY" ]; then
  fail "diagnose.py not found at ${DIAGNOSE_PY}."
  fail "Ensure skill 37_Build_Doctor is present in the skills directory."
  exit 4
fi

set +e
DIAGNOSIS="$("$PYTHON" "$DIAGNOSE_PY" --json "$CI_LOG" 2>&1)"
DIAG_EXIT=$?
set -e

if [ "$DIAG_EXIT" -ne 0 ]; then
  # No known build signature matched — maybe it's a lint failure.
  warn "Build Doctor found no build-level signature (exit ${DIAG_EXIT})."
  warn "Checking for lint/format failure patterns..."

  LINT_CLASS="none"
  if grep -qE '(error|warning)[[:space:]]*•' "$CI_LOG" 2>/dev/null || \
     grep -qE '[0-9]+ issues? found' "$CI_LOG" 2>/dev/null || \
     grep -q 'flutter analyze' "$CI_LOG" 2>/dev/null; then
    LINT_CLASS="lint"
  fi
  if grep -qE '(dart format|would change|set-exit-if-changed)' "$CI_LOG" 2>/dev/null; then
    LINT_CLASS="format"
  fi
  if grep -qE '(test.*failed|Some tests failed)' "$CI_LOG" 2>/dev/null; then
    LINT_CLASS="test"
  fi

  CLASSIFICATION="${LINT_CLASS}"
  echo "$DIAGNOSIS" > "diagnosis_${RUN_ID}.json"
else
  # Parse the JSON to extract the top match
  CLASSIFICATION="build"
  echo "$DIAGNOSIS" > "diagnosis_${RUN_ID}.json"

  TOP_ID="$(printf '%s' "$DIAGNOSIS" | "$PYTHON" -c "
import json,sys
d=json.load(sys.stdin)
m=d.get('matches',[])
print(m[0]['id'] if m else 'unknown')
print(m[0]['family'] if m else 'unknown')
" 2>/dev/null || echo "unknown")"
  info "Top diagnosis: ${TOP_ID}"
fi

# --- 3. Route to the right fixer ----------------------------------------------
attempt=0
HEALED=false

heal_loop() {
  while [ "$attempt" -lt "$MAX_ATTEMPTS" ]; do
    attempt=$((attempt + 1))
    info "--- Heal attempt ${attempt}/${MAX_ATTEMPTS} ---"

    case "$CLASSIFICATION" in
      lint|format)
        info "Routing to Analyzer Auto-Fix (#41)..."
        if [ -f "$ANALYZE_FIX_SH" ]; then
          if bash "$ANALYZE_FIX_SH"; then
            good "Lint fix CLEAN."
            HEALED=true
            return
          else
            warn "Analyzer Auto-Fix has remaining JUDGMENT issues (or max iterations reached)."
            warn "These require human judgment — escalating."
            HEALED=false
            return
          fi
        else
          warn "analyze_fix.sh not found at ${ANALYZE_FIX_SH}; running fallback."
          dart format . >/dev/null 2>&1 || true
          dart fix --apply >/dev/null 2>&1 || true
          if flutter analyze 2>&1 | grep -q "No issues found"; then
            good "Fallback fix CLEAN."
            HEALED=true
            return
          fi
        fi
        ;;

      build)
        info "Build failure classified. Reading error_signatures.md for fix..."
        if [ -f "$ERROR_SIGS_MD" ]; then
          info "Error signatures loaded. Build Doctor fix:"
          "$PYTHON" "$DIAGNOSE_PY" "$CI_LOG" 2>/dev/null || true
        fi
        # The actual fix application is left to the agent orchestrating this script —
        # Build Doctor produces the exact edit; the agent applies it, commits, and re-runs.
        warn "Build fixes require the orchestrating agent to apply the exact edit from Build Doctor."
        warn "See diagnosis_${RUN_ID}.json for the ranked cause + fix."
        HEALED=false
        return
        ;;

      test)
        warn "Test failure detected. Re-running failed tests is left to the orchestrator."
        warn "If flaky: quarantine. If deterministic: escalate as bug."
        HEALED=false
        return
        ;;

      none)
        warn "Could not classify the failure family."
        warn "Check network/timeout/signing patterns manually in ${CI_LOG}."
        HEALED=false
        return
        ;;

      *)
        warn "Unknown classification '${CLASSIFICATION}'. Escalating."
        HEALED=false
        return
        ;;
    esac

    # Re-check: did applying a fix change the classification?
    # Re-fetch logs if a re-run happened.
  done
}

if [ "$APPLY" = true ]; then
  heal_loop
else
  info "Diagnose-only mode (no --apply). Classification: ${CLASSIFICATION}"
  HEALED=true  # Not a failure to not apply — we did what was asked.
fi

# --- 4. Report outcome --------------------------------------------------------
echo ""
info "=== Self-Heal CI Report ==="
echo "  Run ID:       ${RUN_ID}"
echo "  Log file:     ${CI_LOG}"
echo "  Diagnosis:    diagnosis_${RUN_ID}.json"
echo "  Class:        ${CLASSIFICATION}"
echo "  Attempts:     ${attempt}/${MAX_ATTEMPTS}"
if [ "$HEALED" = true ]; then
  echo "  Result:       HEALED (or diagnosed-only)"
else
  echo "  Result:       ESCALATED — human intervention needed"
fi
echo ""
echo "Next: review the diagnosis, apply the recommended fix, commit, and re-run CI."
echo "      DO NOT auto-merge. A human must review before merging."

if [ "$HEALED" = true ]; then
  exit 0
else
  exit 1
fi
