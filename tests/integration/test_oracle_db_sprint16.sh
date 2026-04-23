#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SPRINT_DIR="$REPO_ROOT/progress/sprint_16"
PASS=0
FAIL=0
_pass(){ echo "  [PASS] $*"; PASS=$((PASS+1)); }
_fail(){ echo "  [FAIL] $*"; FAIL=$((FAIL+1)); }
require_file(){ [ -f "$1" ] || { _fail "missing $1"; return 1; }; }

test_IT69_sprint16_docs_exist() {
  echo "=== IT-69: Sprint 16 documentation exists ==="
  require_file "$SPRINT_DIR/sprint_16_design.md" || return 1
  require_file "$SPRINT_DIR/sprint_16_implementation.md" || return 1
  require_file "$SPRINT_DIR/sprint_16_tests.md" || return 1
  require_file "$SPRINT_DIR/sprint_16_summary.md" || return 1
  require_file "$SPRINT_DIR/sprint_16_correlation.md" || return 1
  require_file "$SPRINT_DIR/sprint16_manual.md" || return 1
  require_file "$SPRINT_DIR/sprint_manual.md" || return 1
  grep -q 'BV4DB-37' "$SPRINT_DIR/sprint_16_design.md" || { _fail "design missing BV4DB-37"; return 1; }
  grep -q 'BV4DB-40' "$SPRINT_DIR/sprint_16_design.md" || { _fail "design missing BV4DB-40"; return 1; }
  _pass "IT-69: sprint 16 documentation exists"
}

test_IT70_sprint16_analysis_references_required_source_evidence() {
  echo "=== IT-70: Sprint 16 analysis references required source evidence ==="
  grep -q 'progress/sprint_15/swingbench_results_db.json' "$SPRINT_DIR/sprint_16_correlation.md" || { _fail "analysis missing sprint 15 swingbench reference"; return 1; }
  grep -q 'progress/sprint_17/fio_results.json' "$SPRINT_DIR/sprint_16_correlation.md" || { _fail "analysis missing sprint 17 fio reference"; return 1; }
  grep -q 'progress/sprint_17/swingbench_oci_metrics_report.md' "$SPRINT_DIR/sprint_16_correlation.md" || { _fail "analysis missing sprint 17 OCI metrics reference"; return 1; }
  grep -q 'progress/sprint_17/awr_report.html' "$SPRINT_DIR/sprint_16_correlation.md" || { _fail "analysis missing sprint 17 AWR reference"; return 1; }
  grep -q 'log file sync' "$SPRINT_DIR/sprint_16_correlation.md" || { _fail "analysis missing AWR wait-event discussion"; return 1; }
  grep -q 'guest `iostat`' "$SPRINT_DIR/sprint_16_correlation.md" || { _fail "analysis missing guest iostat discussion"; return 1; }
  _pass "IT-70: sprint 16 analysis references required source evidence"
}

test_IT71_sprint16_required_source_artifacts_exist() {
  echo "=== IT-71: Sprint 16 required source artifacts exist ==="
  local files=(
    "$REPO_ROOT/progress/sprint_15/swingbench_results_db.json"
    "$REPO_ROOT/progress/sprint_15/awr_report.html"
    "$REPO_ROOT/progress/sprint_17/fio_results.json"
    "$REPO_ROOT/progress/sprint_17/fio_iostat.json"
    "$REPO_ROOT/progress/sprint_17/fio_oci_metrics_report.md"
    "$REPO_ROOT/progress/sprint_17/swingbench_results_db.json"
    "$REPO_ROOT/progress/sprint_17/swingbench_iostat.json"
    "$REPO_ROOT/progress/sprint_17/swingbench_oci_metrics_report.md"
    "$REPO_ROOT/progress/sprint_17/awr_report.html"
  )
  local f
  for f in "${files[@]}"; do
    require_file "$f" || return 1
  done
  _pass "IT-71: sprint 16 required source artifacts exist"
}

echo ""
echo "=== BV4DB Integration Tests — Sprint 16 ==="
echo ""
test_IT69_sprint16_docs_exist || true
test_IT70_sprint16_analysis_references_required_source_evidence || true
test_IT71_sprint16_required_source_artifacts_exist || true
echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
