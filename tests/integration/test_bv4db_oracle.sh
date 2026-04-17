#!/usr/bin/env bash
# Integration tests for Sprint 4 Oracle-style block volume layout.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SPRINT_DIR="$REPO_ROOT/progress/sprint_4"
PROFILE_FILE="$SPRINT_DIR/oracle-layout.fio"
RESULT_JSON="$SPRINT_DIR/fio-results-oracle-smoke.json"
IOSTAT_JSON="$SPRINT_DIR/iostat-oracle-smoke.json"
ANALYSIS_MD="$SPRINT_DIR/fio-analysis-oracle-smoke.md"

PASS=0
FAIL=0

_pass() { echo "  [PASS] $*"; PASS=$((PASS + 1)); }
_fail() { echo "  [FAIL] $*"; FAIL=$((FAIL + 1)); }

latest_state() {
  ls -1t "$SPRINT_DIR"/state-bv4db-oracle-run*.json 2>/dev/null | head -n 1
}

test_IT14_oracle_profile_present() {
  echo "=== IT-14: Oracle fio profile file present ==="
  [ -f "$PROFILE_FILE" ] || { _fail "IT-14: oracle-layout.fio not found"; return 1; }
  local has_data has_redo has_fra
  has_data=$(grep -c '\[data-8k\]' "$PROFILE_FILE" || echo 0)
  has_redo=$(grep -c '\[redo\]' "$PROFILE_FILE" || echo 0)
  has_fra=$(grep -c '\[fra-1m\]' "$PROFILE_FILE" || echo 0)
  if [ "$has_data" -ge 1 ] && [ "$has_redo" -ge 1 ] && [ "$has_fra" -ge 1 ]; then
    _pass "IT-14: Oracle fio profile has all three job sections"
    return 0
  fi
  _fail "IT-14: fio profile missing job sections (data=$has_data, redo=$has_redo, fra=$has_fra)"
  return 1
}

test_IT15_smoke_run_completed() {
  echo "=== IT-15: Smoke run completed on Oracle layout ==="
  [ -f "$RESULT_JSON" ] || { _fail "IT-15: fio-results-oracle-smoke.json not found"; return 1; }
  jq empty "$RESULT_JSON" >/dev/null 2>&1 || { _fail "IT-15: result JSON is invalid"; return 1; }
  # TODO: implement — verify runtime=60 and three jobs completed
  local job_count
  job_count=$(jq '.jobs | length' "$RESULT_JSON")
  if [ "$job_count" -ge 3 ]; then
    _pass "IT-15: Oracle smoke run completed with $job_count jobs"
    return 0
  fi
  _fail "IT-15: expected 3+ jobs, got $job_count"
  return 1
}

test_IT16_iostat_captured() {
  echo "=== IT-16: Device utilization captured ==="
  [ -f "$IOSTAT_JSON" ] || { _fail "IT-16: iostat-oracle-smoke.json not found"; return 1; }
  jq empty "$IOSTAT_JSON" >/dev/null 2>&1 || { _fail "IT-16: iostat JSON is invalid"; return 1; }
  _pass "IT-16: iostat JSON captured"
  return 0
}

test_IT17_io_isolation_validated() {
  echo "=== IT-17: I/O isolation validated ==="
  [ -f "$IOSTAT_JSON" ] || { _fail "IT-17: iostat JSON not found"; return 1; }
  # TODO: implement — verify I/O on expected dm-*/mpath devices
  # For now, check that iostat has disk statistics
  local has_disks
  has_disks=$(jq '.sysstat.hosts[0].statistics | length' "$IOSTAT_JSON" 2>/dev/null || echo 0)
  if [ "$has_disks" -ge 1 ]; then
    _pass "IT-17: iostat shows disk statistics (detailed validation pending)"
    return 0
  fi
  _fail "IT-17: no disk statistics in iostat output"
  return 1
}

test_IT18_resources_torn_down() {
  echo "=== IT-18: Resources torn down automatically ==="
  local state
  state="$(latest_state)"
  [ -n "$state" ] || { _fail "IT-18: no archived state file found"; return 1; }
  local compute_deleted
  compute_deleted=$(jq -r '.compute.deleted // empty' "$state")
  if [[ "$state" == *.deleted-* ]] && [ "$compute_deleted" = "true" ]; then
    _pass "IT-18: Sprint 4 archived state indicates automatic teardown"
    return 0
  fi
  _fail "IT-18: expected deleted archived state, got state=$state compute.deleted=$compute_deleted"
  return 1
}

echo ""
echo "=== BV4DB Integration Tests — Sprint 4 ==="
echo ""

test_IT14_oracle_profile_present || true
test_IT15_smoke_run_completed || true
test_IT16_iostat_captured || true
test_IT17_io_isolation_validated || true
test_IT18_resources_torn_down || true

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
