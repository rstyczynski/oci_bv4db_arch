#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SPRINT_DIR="$REPO_ROOT/progress/sprint_15"
PASS=0
FAIL=0
_pass(){ echo "  [PASS] $*"; PASS=$((PASS+1)); }
_fail(){ echo "  [FAIL] $*"; FAIL=$((FAIL+1)); }
require_file(){ [ -f "$1" ] || { _fail "missing $1"; return 1; }; }

test_IT59_sprint15_docs_exist() {
  echo "=== IT-59: Sprint 15 documentation exists ==="
  require_file "$SPRINT_DIR/sprint_15_design.md" || return 1
  require_file "$SPRINT_DIR/sprint_15_implementation.md" || return 1
  require_file "$SPRINT_DIR/sprint_15_summary.md" || return 1
  require_file "$SPRINT_DIR/sprint_15_tests.md" || return 1
  require_file "$SPRINT_DIR/sprint15_manual.md" || return 1
  require_file "$SPRINT_DIR/sprint_manual.md" || return 1
  require_file "$REPO_ROOT/config/swingbench/SOE_Server_Side_V2.xml" || return 1
  grep -q 'BV4DB-41' "$SPRINT_DIR/sprint_15_design.md" || { _fail "design missing BV4DB-41 reference"; return 1; }
  grep -q 'BV4DB-43' "$SPRINT_DIR/sprint_15_design.md" || { _fail "design missing BV4DB-43 reference"; return 1; }
  grep -qi 'Swingbench' "$SPRINT_DIR/sprint_15_design.md" || { _fail "design missing Swingbench reference"; return 1; }
  grep -qi 'HammerDB' "$SPRINT_DIR/sprint15_manual.md" || { _fail "manual missing HammerDB fallback reference"; return 1; }
  _pass "IT-59: sprint 15 documentation exists"
}

test_IT60_sprint15_scripts_exist_and_are_executable() {
  echo "=== IT-60: Sprint 15 scripts exist and are executable ==="
  local scripts=(
    "$REPO_ROOT/tools/install_swingbench.sh"
    "$REPO_ROOT/tools/install_hammerdb.sh"
    "$REPO_ROOT/tools/render_swingbench_report_html.sh"
    "$REPO_ROOT/tools/run_oracle_swingbench.sh"
    "$REPO_ROOT/tools/run_oracle_db_sprint15.sh"
  )
  local script
  for script in "${scripts[@]}"; do
    [ -x "$script" ] || { _fail "$script not executable"; return 1; }
  done
  _pass "IT-60: sprint 15 scripts exist and are executable"
}

test_IT61_sprint15_scripts_parse() {
  echo "=== IT-61: Sprint 15 scripts pass bash syntax check ==="
  local scripts=(
    "$REPO_ROOT/tools/install_swingbench.sh"
    "$REPO_ROOT/tools/install_hammerdb.sh"
    "$REPO_ROOT/tools/render_swingbench_report_html.sh"
    "$REPO_ROOT/tools/run_oracle_swingbench.sh"
    "$REPO_ROOT/tools/run_oracle_db_sprint15.sh"
  )
  local script
  for script in "${scripts[@]}"; do
    bash -n "$script" || { _fail "bash -n failed for $script"; return 1; }
  done
  _pass "IT-61: sprint 15 scripts pass bash syntax check"
}

test_IT62_sprint15_runner_uses_swingbench_and_awr() {
  echo "=== IT-62: Sprint 15 runner wires Swingbench and AWR ==="
  grep -q '_run_remote_step()' "$REPO_ROOT/tools/run_oracle_db_sprint15.sh" || { _fail "runner missing remote step execution helper"; return 1; }
  grep -q 'run_oracle_swingbench.sh' "$REPO_ROOT/tools/run_oracle_db_sprint15.sh" || { _fail "runner missing Swingbench workload call"; return 1; }
  grep -q 'capture_awr_snapshot.sh' "$REPO_ROOT/tools/run_oracle_db_sprint15.sh" || { _fail "runner missing AWR snapshot call"; return 1; }
  grep -q 'export_awr_report.sh' "$REPO_ROOT/tools/run_oracle_db_sprint15.sh" || { _fail "runner missing AWR export call"; return 1; }
  grep -q 'render_swingbench_report_html.sh' "$REPO_ROOT/tools/run_oracle_db_sprint15.sh" || { _fail "runner missing Swingbench HTML report generation"; return 1; }
  grep -q 'BENCHMARK_RESULTS' "$REPO_ROOT/tools/run_oracle_swingbench.sh" || { _fail "Swingbench runner missing database result export"; return 1; }
  grep -q 'CONFIG_FILE=/tmp/SOE_Server_Side_V2.xml' "$REPO_ROOT/tools/run_oracle_db_sprint15.sh" || { _fail "runner missing project config injection"; return 1; }
  grep -q 'Swingbench workload' "$REPO_ROOT/tools/run_oracle_db_sprint15.sh" || { _fail "runner missing detached Swingbench workload step"; return 1; }
  _pass "IT-62: sprint 15 runner wires Swingbench and AWR"
}

test_IT63_sprint15_html_report_exists() {
  echo "=== IT-63: Sprint 15 HTML report exists and contains benchmark sections ==="
  require_file "$SPRINT_DIR/swingbench_report.html" || return 1
  grep -q 'Sprint 15 Swingbench Benchmark Dashboard' "$SPRINT_DIR/swingbench_report.html" || { _fail "missing dashboard title"; return 1; }
  grep -q 'Table of Contents' "$SPRINT_DIR/swingbench_report.html" || { _fail "missing html table of contents"; return 1; }
  grep -q 'Runtime Charts' "$SPRINT_DIR/swingbench_report.html" || { _fail "missing runtime charts section"; return 1; }
  grep -q 'Transaction Mix' "$SPRINT_DIR/swingbench_report.html" || { _fail "missing transaction mix section"; return 1; }
  grep -q 'metric-chart' "$SPRINT_DIR/swingbench_report.html" || { _fail "missing chart markup"; return 1; }
  _pass "IT-63: sprint 15 HTML report exists and contains benchmark sections"
}

test_IT64_sprint15_project_config_exists() {
  echo "=== IT-64: Sprint 15 uses a project-owned Swingbench config file ==="
  require_file "$REPO_ROOT/config/swingbench/SOE_Server_Side_V2.xml" || return 1
  require_file "$SPRINT_DIR/swingbench_config.xml" || return 1
  cmp -s "$REPO_ROOT/config/swingbench/SOE_Server_Side_V2.xml" "$SPRINT_DIR/swingbench_config.xml" || { _fail "archived sprint config differs from project config"; return 1; }
  grep -q '<SwingBenchConfiguration' "$REPO_ROOT/config/swingbench/SOE_Server_Side_V2.xml" || { _fail "project config is not a Swingbench XML config"; return 1; }
  _pass "IT-64: sprint 15 uses a project-owned Swingbench config file"
}

echo ""
echo "=== BV4DB Integration Tests — Sprint 15 ==="
echo ""
test_IT59_sprint15_docs_exist || true
test_IT60_sprint15_scripts_exist_and_are_executable || true
test_IT61_sprint15_scripts_parse || true
test_IT62_sprint15_runner_uses_swingbench_and_awr || true
test_IT63_sprint15_html_report_exists || true
test_IT64_sprint15_project_config_exists || true
echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
