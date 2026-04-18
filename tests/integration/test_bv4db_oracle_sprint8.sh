#!/usr/bin/env bash
# Integration tests for Sprint 8 single-UHP-volume Oracle-style comparison run.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SPRINT_DIR="$REPO_ROOT/progress/sprint_8"
PROFILE_FILE="$REPO_ROOT/progress/sprint_5/oracle-layout.fio"
INT_RESULT_JSON="$SPRINT_DIR/fio-results-oracle-integration.json"
INT_IOSTAT_JSON="$SPRINT_DIR/iostat-oracle-integration.json"
INT_ANALYSIS_MD="$SPRINT_DIR/fio-analysis-oracle-integration.md"

PASS=0
FAIL=0

_pass() { echo "  [PASS] $*"; PASS=$((PASS + 1)); }
_fail() { echo "  [FAIL] $*"; FAIL=$((FAIL + 1)); }

test_IT27_profile_reused() {
  echo "=== IT-27: Sprint 8 reuses Sprint 5 fio profile ==="
  [ -f "$PROFILE_FILE" ] || { _fail "IT-27: Sprint 5 oracle-layout.fio not found"; return 1; }
  grep -q '^group_reporting=0$' "$PROFILE_FILE" || { _fail "IT-27: group_reporting=0 not present"; return 1; }
  grep -q '\[data-8k\]' "$PROFILE_FILE" || { _fail "IT-27: data-8k section missing"; return 1; }
  grep -q '\[redo\]' "$PROFILE_FILE" || { _fail "IT-27: redo section missing"; return 1; }
  grep -q '\[fra-1m\]' "$PROFILE_FILE" || { _fail "IT-27: fra-1m section missing"; return 1; }
  _pass "IT-27: Sprint 8 reuses the Sprint 5 fio profile"
}

test_IT28_integration_results_present() {
  echo "=== IT-28: Sprint 8 integration artifacts present ==="
  [ -f "$INT_RESULT_JSON" ] || { _fail "IT-28: integration fio JSON missing"; return 1; }
  [ -f "$INT_IOSTAT_JSON" ] || { _fail "IT-28: integration iostat JSON missing"; return 1; }
  [ -f "$INT_ANALYSIS_MD" ] || { _fail "IT-28: integration analysis missing"; return 1; }
  jq empty "$INT_RESULT_JSON" >/dev/null 2>&1 || { _fail "IT-28: integration fio JSON invalid"; return 1; }
  jq empty "$INT_IOSTAT_JSON" >/dev/null 2>&1 || { _fail "IT-28: integration iostat JSON invalid"; return 1; }
  _pass "IT-28: Sprint 8 integration artifacts present"
}

test_IT29_per_job_results_preserved() {
  echo "=== IT-29: Sprint 8 preserves per-job fio output ==="
  [ -f "$INT_RESULT_JSON" ] || { _fail "IT-29: integration fio JSON missing"; return 1; }
  local runtime job_count has_data has_redo has_fra
  runtime=$(jq -r '."global options".runtime // empty' "$INT_RESULT_JSON")
  job_count=$(jq '.jobs | length' "$INT_RESULT_JSON")
  has_data=$(jq '[.jobs[] | select(.jobname=="data-8k")] | length' "$INT_RESULT_JSON")
  has_redo=$(jq '[.jobs[] | select(.jobname=="redo")] | length' "$INT_RESULT_JSON")
  has_fra=$(jq '[.jobs[] | select(.jobname=="fra-1m")] | length' "$INT_RESULT_JSON")
  if [ "$runtime" = "600" ] && [ "$job_count" -ge 6 ] && [ "$has_data" -ge 4 ] && [ "$has_redo" -ge 1 ] && [ "$has_fra" -ge 1 ]; then
    _pass "IT-29: per-job fio output preserved"
    return 0
  fi
  _fail "IT-29: expected runtime=600 and per-job records for data/redo/fra, got runtime=$runtime jobs=$job_count data=$has_data redo=$has_redo fra=$has_fra"
  return 1
}

test_IT30_single_uhp_analysis_and_teardown() {
  echo "=== IT-30: Sprint 8 documents single-UHP layout and tears resources down ==="
  grep -qi 'single UHP block volume' "$INT_ANALYSIS_MD" || { _fail "IT-30: analysis does not describe single UHP layout"; return 1; }
  local main_deleted volume_deleted live_main
  main_deleted=$(ls -1 "$SPRINT_DIR"/state-bv4db-oracle8-run.deleted-*.json 2>/dev/null | wc -l | tr -d ' ')
  volume_deleted=$(ls -1 "$SPRINT_DIR"/state-bv-singleuhp.deleted-*.json 2>/dev/null | wc -l | tr -d ' ')
  live_main=$(ls -1 "$SPRINT_DIR"/state-bv4db-oracle8-run.json 2>/dev/null | wc -l | tr -d ' ')
  if [ "$main_deleted" -ge 1 ] && [ "$volume_deleted" -ge 1 ] && [ "$live_main" -eq 0 ]; then
    _pass "IT-30: Sprint 8 teardown archived deleted state files"
    return 0
  fi
  _fail "IT-30: expected archived deleted state files and no live main state (main_deleted=$main_deleted volume_deleted=$volume_deleted live_main=$live_main)"
  return 1
}

echo ""
echo "=== BV4DB Integration Tests — Sprint 8 ==="
echo ""

test_IT27_profile_reused || true
test_IT28_integration_results_present || true
test_IT29_per_job_results_preserved || true
test_IT30_single_uhp_analysis_and_teardown || true

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
