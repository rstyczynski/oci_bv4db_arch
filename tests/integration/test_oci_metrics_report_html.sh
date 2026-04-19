#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SPRINT_DIR="$REPO_ROOT/progress/sprint_12"
PASS=0
FAIL=0
_pass(){ echo "  [PASS] $*"; PASS=$((PASS+1)); }
_fail(){ echo "  [FAIL] $*"; FAIL=$((FAIL+1)); }
require_file(){ [ -f "$1" ] || { _fail "missing $1"; return 1; }; }

test_IT43_metrics_artifacts_exist() {
  echo "=== IT-43: Sprint 12 metrics artifacts exist ==="
  require_file "$SPRINT_DIR/oci-metrics-report.md" || return 1
  require_file "$SPRINT_DIR/oci-metrics-report.html" || return 1
  require_file "$SPRINT_DIR/oci-metrics-raw.json" || return 1
  jq empty "$SPRINT_DIR/oci-metrics-raw.json" >/dev/null 2>&1 || { _fail "invalid raw metrics JSON"; return 1; }
  _pass "IT-43: markdown, html, and raw metrics artifacts exist"
}

test_IT44_html_report_contains_sections_and_charts() {
  echo "=== IT-44: Sprint 12 HTML report contains sections and charts ==="
  require_file "$SPRINT_DIR/oci-metrics-report.html" || return 1
  grep -q 'OCI Metrics Dashboard' "$SPRINT_DIR/oci-metrics-report.html" || { _fail "missing dashboard header"; return 1; }
  grep -q 'Table of Contents' "$SPRINT_DIR/oci-metrics-report.html" || { _fail "missing html table of contents"; return 1; }
  grep -q 'Compute' "$SPRINT_DIR/oci-metrics-report.html" || { _fail "missing compute section"; return 1; }
  grep -q 'Blockvolume' "$SPRINT_DIR/oci-metrics-report.html" || { _fail "missing blockvolume section"; return 1; }
  grep -q 'Network' "$SPRINT_DIR/oci-metrics-report.html" || { _fail "missing network section"; return 1; }
  grep -q 'metric-chart' "$SPRINT_DIR/oci-metrics-report.html" || { _fail "missing chart markup"; return 1; }
  grep -q '<details class="class-section"' "$SPRINT_DIR/oci-metrics-report.html" || { _fail "missing html folding sections"; return 1; }
  _pass "IT-44: html report contains sections and charts"
}

test_IT45_metrics_state_includes_multiple_volumes() {
  echo "=== IT-45: Sprint 12 metrics state includes multiple block volumes ==="
  require_file "$SPRINT_DIR/state-metrics-oracle12.json" || return 1
  jq -e '.volumes.data1.ocid and .volumes.data2.ocid and .volumes.redo1.ocid and .volumes.redo2.ocid and .volumes.fra.ocid' \
    "$SPRINT_DIR/state-metrics-oracle12.json" >/dev/null 2>&1 || { _fail "metrics state missing expected volume ocids"; return 1; }
  _pass "IT-45: metrics state contains multiple block volumes"
}

test_IT46_markdown_report_sections_present() {
  echo "=== IT-46: Sprint 12 markdown report keeps summary sections ==="
  require_file "$SPRINT_DIR/oci-metrics-report.md" || return 1
  grep -q '^## Table of Contents$' "$SPRINT_DIR/oci-metrics-report.md" || { _fail "missing markdown table of contents"; return 1; }
  grep -q '^## Compute$' "$SPRINT_DIR/oci-metrics-report.md" || { _fail "missing compute markdown section"; return 1; }
  grep -q '^## Blockvolume$' "$SPRINT_DIR/oci-metrics-report.md" || { _fail "missing blockvolume markdown section"; return 1; }
  grep -q '^## Network$' "$SPRINT_DIR/oci-metrics-report.md" || { _fail "missing network markdown section"; return 1; }
  _pass "IT-46: markdown report sections present"
}

echo ""
echo "=== BV4DB Integration Tests — Sprint 12 ==="
echo ""
test_IT43_metrics_artifacts_exist || true
test_IT44_html_report_contains_sections_and_charts || true
test_IT45_metrics_state_includes_multiple_volumes || true
test_IT46_markdown_report_sections_present || true
echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
