#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SPRINT_DIR="$REPO_ROOT/progress/sprint_14"
PASS=0
FAIL=0
_pass(){ echo "  [PASS] $*"; PASS=$((PASS+1)); }
_fail(){ echo "  [FAIL] $*"; FAIL=$((FAIL+1)); }
require_file(){ [ -f "$1" ] || { _fail "missing $1"; return 1; }; }

test_IT53_sprint14_design_docs_exist() {
  echo "=== IT-53: Sprint 14 design documentation exists ==="
  require_file "$SPRINT_DIR/sprint_14_design.md" || return 1
  require_file "$SPRINT_DIR/sprint_14_implementation.md" || return 1
  require_file "$SPRINT_DIR/sprint_14_tests.md" || return 1
  require_file "$SPRINT_DIR/sprint14_manual.md" || return 1
  grep -q 'BV4DB-36' "$SPRINT_DIR/sprint_14_design.md" || { _fail "design missing BV4DB-36 reference"; return 1; }
  grep -q 'BV4DB-38' "$SPRINT_DIR/sprint_14_design.md" || { _fail "design missing BV4DB-38 reference"; return 1; }
  grep -q 'BV4DB-39' "$SPRINT_DIR/sprint_14_design.md" || { _fail "design missing BV4DB-39 reference"; return 1; }
  _pass "IT-53: sprint 14 design documentation exists"
}

test_IT54_sprint14_workload_results_exist() {
  echo "=== IT-54: Sprint 14 workload results exist ==="
  require_file "$SPRINT_DIR/workload_results.log" || return 1
  grep -q 'Workload' "$SPRINT_DIR/workload_results.log" || { _fail "workload log missing expected content"; return 1; }
  _pass "IT-54: workload results exist"
}

test_IT55_sprint14_awr_snapshots_captured() {
  echo "=== IT-55: Sprint 14 AWR snapshots captured ==="
  require_file "$SPRINT_DIR/awr_begin_snap_id.txt" || return 1
  require_file "$SPRINT_DIR/awr_end_snap_id.txt" || return 1
  BEGIN_ID=$(cat "$SPRINT_DIR/awr_begin_snap_id.txt" | tr -d '[:space:]')
  END_ID=$(cat "$SPRINT_DIR/awr_end_snap_id.txt" | tr -d '[:space:]')
  [ -n "$BEGIN_ID" ] || { _fail "begin snapshot ID is empty"; return 1; }
  [ -n "$END_ID" ] || { _fail "end snapshot ID is empty"; return 1; }
  [ "$END_ID" -gt "$BEGIN_ID" ] || { _fail "end snapshot should be greater than begin"; return 1; }
  _pass "IT-55: AWR snapshots captured (begin=$BEGIN_ID, end=$END_ID)"
}

test_IT56_sprint14_awr_report_generated() {
  echo "=== IT-56: Sprint 14 AWR report generated ==="
  require_file "$SPRINT_DIR/awr_report.html" || return 1
  grep -qi 'AWR\|Workload Repository' "$SPRINT_DIR/awr_report.html" || { _fail "AWR report missing expected content"; return 1; }
  _pass "IT-56: AWR report generated"
}

test_IT57_sprint14_summary_exists() {
  echo "=== IT-57: Sprint 14 summary report exists ==="
  require_file "$SPRINT_DIR/sprint_14_summary.md" || return 1
  grep -q 'Benchmark Window' "$SPRINT_DIR/sprint_14_summary.md" || { _fail "summary missing benchmark window section"; return 1; }
  grep -q 'AWR Snapshots' "$SPRINT_DIR/sprint_14_summary.md" || { _fail "summary missing AWR snapshots section"; return 1; }
  _pass "IT-57: sprint 14 summary report exists"
}

test_IT58_sprint14_scripts_executable() {
  echo "=== IT-58: Sprint 14 scripts are executable ==="
  [ -x "$REPO_ROOT/tools/run_oracle_db_sprint14.sh" ] || { _fail "run_oracle_db_sprint14.sh not executable"; return 1; }
  [ -x "$REPO_ROOT/tools/run_oracle_workload.sh" ] || { _fail "run_oracle_workload.sh not executable"; return 1; }
  [ -x "$REPO_ROOT/tools/capture_awr_snapshot.sh" ] || { _fail "capture_awr_snapshot.sh not executable"; return 1; }
  [ -x "$REPO_ROOT/tools/export_awr_report.sh" ] || { _fail "export_awr_report.sh not executable"; return 1; }
  _pass "IT-58: sprint 14 scripts are executable"
}

echo ""
echo "=== BV4DB Integration Tests — Sprint 14 ==="
echo ""
test_IT53_sprint14_design_docs_exist || true
test_IT54_sprint14_workload_results_exist || true
test_IT55_sprint14_awr_snapshots_captured || true
test_IT56_sprint14_awr_report_generated || true
test_IT57_sprint14_summary_exists || true
test_IT58_sprint14_scripts_executable || true
echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
