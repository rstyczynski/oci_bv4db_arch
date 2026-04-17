#!/usr/bin/env bash
# Integration tests for oci_bv4db_arch Sprint 1
# Tests verify: infra provisioned, SSH via vault key, BV mounted, fio report produced.
#
# Prerequisites:
#   - setup_infra.sh completed (progress/sprint_1/state-infra.json exists)
#   - run_bv_fio.sh completed (progress/sprint_1/state-compute.json exists)
#   - OCI CLI configured
#   - jq installed

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INFRA_STATE="$REPO_ROOT/progress/sprint_1/state-infra.json"
COMPUTE_STATE="$REPO_ROOT/progress/sprint_1/state-compute.json"
FIO_RESULTS="$REPO_ROOT/progress/sprint_1/fio-results.json"
PUBKEY="$REPO_ROOT/progress/sprint_1/bv4db-key.pub"

PASS=0
FAIL=0

_pass() { echo "  [PASS] $*"; PASS=$((PASS + 1)); }
_fail() { echo "  [FAIL] $*"; FAIL=$((FAIL + 1)); }

# ---------------------------------------------------------------------------
test_IT1_infra_provisioned() {
    echo "=== IT-1: Infrastructure provisioned ==="

    # TODO: implement — verify state-infra.json contains required OCIDs
    local result=""

    if [[ "$result" == "ok" ]]; then
        _pass "IT-1: infra state complete"
        return 0
    else
        _fail "IT-1: infra state incomplete — run setup_infra.sh first"
        return 1
    fi
}

# ---------------------------------------------------------------------------
test_IT2_ssh_via_vault_key() {
    echo "=== IT-2: SSH access using key from vault ==="

    # TODO: implement — retrieve private key from vault, SSH to compute instance
    local result=""

    if [[ "$result" == "ok" ]]; then
        _pass "IT-2: SSH successful via vault key"
        return 0
    else
        _fail "IT-2: SSH failed — check compute state and vault secret"
        return 1
    fi
}

# ---------------------------------------------------------------------------
test_IT3_block_volume_mounted() {
    echo "=== IT-3: Block volume mounted at /mnt/bv ==="

    # TODO: implement — SSH to instance and verify /mnt/bv in lsblk
    local result=""

    if [[ "$result" == "ok" ]]; then
        _pass "IT-3: /mnt/bv is mounted"
        return 0
    else
        _fail "IT-3: /mnt/bv not mounted — check run_bv_fio.sh"
        return 1
    fi
}

# ---------------------------------------------------------------------------
test_IT4_fio_report_produced() {
    echo "=== IT-4: fio performance report produced ==="

    # TODO: implement — verify fio-results.json exists and contains expected fields
    local result=""

    if [[ "$result" == "ok" ]]; then
        _pass "IT-4: fio-results.json valid"
        return 0
    else
        _fail "IT-4: fio-results.json missing or invalid"
        return 1
    fi
}

# ---------------------------------------------------------------------------
run_all() {
    echo ""
    echo "=== BV4DB Integration Tests — Sprint 1 ==="
    echo ""

    test_IT1_infra_provisioned  || true
    test_IT2_ssh_via_vault_key  || true
    test_IT3_block_volume_mounted || true
    test_IT4_fio_report_produced  || true

    echo ""
    echo "Results: $PASS passed, $FAIL failed"
    [[ $FAIL -eq 0 ]]
}

run_all
