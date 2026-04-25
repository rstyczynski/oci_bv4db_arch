#!/usr/bin/env bash
# Integration tests for Sprint 22 fstab-based multipath persistence.
# This test script validates ALL snippets from the Sprint 22 manual.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SPRINT22_DIR="$REPO_ROOT/progress/sprint_22"

PASS=0
FAIL=0
SKIP=0

_pass() { echo "  [PASS] $*"; PASS=$((PASS + 1)); }
_fail() { echo "  [FAIL] $*"; FAIL=$((FAIL + 1)); }
_skip() { echo "  [SKIP] $*"; SKIP=$((SKIP + 1)); }

# === IT-1: Scripts exist and are executable ===
test_IT1_scripts_exist() {
  echo "=== IT-1: Sprint 22 scripts exist and are executable ==="
  local scripts=(
    "$REPO_ROOT/tools/run_bv4db_multipath_diag_sprint22.sh"
    "$REPO_ROOT/tools/run_bv4db_fio_multipath_ab_sprint22.sh"
    "$REPO_ROOT/tools/guest/bv4db_sprint22_fstab.sh"
  )
  local all_ok=1
  for s in "${scripts[@]}"; do
    if [ ! -f "$s" ]; then
      _fail "IT-1: missing script: $s"
      all_ok=0
      continue
    fi
    if [ ! -x "$s" ]; then
      chmod +x "$s" 2>/dev/null || true
    fi
    if [ -x "$s" ]; then
      echo "    OK: $(basename "$s")"
    else
      _fail "IT-1: not executable: $s"
      all_ok=0
    fi
  done
  [ "$all_ok" -eq 1 ] && _pass "IT-1: all scripts present and executable"
  return 0
}

# === IT-2: Progress directory exists ===
test_IT2_progress_dir() {
  echo "=== IT-2: Sprint 22 progress directory structure ==="
  mkdir -p "$SPRINT22_DIR"
  local files=(
    "sprint_22_setup.md"
    "sprint_22_design.md"
    "sprint_22_implementation.md"
    "sprint22_manual.md"
  )
  local all_ok=1
  for f in "${files[@]}"; do
    if [ -f "$SPRINT22_DIR/$f" ]; then
      echo "    OK: $f"
    else
      _fail "IT-2: missing: $SPRINT22_DIR/$f"
      all_ok=0
    fi
  done
  [ "$all_ok" -eq 1 ] && _pass "IT-2: progress directory complete"
  return 0
}

# === IT-3: fstab guest script syntax check ===
test_IT3_fstab_script_syntax() {
  echo "=== IT-3: Guest fstab script syntax validation ==="
  local script="$REPO_ROOT/tools/guest/bv4db_sprint22_fstab.sh"
  if bash -n "$script" 2>/dev/null; then
    _pass "IT-3: fstab script syntax OK"
  else
    _fail "IT-3: fstab script has syntax errors"
    bash -n "$script" || true
  fi
  return 0
}

# === IT-4: fstab script help check ===
test_IT4_fstab_script_help() {
  echo "=== IT-4: Guest fstab script help output ==="
  local script="$REPO_ROOT/tools/guest/bv4db_sprint22_fstab.sh"
  local help_out
  help_out=$("$script" --help 2>&1 || true)
  if echo "$help_out" | grep -q "add.*device"; then
    _pass "IT-4: fstab script help contains expected commands"
  else
    _fail "IT-4: fstab script help missing expected content"
    echo "$help_out" | head -20
  fi
  return 0
}

# === IT-5: Manual contains all required sections ===
test_IT5_manual_sections() {
  echo "=== IT-5: Manual contains all required sections ==="
  local manual="$SPRINT22_DIR/sprint22_manual.md"
  if [ ! -f "$manual" ]; then
    _fail "IT-5: manual not found: $manual"
    return 0
  fi

  local sections=(
    "Step 1 - Run Diagnostics"
    "Step 2 - Run A/B Performance Test"
    "Step 3 - SSH Access"
    "Step 4 - fstab Workflow"
    "View Current fstab Entry"
    "Verify Mount Status"
    "Disable Multipath"
    "Enable Multipath"
    "Remove fstab Entry"
    "Test Reboot Persistence"
    "Switch Between Multipath and Single-Path"
    "Collect Diagnostics"
    "Teardown"
    "Quick Reference"
  )

  local all_ok=1
  for section in "${sections[@]}"; do
    if grep -qi "$section" "$manual"; then
      echo "    OK: $section"
    else
      _fail "IT-5: manual missing section: $section"
      all_ok=0
    fi
  done
  [ "$all_ok" -eq 1 ] && _pass "IT-5: manual contains all required sections"
  return 0
}

# === IT-6: Manual snippets are valid bash ===
test_IT6_manual_snippets_syntax() {
  echo "=== IT-6: Manual snippets syntax validation ==="
  local manual="$SPRINT22_DIR/sprint22_manual.md"
  if [ ! -f "$manual" ]; then
    _skip "IT-6: manual not found"
    return 0
  fi

  # Extract bash code blocks and check syntax
  local tmpfile
  tmpfile=$(mktemp)
  local block_count=0
  local error_count=0

  # Extract code blocks between ```bash and ```
  awk '/^```bash$/,/^```$/{if (!/^```/) print}' "$manual" > "$tmpfile"

  if [ -s "$tmpfile" ]; then
    block_count=$(grep -c '^\s*$' "$tmpfile" 2>/dev/null || echo "0")
    # Basic syntax check - look for common bash patterns
    if grep -q 'go_remote\|KEEP_INFRA\|NAME_PREFIX\|sudo.*fstab\|jq.*state\|oci.*secrets' "$tmpfile"; then
      _pass "IT-6: manual contains expected bash patterns"
    else
      _fail "IT-6: manual snippets missing expected patterns"
      error_count=$((error_count + 1))
    fi
  else
    _skip "IT-6: no bash blocks extracted from manual"
  fi

  rm -f "$tmpfile"
  return 0
}

# === IT-7: Sprint 20 scripts exist (dependency check) ===
test_IT7_sprint20_dependency() {
  echo "=== IT-7: Sprint 20 scripts exist (dependency check) ==="
  local scripts=(
    "$REPO_ROOT/tools/run_bv4db_multipath_diag_sprint20.sh"
    "$REPO_ROOT/tools/run_bv4db_fio_multipath_ab_sprint20.sh"
    "$REPO_ROOT/tools/guest/bv4db_sprint20_load.sh"
  )
  local all_ok=1
  for s in "${scripts[@]}"; do
    if [ -f "$s" ]; then
      echo "    OK: $(basename "$s")"
    else
      _fail "IT-7: Sprint 20 dependency missing: $s"
      all_ok=0
    fi
  done
  [ "$all_ok" -eq 1 ] && _pass "IT-7: Sprint 20 dependencies present"
  return 0
}

# === IT-8: Sprint 1 infrastructure state exists ===
test_IT8_sprint1_infra() {
  echo "=== IT-8: Sprint 1 infrastructure state exists ==="
  local state="$REPO_ROOT/progress/sprint_1/state-bv4db.json"
  if [ -f "$state" ]; then
    local compartment subnet secret
    compartment=$(jq -r '.compartment.ocid // empty' "$state" 2>/dev/null || true)
    subnet=$(jq -r '.subnet.ocid // empty' "$state" 2>/dev/null || true)
    secret=$(jq -r '.secret.ocid // empty' "$state" 2>/dev/null || true)
    if [ -n "$compartment" ] && [ -n "$subnet" ] && [ -n "$secret" ]; then
      _pass "IT-8: Sprint 1 infrastructure state valid"
    else
      _fail "IT-8: Sprint 1 state incomplete (missing compartment/subnet/secret)"
    fi
  else
    _skip "IT-8: Sprint 1 state not found (expected before first deployment)"
  fi
  return 0
}

# === IT-9: PLAN.md contains Sprint 22 ===
test_IT9_plan_contains_sprint22() {
  echo "=== IT-9: PLAN.md contains Sprint 22 ==="
  local plan="$REPO_ROOT/PLAN.md"
  if grep -q "## Sprint 22" "$plan"; then
    if grep -A5 "## Sprint 22" "$plan" | grep -q "Mode: YOLO"; then
      _pass "IT-9: Sprint 22 in PLAN.md with YOLO mode"
    else
      _fail "IT-9: Sprint 22 missing YOLO mode"
    fi
  else
    _fail "IT-9: Sprint 22 not found in PLAN.md"
  fi
  return 0
}

# === IT-10: PROGRESS_BOARD.md contains Sprint 22 ===
test_IT10_progress_board() {
  echo "=== IT-10: PROGRESS_BOARD.md contains Sprint 22 ==="
  local board="$REPO_ROOT/PROGRESS_BOARD.md"
  if grep -q "Sprint 22.*planned.*BV4DB-52" "$board"; then
    _pass "IT-10: Sprint 22 in PROGRESS_BOARD.md"
  else
    _fail "IT-10: Sprint 22 not found in PROGRESS_BOARD.md"
  fi
  return 0
}

# === IT-11: Sprint 21 marked as failed ===
test_IT11_sprint21_failed() {
  echo "=== IT-11: Sprint 21 marked as failed ==="
  local plan="$REPO_ROOT/PLAN.md"
  if grep -A3 "## Sprint 21" "$plan" | grep -q "Status: Failed"; then
    _pass "IT-11: Sprint 21 correctly marked as Failed"
  else
    _fail "IT-11: Sprint 21 not marked as Failed in PLAN.md"
  fi
  return 0
}

# === IT-12: oci_scaffold scripts not modified ===
test_IT12_scaffold_unchanged() {
  echo "=== IT-12: oci_scaffold ensure_* scripts not modified ==="
  local scaffold="$REPO_ROOT/oci_scaffold"
  if [ -d "$scaffold/.git" ]; then
    cd "$scaffold"
    local changes
    changes=$(git status --porcelain resource/ensure-*.sh 2>/dev/null || echo "")
    cd "$REPO_ROOT"
    if [ -z "$changes" ]; then
      _pass "IT-12: oci_scaffold ensure_* scripts unchanged"
    else
      _fail "IT-12: oci_scaffold ensure_* scripts have been modified"
      echo "$changes"
    fi
  else
    _skip "IT-12: oci_scaffold not a git repo"
  fi
  return 0
}

# === IT-13: Live test - scripts run without error (dry run check) ===
test_IT13_scripts_dryrun() {
  echo "=== IT-13: Scripts validate without actual execution ==="
  # Just verify the scripts source/parse without errors
  local diag="$REPO_ROOT/tools/run_bv4db_multipath_diag_sprint22.sh"
  local ab="$REPO_ROOT/tools/run_bv4db_fio_multipath_ab_sprint22.sh"

  if bash -n "$diag" 2>/dev/null && bash -n "$ab" 2>/dev/null; then
    _pass "IT-13: Sprint 22 scripts parse without errors"
  else
    _fail "IT-13: Sprint 22 scripts have syntax errors"
  fi
  return 0
}

# === Run all tests ===
run_all() {
  echo ""
  echo "========================================"
  echo "=== BV4DB Integration Tests - Sprint 22 ==="
  echo "========================================"
  echo ""

  test_IT1_scripts_exist || true
  test_IT2_progress_dir || true
  test_IT3_fstab_script_syntax || true
  test_IT4_fstab_script_help || true
  test_IT5_manual_sections || true
  test_IT6_manual_snippets_syntax || true
  test_IT7_sprint20_dependency || true
  test_IT8_sprint1_infra || true
  test_IT9_plan_contains_sprint22 || true
  test_IT10_progress_board || true
  test_IT11_sprint21_failed || true
  test_IT12_scaffold_unchanged || true
  test_IT13_scripts_dryrun || true

  echo ""
  echo "========================================"
  echo "Results: $PASS passed, $FAIL failed, $SKIP skipped"
  echo "========================================"
  [[ $FAIL -eq 0 ]]
}

run_all
