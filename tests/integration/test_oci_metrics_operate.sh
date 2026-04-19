#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SPRINT_DIR="$REPO_ROOT/progress/sprint_11"
PASS=0
FAIL=0
_pass(){ echo "  [PASS] $*"; PASS=$((PASS+1)); }
_fail(){ echo "  [FAIL] $*"; FAIL=$((FAIL+1)); }
require_file(){ [ -f "$1" ] || { _fail "missing $1"; return 1; }; }

test_IT39_metrics_artifacts_exist() {
  echo "=== IT-39: Sprint 11 metrics artifacts exist ==="
  require_file "$SPRINT_DIR/oci-metrics-report.md" || return 1
  require_file "$SPRINT_DIR/oci-metrics-raw.json" || return 1
  jq empty "$SPRINT_DIR/oci-metrics-raw.json" >/dev/null 2>&1 || { _fail "invalid raw metrics JSON"; return 1; }
  _pass "IT-39: metrics artifacts exist"
}

test_IT40_metrics_report_sections() {
  echo "=== IT-40: Sprint 11 metrics report has expected sections ==="
  require_file "$SPRINT_DIR/oci-metrics-report.md" || return 1
  grep -q '^## Compute$' "$SPRINT_DIR/oci-metrics-report.md" || { _fail "missing compute section"; return 1; }
  grep -q '^## Blockvolume$' "$SPRINT_DIR/oci-metrics-report.md" || { _fail "missing blockvolume section"; return 1; }
  grep -q '^## Network$' "$SPRINT_DIR/oci-metrics-report.md" || { _fail "missing network section"; return 1; }
  _pass "IT-40: report sections present"
}

test_IT41_metrics_state_and_window() {
  echo "=== IT-41: Sprint 11 metrics state contains test window ==="
  require_file "$SPRINT_DIR/state-metrics-oracle11.json" || return 1
  jq -e '.test_window.start_time and .test_window.end_time and .compute.ocid and .blockvolume.ocid' \
    "$SPRINT_DIR/state-metrics-oracle11.json" >/dev/null 2>&1 || { _fail "metrics state missing required fields"; return 1; }
  _pass "IT-41: metrics state contains required fields"
}

test_IT42_metrics_refactor_structure() {
  echo "=== IT-42: Sprint 11 metrics refactor structure exists ==="
  local files=(
    "$REPO_ROOT/oci_scaffold/do/shared-metrics.sh"
    "$REPO_ROOT/oci_scaffold/resource/operate-compute.sh"
    "$REPO_ROOT/oci_scaffold/resource/operate-blockvolume.sh"
    "$REPO_ROOT/oci_scaffold/resource/operate-network.sh"
  )
  local f
  for f in "${files[@]}"; do
    require_file "$f" || return 1
  done
  _pass "IT-42: shared and resource-specific metrics files exist"
}

echo ""
echo "=== BV4DB Integration Tests — Sprint 11 ==="
echo ""
test_IT39_metrics_artifacts_exist || true
test_IT40_metrics_report_sections || true
test_IT41_metrics_state_and_window || true
test_IT42_metrics_refactor_structure || true
echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
