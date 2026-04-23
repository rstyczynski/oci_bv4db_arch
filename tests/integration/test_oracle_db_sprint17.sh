#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SPRINT_DIR="$REPO_ROOT/progress/sprint_17"
PASS=0
FAIL=0
_pass(){ echo "  [PASS] $*"; PASS=$((PASS+1)); }
_fail(){ echo "  [FAIL] $*"; FAIL=$((FAIL+1)); }
require_file(){ [ -f "$1" ] || { _fail "missing $1"; return 1; }; }

test_IT65_sprint17_docs_exist() {
  echo "=== IT-65: Sprint 17 documentation exists ==="
  require_file "$SPRINT_DIR/sprint_17_design.md" || return 1
  require_file "$SPRINT_DIR/sprint_17_implementation.md" || return 1
  require_file "$SPRINT_DIR/sprint_17_tests.md" || return 1
  require_file "$SPRINT_DIR/sprint17_manual.md" || return 1
  require_file "$SPRINT_DIR/sprint_manual.md" || return 1
  grep -q 'BV4DB-44' "$SPRINT_DIR/sprint_17_design.md" || { _fail "design missing BV4DB-44 reference"; return 1; }
  grep -q 'BV4DB-45' "$SPRINT_DIR/sprint_17_design.md" || { _fail "design missing BV4DB-45 reference"; return 1; }
  _pass "IT-65: sprint 17 documentation exists"
}

test_IT66_sprint17_scripts_exist_and_are_executable() {
  echo "=== IT-66: Sprint 17 scripts exist and are executable ==="
  local scripts=(
    "$REPO_ROOT/tools/run_oracle_db_sprint17.sh"
    "$REPO_ROOT/tools/render_fio_report_html.sh"
    "$REPO_ROOT/tools/render_swingbench_report_html.sh"
  )
  local script
  for script in "${scripts[@]}"; do
    [ -x "$script" ] || { _fail "$script not executable"; return 1; }
  done
  _pass "IT-66: sprint 17 scripts exist and are executable"
}

test_IT67_sprint17_runner_wires_both_phases_and_metrics() {
  echo "=== IT-67: Sprint 17 runner wires both phases and metrics ==="
  grep -q 'run_remote_fio_phase' "$REPO_ROOT/tools/run_oracle_db_sprint17.sh" || { _fail "runner missing fio phase"; return 1; }
  grep -q 'run_oracle_swingbench.sh' "$REPO_ROOT/tools/run_oracle_db_sprint17.sh" || { _fail "runner missing Swingbench phase"; return 1; }
  grep -q 'capture_awr_snapshot.sh' "$REPO_ROOT/tools/run_oracle_db_sprint17.sh" || { _fail "runner missing AWR begin/end capture"; return 1; }
  grep -q 'export_awr_report.sh' "$REPO_ROOT/tools/run_oracle_db_sprint17.sh" || { _fail "runner missing AWR export"; return 1; }
  grep -q 'run_metrics_phase' "$REPO_ROOT/tools/run_oracle_db_sprint17.sh" || { _fail "runner missing OCI metrics phase helper"; return 1; }
  grep -q 'render_fio_report_html.sh' "$REPO_ROOT/tools/run_oracle_db_sprint17.sh" || { _fail "runner missing FIO HTML renderer call"; return 1; }
  grep -q 'render_swingbench_report_html.sh' "$REPO_ROOT/tools/run_oracle_db_sprint17.sh" || { _fail "runner missing Swingbench HTML renderer call"; return 1; }
  grep -q 'multi_volume' "$REPO_ROOT/tools/run_oracle_db_sprint17.sh" || { _fail "runner missing multi-volume layout"; return 1; }
  _pass "IT-67: sprint 17 runner wires both phases and metrics"
}

test_IT68_sprint17_report_artifacts_exist() {
  echo "=== IT-68: Sprint 17 report artifacts exist ==="
  require_file "$SPRINT_DIR/fio_report.html" || return 1
  require_file "$SPRINT_DIR/fio_oci_metrics_report.html" || return 1
  require_file "$SPRINT_DIR/swingbench_report.html" || return 1
  require_file "$SPRINT_DIR/swingbench_oci_metrics_report.html" || return 1
  require_file "$SPRINT_DIR/awr_report.html" || return 1
  require_file "$SPRINT_DIR/sprint_17_summary.md" || return 1
  require_file "$SPRINT_DIR/fio_results.json" || return 1
  require_file "$SPRINT_DIR/fio_iostat.json" || return 1
  require_file "$SPRINT_DIR/swingbench_results.xml" || return 1
  require_file "$SPRINT_DIR/swingbench_iostat.json" || return 1
  grep -q 'FIO Results' "$SPRINT_DIR/fio_report.html" || { _fail "fio report missing title content"; return 1; }
  grep -q 'Swingbench Benchmark Dashboard' "$SPRINT_DIR/swingbench_report.html" || { _fail "swingbench report missing title content"; return 1; }
  grep -q 'AWR Report' "$SPRINT_DIR/awr_report.html" || { _fail "awr report missing awr content"; return 1; }
  _pass "IT-68: sprint 17 report artifacts exist"
}

echo ""
echo "=== BV4DB Integration Tests — Sprint 17 ==="
echo ""
test_IT65_sprint17_docs_exist || true
test_IT66_sprint17_scripts_exist_and_are_executable || true
test_IT67_sprint17_runner_wires_both_phases_and_metrics || true
test_IT68_sprint17_report_artifacts_exist || true
echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
