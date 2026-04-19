#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SPRINT_DIR="$REPO_ROOT/progress/sprint_10"
PASS=0
FAIL=0
_pass(){ echo "  [PASS] $*"; PASS=$((PASS+1)); }
_fail(){ echo "  [FAIL] $*"; FAIL=$((FAIL+1)); }

require_file() { [ -f "$1" ] || { _fail "missing $1"; return 1; }; }

test_IT35_profile_exists() {
  echo "=== IT-35: Sprint 10 fio profile exists ==="
  require_file "$SPRINT_DIR/oracle-layout-4k-redo.fio" || return 1
  grep -q '^bs=4k$' "$SPRINT_DIR/oracle-layout-4k-redo.fio" || { _fail "redo bs=4k missing"; return 1; }
  _pass "IT-35: sprint 10 fio profile exists"
}

test_IT36_all_artifacts_exist() {
  echo "=== IT-36: Sprint 10 artifacts exist ==="
  local files=(
    "$SPRINT_DIR/fio-results-oracle-lower-single-4k-redo-integration.json"
    "$SPRINT_DIR/fio-results-oracle-balanced-single-4k-redo-integration.json"
    "$SPRINT_DIR/fio-results-oracle-balanced-multi-4k-redo-integration.json"
    "$SPRINT_DIR/fio-results-oracle-hp-single-4k-redo-integration.json"
    "$SPRINT_DIR/fio-results-oracle-hp-multi-4k-redo-integration.json"
  )
  local f
  for f in "${files[@]}"; do
    require_file "$f" || return 1
    jq empty "$f" >/dev/null 2>&1 || { _fail "invalid JSON $f"; return 1; }
  done
  _pass "IT-36: sprint 10 fio artifacts exist"
}

test_IT37_all_analyses_exist() {
  echo "=== IT-37: Sprint 10 analyses exist ==="
  local files=(
    "$SPRINT_DIR/fio-analysis-oracle-lower-single-4k-redo-integration.md"
    "$SPRINT_DIR/fio-analysis-oracle-balanced-single-4k-redo-integration.md"
    "$SPRINT_DIR/fio-analysis-oracle-balanced-multi-4k-redo-integration.md"
    "$SPRINT_DIR/fio-analysis-oracle-hp-single-4k-redo-integration.md"
    "$SPRINT_DIR/fio-analysis-oracle-hp-multi-4k-redo-integration.md"
    "$SPRINT_DIR/oci_performance_tier_comparison.md"
  )
  local f
  for f in "${files[@]}"; do
    require_file "$f" || return 1
  done
  _pass "IT-37: sprint 10 analysis artifacts exist"
}

test_IT38_teardown_archived() {
  echo "=== IT-38: Sprint 10 teardown archived state ==="
  local count
  count=$(find "$SPRINT_DIR" -maxdepth 1 -name 'state-*.deleted-*.json' | wc -l | tr -d ' ')
  [ "$count" -ge 10 ] || { _fail "expected archived deleted state files, got $count"; return 1; }
  _pass "IT-38: teardown archived state files"
}

echo ""
echo "=== BV4DB Integration Tests — Sprint 10 ==="
echo ""
test_IT35_profile_exists || true
test_IT36_all_artifacts_exist || true
test_IT37_all_analyses_exist || true
test_IT38_teardown_archived || true
echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
