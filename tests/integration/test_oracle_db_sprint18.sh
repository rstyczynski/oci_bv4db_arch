#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SPRINT_DIR="$REPO_ROOT/progress/sprint_18"
PASS=0
FAIL=0
_pass(){ echo "  [PASS] $*"; PASS=$((PASS+1)); }
_fail(){ echo "  [FAIL] $*"; FAIL=$((FAIL+1)); }
require_file(){ [ -f "$1" ] || { _fail "missing $1"; return 1; }; }

test_IT72_sprint18_docs_exist() {
  echo "=== IT-72: Sprint 18 documentation exists ==="
  require_file "$SPRINT_DIR/sprint_18_design.md" || return 1
  require_file "$SPRINT_DIR/sprint_18_implementation.md" || return 1
  require_file "$SPRINT_DIR/sprint_18_tests.md" || return 1
  require_file "$SPRINT_DIR/sprint_18_bugs.md" || return 1
  require_file "$SPRINT_DIR/sprint_18_summary.md" || return 1
  require_file "$SPRINT_DIR/sprint18_manual.md" || return 1
  require_file "$SPRINT_DIR/sprint_manual.md" || return 1
  grep -q 'BV4DB-46' "$SPRINT_DIR/sprint_18_design.md" || { _fail "design missing BV4DB-46"; return 1; }
  grep -q 'BUG-1' "$SPRINT_DIR/sprint_18_bugs.md" || { _fail "bugs file missing BUG-1"; return 1; }
  _pass "IT-72: sprint 18 documentation exists"
}

test_IT73_sprint18_wrapper_enforces_mirror_run_parameters() {
  echo "=== IT-73: Sprint 18 wrapper enforces mirror-run parameters ==="
  grep -q 'progress/sprint_18' "$REPO_ROOT/tools/run_oracle_db_sprint18.sh" || { _fail "wrapper missing sprint 18 progress dir"; return 1; }
  grep -q 'bv4db-oracle18-run' "$REPO_ROOT/tools/run_oracle_db_sprint18.sh" || { _fail "wrapper missing sprint 18 name prefix"; return 1; }
  grep -q 'FIO_RUNTIME_SEC=.*900' "$REPO_ROOT/tools/run_oracle_db_sprint18.sh" || { _fail "wrapper missing 900s fio runtime"; return 1; }
  grep -q 'SWINGBENCH_WORKLOAD_DURATION=.*900' "$REPO_ROOT/tools/run_oracle_db_sprint18.sh" || { _fail "wrapper missing 900s swingbench runtime"; return 1; }
  grep -q 'SKIP_FIO_PHASE' "$REPO_ROOT/tools/run_oracle_db_sprint17.sh" || { _fail "runner missing skip-fio control"; return 1; }
  grep -q 'SKIP_DB_INSTALL' "$REPO_ROOT/tools/run_oracle_db_sprint17.sh" || { _fail "runner missing skip-db-install control"; return 1; }
  grep -q 'REUSE_EXISTING_INFRA' "$REPO_ROOT/tools/run_oracle_db_sprint17.sh" || { _fail "runner missing reuse-infra control"; return 1; }
  _pass "IT-73: sprint 18 wrapper enforces mirror-run parameters"
}

test_IT75_oracle_db_install_enforces_project_storage_layout() {
  echo "=== IT-75: Oracle DB install enforces project storage layout ==="
  grep -q 'FORCE_DB_RECREATE_ON_MISPLACEMENT' "$REPO_ROOT/tools/install_oracle_db_free.sh" || { _fail "installer missing recreate-on-misplacement control"; return 1; }
  grep -q 'db_placement_is_valid' "$REPO_ROOT/tools/install_oracle_db_free.sh" || { _fail "installer missing placement validation"; return 1; }
  grep -q 'move_redo_logs_to_project_storage' "$REPO_ROOT/tools/install_oracle_db_free.sh" || { _fail "installer missing redo relocation"; return 1; }
  if grep -q '/etc/init.d/oracle-free-23ai configure' "$REPO_ROOT/tools/install_oracle_db_free.sh"; then
    _fail "installer still uses oracle-free configure path"
    return 1
  fi
  _pass "IT-75: Oracle DB install enforces project storage layout"
}

test_IT76_metrics_path_includes_boot_volume() {
  echo "=== IT-76: metrics path includes boot volume ==="
  grep -q 'boot_volume' "$REPO_ROOT/oci_scaffold/resource/operate-blockvolume.sh" || { _fail "blockvolume adapter missing boot volume resource"; return 1; }
  grep -q 'ensure_boot_volume_state' "$REPO_ROOT/tools/run_oracle_db_sprint17.sh" || { _fail "runner missing boot volume state enrichment"; return 1; }
  _pass "IT-76: metrics path includes boot volume"
}

test_IT74_sprint18_report_artifacts_exist() {
  echo "=== IT-74: Sprint 18 report artifacts exist ==="
  require_file "$SPRINT_DIR/fio_report.html" || return 1
  require_file "$SPRINT_DIR/fio_oci_metrics_report.html" || return 1
  require_file "$SPRINT_DIR/swingbench_report.html" || return 1
  require_file "$SPRINT_DIR/swingbench_oci_metrics_report.html" || return 1
  require_file "$SPRINT_DIR/awr_report.html" || return 1
  require_file "$SPRINT_DIR/sprint_18_summary.md" || return 1
  _pass "IT-74: sprint 18 report artifacts exist"
}

echo ""
echo "=== BV4DB Integration Tests — Sprint 18 ==="
echo ""
test_IT72_sprint18_docs_exist || true
test_IT73_sprint18_wrapper_enforces_mirror_run_parameters || true
test_IT74_sprint18_report_artifacts_exist || true
test_IT75_oracle_db_install_enforces_project_storage_layout || true
test_IT76_metrics_path_includes_boot_volume || true
echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
