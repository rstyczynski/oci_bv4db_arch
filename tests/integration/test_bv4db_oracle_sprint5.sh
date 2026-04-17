#!/usr/bin/env bash
# Integration tests for Sprint 5 Oracle-style block volume layout rerun.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SPRINT_DIR="$REPO_ROOT/progress/sprint_5"
PROFILE_FILE="$SPRINT_DIR/oracle-layout.fio"
SMOKE_RESULT_JSON="$SPRINT_DIR/fio-results-oracle-smoke.json"
SMOKE_IOSTAT_JSON="$SPRINT_DIR/iostat-oracle-smoke.json"
SMOKE_ANALYSIS_MD="$SPRINT_DIR/fio-analysis-oracle-smoke.md"
INT_RESULT_JSON="$SPRINT_DIR/fio-results-oracle-integration.json"
INT_IOSTAT_JSON="$SPRINT_DIR/iostat-oracle-integration.json"
INT_ANALYSIS_MD="$SPRINT_DIR/fio-analysis-oracle-integration.md"

PASS=0
FAIL=0

_pass() { echo "  [PASS] $*"; PASS=$((PASS + 1)); }
_fail() { echo "  [FAIL] $*"; FAIL=$((FAIL + 1)); }

test_IT20_corrected_profile_present() {
  echo "=== IT-20: Corrected Sprint 5 fio profile present ==="
  [ -f "$PROFILE_FILE" ] || { _fail "IT-20: oracle-layout.fio not found"; return 1; }
  grep -q '^group_reporting=0$' "$PROFILE_FILE" || { _fail "IT-20: group_reporting=0 not present"; return 1; }
  grep -q '\[data-8k\]' "$PROFILE_FILE" || { _fail "IT-20: data-8k section missing"; return 1; }
  grep -q '\[redo\]' "$PROFILE_FILE" || { _fail "IT-20: redo section missing"; return 1; }
  grep -q '\[fra-1m\]' "$PROFILE_FILE" || { _fail "IT-20: fra-1m section missing"; return 1; }
  _pass "IT-20: corrected Sprint 5 profile present"
}

test_IT21_smoke_per_job_reporting() {
  echo "=== IT-21: Smoke run produces per-job fio output ==="
  [ -f "$SMOKE_RESULT_JSON" ] || { _fail "IT-21: smoke fio JSON missing"; return 1; }
  jq empty "$SMOKE_RESULT_JSON" >/dev/null 2>&1 || { _fail "IT-21: smoke fio JSON invalid"; return 1; }
  local runtime job_count has_data has_redo has_fra
  runtime=$(jq -r '."global options".runtime // empty' "$SMOKE_RESULT_JSON")
  job_count=$(jq '.jobs | length' "$SMOKE_RESULT_JSON")
  has_data=$(jq '[.jobs[] | select(.jobname=="data-8k")] | length' "$SMOKE_RESULT_JSON")
  has_redo=$(jq '[.jobs[] | select(.jobname=="redo")] | length' "$SMOKE_RESULT_JSON")
  has_fra=$(jq '[.jobs[] | select(.jobname=="fra-1m")] | length' "$SMOKE_RESULT_JSON")
  if [ "$runtime" = "60" ] && [ "$job_count" -ge 6 ] && [ "$has_data" -ge 4 ] && [ "$has_redo" -ge 1 ] && [ "$has_fra" -ge 1 ]; then
    _pass "IT-21: smoke fio output contains distinct per-job results"
    return 0
  fi
  _fail "IT-21: expected runtime=60 and per-job records for data/redo/fra, got runtime=$runtime jobs=$job_count data=$has_data redo=$has_redo fra=$has_fra"
  return 1
}

test_IT22_integration_per_job_reporting() {
  echo "=== IT-22: Integration run produces per-job fio output ==="
  [ -f "$INT_RESULT_JSON" ] || { _fail "IT-22: integration fio JSON missing"; return 1; }
  jq empty "$INT_RESULT_JSON" >/dev/null 2>&1 || { _fail "IT-22: integration fio JSON invalid"; return 1; }
  local runtime job_count has_data has_redo has_fra
  runtime=$(jq -r '."global options".runtime // empty' "$INT_RESULT_JSON")
  job_count=$(jq '.jobs | length' "$INT_RESULT_JSON")
  has_data=$(jq '[.jobs[] | select(.jobname=="data-8k")] | length' "$INT_RESULT_JSON")
  has_redo=$(jq '[.jobs[] | select(.jobname=="redo")] | length' "$INT_RESULT_JSON")
  has_fra=$(jq '[.jobs[] | select(.jobname=="fra-1m")] | length' "$INT_RESULT_JSON")
  if [ "$runtime" = "600" ] && [ "$job_count" -ge 6 ] && [ "$has_data" -ge 4 ] && [ "$has_redo" -ge 1 ] && [ "$has_fra" -ge 1 ]; then
    _pass "IT-22: integration fio output contains distinct per-job results"
    return 0
  fi
  _fail "IT-22: expected runtime=600 and per-job records for data/redo/fra, got runtime=$runtime jobs=$job_count data=$has_data redo=$has_redo fra=$has_fra"
  return 1
}

test_IT23_iostat_and_analysis_present() {
  echo "=== IT-23: iostat and analysis artifacts present ==="
  [ -f "$SMOKE_IOSTAT_JSON" ] || { _fail "IT-23: smoke iostat JSON missing"; return 1; }
  [ -f "$INT_IOSTAT_JSON" ] || { _fail "IT-23: integration iostat JSON missing"; return 1; }
  [ -f "$SMOKE_ANALYSIS_MD" ] || { _fail "IT-23: smoke analysis missing"; return 1; }
  [ -f "$INT_ANALYSIS_MD" ] || { _fail "IT-23: integration analysis missing"; return 1; }
  jq empty "$SMOKE_IOSTAT_JSON" >/dev/null 2>&1 || { _fail "IT-23: smoke iostat JSON invalid"; return 1; }
  jq empty "$INT_IOSTAT_JSON" >/dev/null 2>&1 || { _fail "IT-23: integration iostat JSON invalid"; return 1; }
  grep -q 'data-8k' "$INT_ANALYSIS_MD" || { _fail "IT-23: integration analysis missing data-8k section"; return 1; }
  grep -q 'redo' "$INT_ANALYSIS_MD" || { _fail "IT-23: integration analysis missing redo section"; return 1; }
  grep -q 'fra-1m' "$INT_ANALYSIS_MD" || { _fail "IT-23: integration analysis missing fra-1m section"; return 1; }
  _pass "IT-23: iostat and analysis artifacts present"
}

test_IT24_resources_torn_down() {
  echo "=== IT-24: Sprint 5 resources torn down automatically ==="
  local main_deleted volume_deleted live_main
  main_deleted=$(ls -1 "$SPRINT_DIR"/state-bv4db-oracle5-run.deleted-*.json 2>/dev/null | wc -l | tr -d ' ')
  volume_deleted=$(ls -1 "$SPRINT_DIR"/state-bv-*.deleted-*.json 2>/dev/null | wc -l | tr -d ' ')
  live_main=$(ls -1 "$SPRINT_DIR"/state-bv4db-oracle5-run.json 2>/dev/null | wc -l | tr -d ' ')
  if [ "$main_deleted" -ge 1 ] && [ "$volume_deleted" -ge 5 ] && [ "$live_main" -eq 0 ]; then
    _pass "IT-24: Sprint 5 archived deleted state files confirm automatic teardown"
    return 0
  fi
  _fail "IT-24: expected archived deleted state files and no live main state (main_deleted=$main_deleted volume_deleted=$volume_deleted live_main=$live_main)"
  return 1
}

echo ""
echo "=== BV4DB Integration Tests — Sprint 5 ==="
echo ""

test_IT20_corrected_profile_present || true
test_IT21_smoke_per_job_reporting || true
test_IT22_integration_per_job_reporting || true
test_IT23_iostat_and_analysis_present || true
test_IT24_resources_torn_down || true

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
