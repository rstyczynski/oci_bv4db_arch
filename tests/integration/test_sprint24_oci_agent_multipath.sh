#!/usr/bin/env bash
# Integration tests for Sprint 24 OCI agent-managed multipath validation.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SPRINT24_DIR="$REPO_ROOT/progress/sprint_24"

PASS=0
FAIL=0

_pass() { echo "  [PASS] $*"; PASS=$((PASS + 1)); }
_fail() { echo "  [FAIL] $*"; FAIL=$((FAIL + 1)); }

test_IT2401_progress_artifacts_exist() {
  echo "=== IT-24-01: Sprint 24 progress artifacts exist ==="
  local files=(
    "sprint_24_setup.md"
    "sprint_24_design.md"
    "sprint_24_implementation.md"
    "sprint_24_tests.md"
    "sprint24_manual.md"
    "new_tests.manifest"
  )
  local all_ok=1
  for f in "${files[@]}"; do
    if [ -f "$SPRINT24_DIR/$f" ]; then
      echo "    OK: $f"
    else
      _fail "IT-24-01: missing: $SPRINT24_DIR/$f"
      all_ok=0
    fi
  done
  [ "$all_ok" -eq 1 ] && _pass "IT-24-01: progress artifacts present"
  return 0
}

test_IT2402_manual_has_required_sections_and_refs() {
  echo "=== IT-24-02: Manual includes oracle references and verification sections ==="
  local manual="$SPRINT24_DIR/sprint24_manual.md"
  if [ ! -f "$manual" ]; then
    _fail "IT-24-02: manual not found: $manual"
    return 0
  fi

  local required=(
    "Oracle references used by this manual"
    "Step 1 - Enable the Block Volume Management plugin"
    "Step 2 - Create a multipath-enabled iSCSI attachment (UHP)"
    "Step 3 - Evidence checklist (ground truth)"
    "Step 4 - Archive evidence"
    "Step 5 - Troubleshooting"
    "enablingblockvolumemanagementplugin"
    "configuringmultipathattachments"
    "multipathcheck"
    "troubleshootingmultipathattachments"
  )

  local all_ok=1
  for s in "${required[@]}"; do
    if grep -q "$s" "$manual"; then
      echo "    OK: $s"
    else
      _fail "IT-24-02: manual missing: $s"
      all_ok=0
    fi
  done

  [ "$all_ok" -eq 1 ] && _pass "IT-24-02: manual content present"
  return 0
}

test_IT2403_scripts_parse_if_present() {
  echo "=== IT-24-03: Sprint 24 scripts parse without errors (if present) ==="
  local any=0
  local failed=0

  while IFS= read -r -d '' f; do
    any=1
    echo "    Checking: $(basename "$f")"
    if bash -n "$f" 2>/dev/null; then
      true
    else
      _fail "IT-24-03: bash syntax error: $f"
      bash -n "$f" || true
      failed=1
    fi
  done < <(find "$REPO_ROOT/tools" "$SPRINT24_DIR" -maxdepth 2 -type f -name "*sprint24*.sh" -print0 2>/dev/null || true)

  if [ "$any" -eq 0 ]; then
    _pass "IT-24-03: no sprint24 scripts found (ok)"
    return 0
  fi

  if [ "$failed" -eq 0 ]; then
    _pass "IT-24-03: sprint24 scripts parse OK"
  fi
  return 0
}

run_all() {
  echo ""
  echo "=== BV4DB Integration Tests - Sprint 24 ==="
  echo ""

  test_IT2401_progress_artifacts_exist || true
  test_IT2402_manual_has_required_sections_and_refs || true
  test_IT2403_scripts_parse_if_present || true

  echo ""
  echo "Results: $PASS passed, $FAIL failed"
  [[ $FAIL -eq 0 ]]
}

run_all

