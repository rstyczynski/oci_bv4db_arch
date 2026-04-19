#!/usr/bin/env bash
# Integration tests for Sprint 9 4 KB redo Oracle-style runs.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SPRINT_DIR="$REPO_ROOT/progress/sprint_9"
PROFILE_FILE="$SPRINT_DIR/oracle-layout-4k-redo.fio"
SINGLE_JSON="$SPRINT_DIR/fio-results-oracle-single-4k-redo-integration.json"
SINGLE_IOSTAT="$SPRINT_DIR/iostat-oracle-single-4k-redo-integration.json"
SINGLE_ANALYSIS="$SPRINT_DIR/fio-analysis-oracle-single-4k-redo-integration.md"
MULTI_JSON="$SPRINT_DIR/fio-results-oracle-multi-4k-redo-integration.json"
MULTI_IOSTAT="$SPRINT_DIR/iostat-oracle-multi-4k-redo-integration.json"
MULTI_ANALYSIS="$SPRINT_DIR/fio-analysis-oracle-multi-4k-redo-integration.md"

PASS=0
FAIL=0

_pass() { echo "  [PASS] $*"; PASS=$((PASS + 1)); }
_fail() { echo "  [FAIL] $*"; FAIL=$((FAIL + 1)); }

test_IT31_profile_uses_4k_redo() {
  echo "=== IT-31: Sprint 9 profile uses 4 KB redo ==="
  [ -f "$PROFILE_FILE" ] || { _fail "IT-31: sprint 9 fio profile missing"; return 1; }
  grep -q '^bs=4k$' "$PROFILE_FILE" || { _fail "IT-31: redo bs=4k not present"; return 1; }
  _pass "IT-31: sprint 9 fio profile uses 4 KB redo"
}

test_IT32_single_and_multi_artifacts_exist() {
  echo "=== IT-32: Sprint 9 artifacts exist for both layouts ==="
  for f in "$SINGLE_JSON" "$SINGLE_IOSTAT" "$SINGLE_ANALYSIS" "$MULTI_JSON" "$MULTI_IOSTAT" "$MULTI_ANALYSIS"; do
    [ -f "$f" ] || { _fail "IT-32: missing artifact $f"; return 1; }
  done
  jq empty "$SINGLE_JSON" >/dev/null 2>&1 || { _fail "IT-32: single fio JSON invalid"; return 1; }
  jq empty "$MULTI_JSON" >/dev/null 2>&1 || { _fail "IT-32: multi fio JSON invalid"; return 1; }
  jq empty "$SINGLE_IOSTAT" >/dev/null 2>&1 || { _fail "IT-32: single iostat JSON invalid"; return 1; }
  jq empty "$MULTI_IOSTAT" >/dev/null 2>&1 || { _fail "IT-32: multi iostat JSON invalid"; return 1; }
  _pass "IT-32: sprint 9 artifacts exist for both layouts"
}

test_IT33_per_job_output_preserved() {
  echo "=== IT-33: Sprint 9 preserves per-job output ==="
  local single_jobs multi_jobs single_redo_bs
  single_jobs=$(jq '.jobs | length' "$SINGLE_JSON")
  multi_jobs=$(jq '.jobs | length' "$MULTI_JSON")
  single_redo_bs=$(jq -r '.jobs[] | select(.jobname=="redo") | .["job options"].bs' "$SINGLE_JSON" | head -n1)
  if [ "$single_jobs" -ge 6 ] && [ "$multi_jobs" -ge 6 ] && [ "$single_redo_bs" = "4k" ]; then
    _pass "IT-33: per-job output preserved with 4 KB redo"
    return 0
  fi
  _fail "IT-33: expected 6+ jobs in both JSON files and redo bs=4k (single_jobs=$single_jobs multi_jobs=$multi_jobs redo_bs=$single_redo_bs)"
  return 1
}

test_IT34_teardown_archived_state() {
  echo "=== IT-34: Sprint 9 teardown archived state files ==="
  local single_deleted multi_deleted single_vol_deleted live_single live_multi
  single_deleted=$(ls -1 "$SPRINT_DIR"/state-bv4db-oracle9-single-run.deleted-*.json 2>/dev/null | wc -l | tr -d ' ')
  multi_deleted=$(ls -1 "$SPRINT_DIR"/state-bv4db-oracle9-multi-run.deleted-*.json 2>/dev/null | wc -l | tr -d ' ')
  single_vol_deleted=$(ls -1 "$SPRINT_DIR"/state-bv-singleuhp.deleted-*.json 2>/dev/null | wc -l | tr -d ' ')
  live_single=$(ls -1 "$SPRINT_DIR"/state-bv4db-oracle9-single-run.json 2>/dev/null | wc -l | tr -d ' ')
  live_multi=$(ls -1 "$SPRINT_DIR"/state-bv4db-oracle9-multi-run.json 2>/dev/null | wc -l | tr -d ' ')
  if [ "$single_deleted" -ge 1 ] && [ "$multi_deleted" -ge 1 ] && [ "$single_vol_deleted" -ge 1 ] && [ "$live_single" -eq 0 ] && [ "$live_multi" -eq 0 ]; then
    _pass "IT-34: sprint 9 teardown archived state files"
    return 0
  fi
  _fail "IT-34: expected archived deleted state files and no live run state"
  return 1
}

echo ""
echo "=== BV4DB Integration Tests — Sprint 9 ==="
echo ""

test_IT31_profile_uses_4k_redo || true
test_IT32_single_and_multi_artifacts_exist || true
test_IT33_per_job_output_preserved || true
test_IT34_teardown_archived_state || true

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
