#!/usr/bin/env bash
# Integration tests for Sprint 3 mixed-8k smoke benchmark.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SPRINT_DIR="$REPO_ROOT/progress/sprint_3"
PROFILE_FILE="$SPRINT_DIR/mixed-8k.fio"
RESULT_JSON="$SPRINT_DIR/fio-results-mixed8k-smoke.json"
ANALYSIS_MD="$SPRINT_DIR/fio-analysis-mixed8k-smoke.md"

PASS=0
FAIL=0

_pass() { echo "  [PASS] $*"; PASS=$((PASS + 1)); }
_fail() { echo "  [FAIL] $*"; FAIL=$((FAIL + 1)); }

latest_state() {
  ls -1t "$SPRINT_DIR"/state-bv4db-mixed8k-run*.json 2>/dev/null | head -n 1
}

test_IT10_profile_file_present() {
  echo "=== IT-10: mixed 8k fio profile file present ==="
  [ -f "$PROFILE_FILE" ] || { _fail "IT-10: mixed-8k.fio not found"; return 1; }
  grep -q '\[mixed-8k\]' "$PROFILE_FILE" && grep -q 'rwmixread=70' "$PROFILE_FILE" && \
    _pass "IT-10: mixed-8k fio profile file present" && return 0
  _fail "IT-10: fio profile content missing expected mixed-8k settings"
  return 1
}

test_IT11_smoke_run_completed() {
  echo "=== IT-11: smoke run completed on Sprint 2 topology ==="
  [ -f "$RESULT_JSON" ] || { _fail "IT-11: fio-results-mixed8k-smoke.json not found"; return 1; }
  jq empty "$RESULT_JSON" >/dev/null 2>&1 || { _fail "IT-11: result JSON is invalid"; return 1; }
  local runtime
  runtime=$(jq -r '."global options".runtime // .jobs[0]."job options".runtime // empty' "$RESULT_JSON")
  [ "$runtime" = "60" ] && _pass "IT-11: mixed-8k smoke runtime is 60 seconds" && return 0
  _fail "IT-11: expected runtime 60 seconds, got $runtime"
  return 1
}

test_IT12_smoke_analysis_written() {
  echo "=== IT-12: smoke analysis written ==="
  [ -f "$ANALYSIS_MD" ] || { _fail "IT-12: smoke analysis file not found"; return 1; }
  grep -q "Measured Results" "$ANALYSIS_MD" && \
    _pass "IT-12: smoke analysis created" && return 0
  _fail "IT-12: smoke analysis missing expected sections"
  return 1
}

test_IT13_smoke_resources_torn_down() {
  echo "=== IT-13: smoke resources torn down automatically ==="
  local state
  state="$(latest_state)"
  [ -n "$state" ] || { _fail "IT-13: no archived state file found"; return 1; }
  local bv_deleted
  bv_deleted=$(jq -r '.blockvolume.deleted // empty' "$state")
  if [[ "$state" == *.deleted-* ]] && [ "$bv_deleted" = "true" ]; then
    _pass "IT-13: Sprint 3 archived state indicates automatic teardown"
    return 0
  fi
  _fail "IT-13: expected deleted archived state, got state=$state blockvolume.deleted=$bv_deleted"
  return 1
}

echo ""
echo "=== BV4DB Integration Tests — Sprint 3 ==="
echo ""

test_IT10_profile_file_present || true
test_IT11_smoke_run_completed || true
test_IT12_smoke_analysis_written || true
test_IT13_smoke_resources_torn_down || true

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
