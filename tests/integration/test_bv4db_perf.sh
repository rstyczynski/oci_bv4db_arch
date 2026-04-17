#!/usr/bin/env bash
# Integration tests for Sprint 2 high-performance block volume benchmark.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SPRINT_DIR="$REPO_ROOT/progress/sprint_2"
FIO_RESULTS="$SPRINT_DIR/fio-results-perf.json"
FIO_SEQ_RESULTS="$SPRINT_DIR/fio-results-perf-sequential.json"
FIO_RAND_RESULTS="$SPRINT_DIR/fio-results-perf-random.json"
FIO_ANALYSIS="$SPRINT_DIR/fio_analysis.md"

PASS=0
FAIL=0

_pass() { echo "  [PASS] $*"; PASS=$((PASS + 1)); }
_fail() { echo "  [FAIL] $*"; FAIL=$((FAIL + 1)); }

latest_state() {
  ls -1t "$SPRINT_DIR"/state-bv4db-perf-run*.json 2>/dev/null | head -n 1
}

test_IT5_perf_compute_provisioned() {
  echo "=== IT-5: Maximum-performance compute instance provisioned ==="
  local state
  state="$(latest_state)"
  [ -n "$state" ] || { _fail "IT-5: no Sprint 2 state file found"; return 1; }
  local shape ocpus
  shape=$(jq -r '.inputs.compute_shape // empty' "$state")
  ocpus=$(jq -r '.inputs.compute_ocpus // empty' "$state")
  [ "$shape" = "VM.Standard.E5.Flex" ] && [ "$ocpus" = "40" ] && \
    _pass "IT-5: Sprint 2 benchmark compute recorded as VM.Standard.E5.Flex with 40 OCPUs" && return 0
  _fail "IT-5: unexpected compute configuration shape=$shape ocpus=$ocpus"
  return 1
}

test_IT6_uhp_volume_attached() {
  echo "=== IT-6: Ultra High Performance block volume attached ==="
  local state
  state="$(latest_state)"
  [ -n "$state" ] || { _fail "IT-6: no Sprint 2 state file found"; return 1; }
  local vpu is_multipath
  vpu=$(jq -r '.blockvolume.vpus_per_gb // empty' "$state")
  is_multipath=$(jq -r '.blockvolume.is_multipath // empty' "$state")
  [ "$vpu" = "120" ] && [ "$is_multipath" = "true" ] && \
    _pass "IT-6: UHP volume recorded with 120 VPUs/GB and multipath-enabled attachment" && return 0
  _fail "IT-6: unexpected UHP configuration vpus_per_gb=$vpu is_multipath=$is_multipath"
  return 1
}

test_IT7_60s_benchmark_completed() {
  echo "=== IT-7: 60-second fio benchmark completed ==="
  [ -f "$FIO_RESULTS" ] || { _fail "IT-7: fio-results-perf.json not found"; return 1; }
  jq empty "$FIO_RESULTS" >/dev/null 2>&1 || { _fail "IT-7: fio-results-perf.json is invalid"; return 1; }
  local seq rand total
  seq=$(jq -r '.sequential.jobs[0]."job options".runtime // empty' "$FIO_RESULTS")
  rand=$(jq -r '.random.jobs[0]."job options".runtime // empty' "$FIO_RESULTS")
  total=$((seq + rand))
  [ "$total" -eq 60 ] && _pass "IT-7: fio runtime totals 60 seconds" && return 0
  _fail "IT-7: expected total runtime 60 seconds, got $total"
  return 1
}

test_IT8_analysis_written() {
  echo "=== IT-8: per-workload fio artifacts and analysis written ==="
  [ -f "$FIO_SEQ_RESULTS" ] || { _fail "IT-8: fio-results-perf-sequential.json not found"; return 1; }
  [ -f "$FIO_RAND_RESULTS" ] || { _fail "IT-8: fio-results-perf-random.json not found"; return 1; }
  [ -f "$FIO_ANALYSIS" ] || { _fail "IT-8: fio_analysis.md not found"; return 1; }
  jq empty "$FIO_SEQ_RESULTS" >/dev/null 2>&1 || { _fail "IT-8: fio-results-perf-sequential.json is invalid"; return 1; }
  jq empty "$FIO_RAND_RESULTS" >/dev/null 2>&1 || { _fail "IT-8: fio-results-perf-random.json is invalid"; return 1; }
  grep -q "Measured Results" "$FIO_ANALYSIS" && grep -q "Comparison to Sprint 1" "$FIO_ANALYSIS" && \
    _pass "IT-8: Sprint 2 per-workload artifacts and analysis created" && return 0
  _fail "IT-8: analysis file missing expected sections"
  return 1
}

test_IT9_resources_torn_down() {
  echo "=== IT-9: Benchmark resources torn down automatically ==="
  local state
  state="$(latest_state)"
  [ -n "$state" ] || { _fail "IT-9: no Sprint 2 archived state file found"; return 1; }
  local bv_deleted
  bv_deleted=$(jq -r '.blockvolume.deleted // empty' "$state")
  if [[ "$state" == *.deleted-* ]] && [ "$bv_deleted" = "true" ]; then
    _pass "IT-9: Sprint 2 archived state indicates automatic teardown"
    return 0
  fi
  _fail "IT-9: expected deleted archived state, got state=$state blockvolume.deleted=$bv_deleted"
  return 1
}

run_all() {
  echo ""
  echo "=== BV4DB Integration Tests — Sprint 2 ==="
  echo ""

  test_IT5_perf_compute_provisioned || true
  test_IT6_uhp_volume_attached || true
  test_IT7_60s_benchmark_completed || true
  test_IT8_analysis_written || true
  test_IT9_resources_torn_down || true

  echo ""
  echo "Results: $PASS passed, $FAIL failed"
  [[ $FAIL -eq 0 ]]
}

run_all
