#!/usr/bin/env bash
# Smoke validation for Sprint 6 oci_scaffold sync.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SPRINT_DIR="$REPO_ROOT/progress/sprint_6"
REPORT_MD="$SPRINT_DIR/scaffold_sync_smoke.md"

PASS=0
FAIL=0

_pass() { echo "  [PASS] $*"; PASS=$((PASS + 1)); }
_fail() { echo "  [FAIL] $*"; FAIL=$((FAIL + 1)); }

test_IT25_scaffold_smoke_report_present() {
  echo "=== IT-25: Scaffold smoke report present ==="
  [ -f "$REPORT_MD" ] || { _fail "IT-25: scaffold_sync_smoke.md not found"; return 1; }
  grep -q 'Submodule branch' "$REPORT_MD" || { _fail "IT-25: branch line missing"; return 1; }
  grep -q 'Attachment state: `ATTACHED`' "$REPORT_MD" || { _fail "IT-25: attachment not reported as ATTACHED"; return 1; }
  _pass "IT-25: scaffold smoke report recorded attached block volume"
}

test_IT26_scaffold_teardown_complete() {
  echo "=== IT-26: Scaffold smoke teardown complete ==="
  local main_deleted live_main
  main_deleted=$(ls -1 "$SPRINT_DIR"/state-bv4db-scaffold-sync.deleted-*.json 2>/dev/null | wc -l | tr -d ' ')
  live_main=$(ls -1 "$SPRINT_DIR"/state-bv4db-scaffold-sync.json 2>/dev/null | wc -l | tr -d ' ')
  if [ "$main_deleted" -ge 1 ] && [ "$live_main" -eq 0 ]; then
    _pass "IT-26: scaffold smoke state archived after teardown"
    return 0
  fi
  _fail "IT-26: expected archived scaffold state and no live state (main_deleted=$main_deleted live_main=$live_main)"
  return 1
}

echo ""
echo "=== BV4DB Smoke Tests — Sprint 6 ==="
echo ""

test_IT25_scaffold_smoke_report_present || true
test_IT26_scaffold_teardown_complete || true

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
