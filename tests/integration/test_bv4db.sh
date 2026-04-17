#!/usr/bin/env bash
# Integration tests for oci_bv4db_arch Sprint 1
# Tests verify: infra provisioned, SSH via vault key, BV mounted, fio report produced.
#
# Prerequisites:
#   - setup_infra.sh completed  → progress/sprint_1/state-bv4db.json
#   - run_bv_fio.sh completed with KEEP_INFRA=true for IT-2/IT-3
#     (IT-1 and IT-4 are file-only and work after teardown)
#   - OCI CLI configured
#   - jq installed

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INFRA_STATE="$REPO_ROOT/progress/sprint_1/state-bv4db.json"
COMPUTE_STATE="$REPO_ROOT/progress/sprint_1/state-bv4db-run.json"
FIO_RESULTS="$REPO_ROOT/progress/sprint_1/fio-results.json"
PUBKEY="$REPO_ROOT/progress/sprint_1/bv4db-key.pub"

PASS=0
FAIL=0

_pass() { echo "  [PASS] $*"; PASS=$((PASS + 1)); }
_fail() { echo "  [FAIL] $*"; FAIL=$((FAIL + 1)); }

# ---------------------------------------------------------------------------
test_IT1_infra_provisioned() {
    echo "=== IT-1: Infrastructure provisioned ==="

    local ok=true

    if [ ! -f "$INFRA_STATE" ]; then
        _fail "IT-1: state-bv4db.json not found — run setup_infra.sh first"
        return 1
    fi

    local comp subnet secret
    comp=$(jq -r '.compartment.ocid // empty' "$INFRA_STATE")
    subnet=$(jq -r '.subnet.ocid // empty'    "$INFRA_STATE")
    secret=$(jq -r '.secret.ocid // empty'    "$INFRA_STATE")

    [ -n "$comp"   ] || { _fail "IT-1: .compartment.ocid missing in state"; ok=false; }
    [ -n "$subnet" ] || { _fail "IT-1: .subnet.ocid missing in state";      ok=false; }
    [ -n "$secret" ] || { _fail "IT-1: .secret.ocid missing in state";      ok=false; }
    [ -f "$PUBKEY" ] || { _fail "IT-1: bv4db-key.pub not found";            ok=false; }

    if [ "$ok" = "true" ]; then
        _pass "IT-1: infra state complete (compartment, subnet, secret, pubkey)"
        return 0
    else
        return 1
    fi
}

# ---------------------------------------------------------------------------
test_IT2_ssh_via_vault_key() {
    echo "=== IT-2: SSH access using key from vault ==="

    if [ ! -f "$COMPUTE_STATE" ]; then
        _fail "IT-2: state-bv4db-run.json not found — run run_bv_fio.sh KEEP_INFRA=true first"
        return 1
    fi

    local public_ip secret_ocid
    public_ip=$(jq -r '.compute.public_ip // empty' "$COMPUTE_STATE")
    secret_ocid=$(jq -r '.secret.ocid // empty'     "$INFRA_STATE")

    if [ -z "$public_ip" ]; then
        _fail "IT-2: no public IP in compute state"
        return 1
    fi
    if [ -z "$secret_ocid" ]; then
        _fail "IT-2: no secret OCID in infra state"
        return 1
    fi

    local tmpkey
    tmpkey=$(mktemp)
    chmod 600 "$tmpkey"

    if ! oci secrets secret-bundle get \
           --secret-id "$secret_ocid" \
           --query 'data."secret-bundle-content".content' --raw-output \
           | base64 --decode > "$tmpkey" 2>/dev/null; then
        rm -f "$tmpkey"
        _fail "IT-2: failed to retrieve private key from vault"
        return 1
    fi

    local ssh_out
    if ssh_out=$(ssh -i "$tmpkey" \
                     -o StrictHostKeyChecking=no \
                     -o ConnectTimeout=15 \
                     -o BatchMode=yes \
                     "opc@${public_ip}" "echo ok" 2>&1); then
        rm -f "$tmpkey"
        if [ "$ssh_out" = "ok" ]; then
            _pass "IT-2: SSH successful via vault key to $public_ip"
            return 0
        else
            _fail "IT-2: SSH connected but unexpected output: $ssh_out"
            return 1
        fi
    else
        rm -f "$tmpkey"
        _fail "IT-2: SSH failed to $public_ip — is compute running? (use KEEP_INFRA=true)"
        return 1
    fi
}

# ---------------------------------------------------------------------------
test_IT3_block_volume_mounted() {
    echo "=== IT-3: Block volume mounted at /mnt/bv ==="

    if [ ! -f "$COMPUTE_STATE" ]; then
        _fail "IT-3: state-bv4db-run.json not found — run run_bv_fio.sh KEEP_INFRA=true first"
        return 1
    fi

    local public_ip secret_ocid
    public_ip=$(jq -r '.compute.public_ip // empty' "$COMPUTE_STATE")
    secret_ocid=$(jq -r '.secret.ocid // empty'     "$INFRA_STATE")

    if [ -z "$public_ip" ] || [ -z "$secret_ocid" ]; then
        _fail "IT-3: missing public_ip or secret_ocid"
        return 1
    fi

    local tmpkey
    tmpkey=$(mktemp)
    chmod 600 "$tmpkey"

    oci secrets secret-bundle get \
        --secret-id "$secret_ocid" \
        --query 'data."secret-bundle-content".content' --raw-output \
        | base64 --decode > "$tmpkey" 2>/dev/null || {
        rm -f "$tmpkey"
        _fail "IT-3: failed to retrieve private key from vault"
        return 1
    }

    local mount_out
    if mount_out=$(ssh -i "$tmpkey" \
                       -o StrictHostKeyChecking=no \
                       -o ConnectTimeout=15 \
                       -o BatchMode=yes \
                       "opc@${public_ip}" \
                       "mountpoint -q /mnt/bv && echo mounted || echo not_mounted" 2>&1); then
        rm -f "$tmpkey"
        if [ "$mount_out" = "mounted" ]; then
            _pass "IT-3: /mnt/bv is mounted on $public_ip"
            return 0
        else
            _fail "IT-3: /mnt/bv is not mounted on $public_ip"
            return 1
        fi
    else
        rm -f "$tmpkey"
        _fail "IT-3: SSH failed — is compute running? (use KEEP_INFRA=true)"
        return 1
    fi
}

# ---------------------------------------------------------------------------
test_IT4_fio_report_produced() {
    echo "=== IT-4: fio performance report produced ==="

    if [ ! -f "$FIO_RESULTS" ]; then
        _fail "IT-4: fio-results.json not found — run run_bv_fio.sh first"
        return 1
    fi

    if ! jq empty "$FIO_RESULTS" 2>/dev/null; then
        _fail "IT-4: fio-results.json is not valid JSON"
        return 1
    fi

    local ok=true

    local seq_iops rand_iops
    seq_iops=$(jq -r '.sequential.jobs[0].read.iops // empty' "$FIO_RESULTS")
    rand_iops=$(jq -r '.random.jobs[0].read.iops // empty'    "$FIO_RESULTS")

    [ -n "$seq_iops"  ] || { _fail "IT-4: .sequential.jobs[0].read.iops missing"; ok=false; }
    [ -n "$rand_iops" ] || { _fail "IT-4: .random.jobs[0].read.iops missing";     ok=false; }

    if [ "$ok" = "true" ]; then
        local seq_bw rand_bw
        seq_bw=$(jq  '.sequential.jobs[0].read.bw  // 0 | . / 1024 | round' "$FIO_RESULTS")
        rand_bw=$(jq '.random.jobs[0].read.bw       // 0 | . / 1024 | round' "$FIO_RESULTS")
        _pass "IT-4: fio-results.json valid — seq read $(printf '%.0f' "$seq_iops") IOPS ${seq_bw} MB/s, rand read $(printf '%.0f' "$rand_iops") IOPS ${rand_bw} MB/s"
        return 0
    else
        return 1
    fi
}

# ---------------------------------------------------------------------------
run_all() {
    echo ""
    echo "=== BV4DB Integration Tests — Sprint 1 ==="
    echo ""

    test_IT1_infra_provisioned    || true
    test_IT2_ssh_via_vault_key    || true
    test_IT3_block_volume_mounted || true
    test_IT4_fio_report_produced  || true

    echo ""
    echo "Results: $PASS passed, $FAIL failed"
    [[ $FAIL -eq 0 ]]
}

run_all
