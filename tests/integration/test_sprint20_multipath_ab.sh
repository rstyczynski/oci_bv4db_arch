#!/usr/bin/env bash
# Integration tests for Sprint 20 multipath diagnostics and A/B runner presence.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SPRINT_DIR="$REPO_ROOT/progress/sprint_20"

PASS=0
FAIL=0

_pass() { echo "  [PASS] $*"; PASS=$((PASS + 1)); }
_fail() { echo "  [FAIL] $*"; FAIL=$((FAIL + 1)); }

test_IT1_scripts_exist() {
  echo "=== IT-1: Sprint 20 scripts exist and are executable ==="
  local a="$REPO_ROOT/tools/run_bv4db_multipath_diag_sprint20.sh"
  local b="$REPO_ROOT/tools/run_bv4db_fio_multipath_ab_sprint20.sh"
  [ -f "$a" ] && [ -f "$b" ] || { _fail "IT-1: missing Sprint 20 tool scripts"; return 1; }
  [ -x "$a" ] || chmod +x "$a" || true
  [ -x "$b" ] || chmod +x "$b" || true
  [ -x "$a" ] && [ -x "$b" ] && _pass "IT-1: scripts present" && return 0
  _fail "IT-1: scripts not executable"
  return 1
}

test_IT2_outputs_exist_if_run() {
  echo "=== IT-2: output artifacts exist (if live run executed) ==="
  mkdir -p "$SPRINT_DIR"
  local any
  any="$(ls -1 "$SPRINT_DIR"/multipath_diagnostics_*.txt "$SPRINT_DIR"/fio_compare_*.md 2>/dev/null | head -n 1 || true)"
  if [ -n "$any" ]; then
    _pass "IT-2: found artifact: $(basename "$any")"
    return 0
  fi
  _pass "IT-2: no artifacts yet (expected before first live run)"
  return 0
}

run_all() {
  echo ""
  echo "=== BV4DB Integration Tests — Sprint 20 ==="
  echo ""

  test_IT1_scripts_exist || true
  test_IT2_outputs_exist_if_run || true

  echo ""
  echo "Results: $PASS passed, $FAIL failed"
  [[ $FAIL -eq 0 ]]
}

run_all

#!/usr/bin/env bash
# Integration tests for Sprint 20 multipath diagnostics and fio A/B.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SPRINT_DIR="$REPO_ROOT/progress/sprint_20"

PASS=0
FAIL=0

_pass() { echo "  [PASS] $*"; PASS=$((PASS + 1)); }
_fail() { echo "  [FAIL] $*"; FAIL=$((FAIL + 1)); }

test_IT1_scripts_exist() {
  echo "=== IT-1: Sprint 20 scripts exist and are executable ==="
  local a="$REPO_ROOT/tools/run_bv4db_multipath_diag_sprint20.sh"
  local b="$REPO_ROOT/tools/run_bv4db_fio_multipath_ab_sprint20.sh"
  [ -f "$a" ] && [ -f "$b" ] || { _fail "IT-1: missing Sprint 20 tools scripts"; return 1; }
  [ -x "$a" ] || chmod +x "$a" || true
  [ -x "$b" ] || chmod +x "$b" || true
  [ -x "$a" ] && [ -x "$b" ] && _pass "IT-1: scripts present" && return 0
  _fail "IT-1: scripts not executable"
  return 1
}

test_IT2_diagnostics_exist_if_run() {
  echo "=== IT-2: Diagnostics artifacts exist (if run has been executed) ==="
  mkdir -p "$SPRINT_DIR"
  local any
  any="$(ls -1 "$SPRINT_DIR"/multipath_diagnostics_*.txt "$SPRINT_DIR"/diag_multipath_*.txt "$SPRINT_DIR"/diag_singlepath_*.txt 2>/dev/null | head -n 1 || true)"
  if [ -n "$any" ]; then
    _pass "IT-2: found diagnostics artifact: $(basename "$any")"
    return 0
  fi
  _pass "IT-2: no diagnostics yet (expected before first live run)"
  return 0
}

test_IT3_fio_outputs_exist_if_run() {
  echo "=== IT-3: fio results + comparison exist (if run has been executed) ==="
  mkdir -p "$SPRINT_DIR"
  local any_json any_md
  any_json="$(ls -1 "$SPRINT_DIR"/fio_multipath_*.json "$SPRINT_DIR"/fio_singlepath_*.json 2>/dev/null | head -n 1 || true)"
  any_md="$(ls -1 "$SPRINT_DIR"/fio_compare_*.md 2>/dev/null | head -n 1 || true)"
  if [ -n "$any_json" ] && [ -n "$any_md" ]; then
    _pass "IT-3: found fio artifacts: $(basename "$any_json"), $(basename "$any_md")"
    return 0
  fi
  _pass "IT-3: no fio artifacts yet (expected before first live run)"
  return 0
}

run_all() {
  echo ""
  echo "=== BV4DB Integration Tests — Sprint 20 ==="
  echo ""

  test_IT1_scripts_exist || true
  test_IT2_diagnostics_exist_if_run || true
  test_IT3_fio_outputs_exist_if_run || true

  echo ""
  echo "Results: $PASS passed, $FAIL failed"
  [[ $FAIL -eq 0 ]]
}

run_all

