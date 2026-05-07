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

test_IT1_runner_exists_and_is_executable() {
  echo "=== IT-1: Sprint 24 runner exists and is executable ==="
  local script="$REPO_ROOT/tools/run_bv4db_oci_agent_multipath_sprint24.sh"
  if [ ! -f "$script" ]; then
    _fail "missing runner: $script"
    return 0
  fi
  [ -x "$script" ] || chmod +x "$script" 2>/dev/null || true
  if [ -x "$script" ]; then
    _pass "runner is executable"
  else
    _fail "runner is not executable"
  fi
  return 0
}

test_IT2_runner_syntax() {
  echo "=== IT-2: Sprint 24 runner syntax ==="
  local script="$REPO_ROOT/tools/run_bv4db_oci_agent_multipath_sprint24.sh"
  if bash -n "$script"; then
    _pass "runner syntax OK"
  else
    _fail "runner syntax failed"
  fi
  return 0
}

test_IT3_runner_uses_agent_path() {
  echo "=== IT-3: Runner uses OCI agent-managed multipath path ==="
  local script="$REPO_ROOT/tools/run_bv4db_oci_agent_multipath_sprint24.sh"
  local all_ok=1

  grep -q "Block Volume Management" "$script" || { _fail "runner does not enable Block Volume Management plugin"; all_ok=0; }
  grep -q "guest_wait_for_agent_multipath" "$script" || { _fail "runner lacks agent wait verification"; all_ok=0; }
  grep -q "oci-blockautoconfig" "$script" || { _fail "runner does not capture block plugin evidence"; all_ok=0; }

  if grep -q "iscsiadm .*--login\\|mpathconf --enable\\|cat >/etc/multipath.conf" "$script"; then
    _fail "runner contains custom iSCSI login or custom multipath configuration"
    all_ok=0
  fi

  [ "$all_ok" -eq 1 ] && _pass "runner relies on agent-managed setup and evidence collection"
  return 0
}

test_IT4_docs_contain_evidence_checklist() {
  echo "=== IT-4: Sprint 24 docs contain evidence checklist and troubleshooting ==="
  local design="$SPRINT24_DIR/sprint_24_design.md"
  local manual="$SPRINT24_DIR/sprint24_manual.md"
  local all_ok=1

  [ -f "$design" ] || { _fail "missing design doc"; all_ok=0; }
  [ -f "$manual" ] || { _fail "missing manual"; all_ok=0; }

  if [ -f "$manual" ]; then
    grep -qi "Evidence Checklist" "$manual" || { _fail "manual missing Evidence Checklist"; all_ok=0; }
    grep -qi "Operator Walkthrough" "$manual" || { _fail "manual missing operator walkthrough"; all_ok=0; }
    grep -qi "Autodiscovered OCI Context" "$manual" || { _fail "manual missing OCI context autodiscovery"; all_ok=0; }
    grep -qi "missing sessions" "$manual" || { _fail "manual missing missing sessions troubleshooting"; all_ok=0; }
    grep -qi "missing mapper" "$manual" || { _fail "manual missing missing mapper troubleshooting"; all_ok=0; }
    grep -qi "plugin warnings" "$manual" || { _fail "manual missing plugin warnings troubleshooting"; all_ok=0; }
    grep -q "multipath -ll" "$manual" || { _fail "manual missing multipath -ll verification"; all_ok=0; }
    grep -q "KEEP_INFRA=true ./tools/run_bv4db_oci_agent_multipath_sprint24.sh" "$manual" || { _fail "manual missing copy/paste runner command"; all_ok=0; }
    grep -q "<region>" "$manual" && { _fail "manual still contains region placeholder"; all_ok=0; }
  fi

  [ "$all_ok" -eq 1 ] && _pass "documentation includes checklist and troubleshooting"
  return 0
}

test_IT5_new_tests_manifest_registers_runner() {
  echo "=== IT-5: Sprint 24 new tests manifest ==="
  local manifest="$SPRINT24_DIR/new_tests.manifest"
  if [ -f "$manifest" ] && grep -q '^integration:test_sprint24_oci_agent_multipath.sh$' "$manifest"; then
    _pass "new tests manifest registers Sprint 24 integration test"
  else
    _fail "new tests manifest missing Sprint 24 integration test"
  fi
  return 0
}

run_all() {
  echo ""
  echo "=== BV4DB Integration Tests — Sprint 24 OCI Agent Multipath ==="
  echo ""

  test_IT1_runner_exists_and_is_executable
  test_IT2_runner_syntax
  test_IT3_runner_uses_agent_path
  test_IT4_docs_contain_evidence_checklist
  test_IT5_new_tests_manifest_registers_runner

  echo ""
  echo "Results: $PASS passed, $FAIL failed"
  [ "$FAIL" -eq 0 ]
}

run_all
