#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SPRINT_DIR="$REPO_ROOT/progress/sprint_13"
PASS=0
FAIL=0
_pass(){ echo "  [PASS] $*"; PASS=$((PASS+1)); }
_fail(){ echo "  [FAIL] $*"; FAIL=$((FAIL+1)); }
require_file(){ [ -f "$1" ] || { _fail "missing $1"; return 1; }; }

test_IT47_sprint13_design_docs_exist() {
  echo "=== IT-47: Sprint 13 design documentation exists ==="
  require_file "$SPRINT_DIR/sprint_13_design.md" || return 1
  require_file "$SPRINT_DIR/sprint_13_implementation.md" || return 1
  require_file "$SPRINT_DIR/sprint_13_tests.md" || return 1
  grep -q 'BV4DB-34' "$SPRINT_DIR/sprint_13_design.md" || { _fail "design missing BV4DB-34 reference"; return 1; }
  grep -q 'BV4DB-35' "$SPRINT_DIR/sprint_13_design.md" || { _fail "design missing BV4DB-35 reference"; return 1; }
  _pass "IT-47: sprint 13 design documentation exists"
}

test_IT48_sprint13_summary_exists() {
  echo "=== IT-48: Sprint 13 summary report exists ==="
  require_file "$SPRINT_DIR/sprint_13_summary.md" || return 1
  grep -q 'Database' "$SPRINT_DIR/sprint_13_summary.md" || { _fail "summary missing database section"; return 1; }
  grep -q 'Storage Layout' "$SPRINT_DIR/sprint_13_summary.md" || { _fail "summary missing storage layout section"; return 1; }
  _pass "IT-48: sprint 13 summary report exists"
}

test_IT49_sprint13_logs_exist() {
  echo "=== IT-49: Sprint 13 installation logs exist ==="
  require_file "$SPRINT_DIR/db-install.log" || return 1
  require_file "$SPRINT_DIR/storage-layout.log" || return 1
  _pass "IT-49: sprint 13 installation logs exist"
}

test_IT50_sprint13_db_status_log_shows_open() {
  echo "=== IT-50: Sprint 13 database status shows OPEN ==="
  require_file "$SPRINT_DIR/db-status.log" || return 1
  grep -q 'OPEN' "$SPRINT_DIR/db-status.log" || { _fail "db-status.log does not show OPEN"; return 1; }
  _pass "IT-50: database status shows OPEN"
}

test_IT51_sprint13_state_files_exist() {
  echo "=== IT-51: Sprint 13 state files exist ==="
  # Check for archived state files (created after successful run)
  if [ -f "$SPRINT_DIR/state-bv4db-oracle-db-archived.json" ]; then
    jq empty "$SPRINT_DIR/state-bv4db-oracle-db-archived.json" >/dev/null 2>&1 || { _fail "invalid main state JSON"; return 1; }
  elif [ -f "$SPRINT_DIR/state-bv4db-oracle-db.json" ]; then
    jq empty "$SPRINT_DIR/state-bv4db-oracle-db.json" >/dev/null 2>&1 || { _fail "invalid main state JSON"; return 1; }
  else
    _fail "no compute state file found"
    return 1
  fi
  _pass "IT-51: sprint 13 state files exist"
}

test_IT52_sprint13_scripts_executable() {
  echo "=== IT-52: Sprint 13 scripts are executable ==="
  [ -x "$REPO_ROOT/tools/run_oracle_db_sprint13.sh" ] || { _fail "run_oracle_db_sprint13.sh not executable"; return 1; }
  [ -x "$REPO_ROOT/tools/install_oracle_db_free.sh" ] || { _fail "install_oracle_db_free.sh not executable"; return 1; }
  [ -x "$REPO_ROOT/tools/configure_oracle_db_layout.sh" ] || { _fail "configure_oracle_db_layout.sh not executable"; return 1; }
  _pass "IT-52: sprint 13 scripts are executable"
}

echo ""
echo "=== BV4DB Integration Tests — Sprint 13 ==="
echo ""
test_IT47_sprint13_design_docs_exist || true
test_IT48_sprint13_summary_exists || true
test_IT49_sprint13_logs_exist || true
test_IT50_sprint13_db_status_log_shows_open || true
test_IT51_sprint13_state_files_exist || true
test_IT52_sprint13_scripts_executable || true
echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
