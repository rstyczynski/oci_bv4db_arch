#!/usr/bin/env bash
# run_oracle_db_sprint14.sh — Sprint 14: Oracle Database Free workload with AWR capture
#
# This script provisions infrastructure, runs database workload, captures AWR snapshots,
# and exports AWR report for benchmark analysis.
#
# BV4DB-36: Automated Oracle Database Free performance workload execution
# BV4DB-38: Automated AWR snapshot window capture for database benchmarks
# BV4DB-39: Automated AWR report export and archival for benchmark runs

set -euo pipefail
set -E

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCAFFOLD_DIR="$REPO_DIR/oci_scaffold"
PROGRESS_DIR="${PROGRESS_DIR:-$REPO_DIR/progress/sprint_14}"
SPRINT1_DIR="$REPO_DIR/progress/sprint_1"
INFRA_STATE="$SPRINT1_DIR/state-bv4db.json"
SPRINT_LABEL="${SPRINT_LABEL:-Sprint 14}"

export PATH="$SCAFFOLD_DIR/do:$SCAFFOLD_DIR/resource:$PATH"
export NAME_PREFIX="${NAME_PREFIX:-bv4db-oracle-wkld}"
export OCI_REGION="${OCI_REGION:-}"
export OCI_CLI_REGION="${OCI_CLI_REGION:-${OCI_REGION:-}}"

# Compute configuration
COMPUTE_SHAPE="${COMPUTE_SHAPE:-VM.Standard.E5.Flex}"
COMPUTE_OCPUS="${COMPUTE_OCPUS:-2}"
COMPUTE_MEMORY_GB="${COMPUTE_MEMORY_GB:-16}"

# Storage configuration
STORAGE_LAYOUT_MODE="${STORAGE_LAYOUT_MODE:-single_uhp}"
VPU_SINGLE="${VPU_SINGLE:-10}"
SIZE_SINGLE_GB="${SIZE_SINGLE_GB:-600}"

# Database configuration
ORACLE_PWD="${ORACLE_PWD:-BenchmarkPwd123}"

# Workload configuration
WORKLOAD_DURATION="${WORKLOAD_DURATION:-300}"  # 5 minutes default

# Whether to keep infrastructure after run
KEEP_INFRA="${KEEP_INFRA:-false}"

_on_err() {
    local ec=$? line=${BASH_LINENO[0]:-?} cmd=${BASH_COMMAND:-?}
    echo "  [FAIL] run_oracle_db_sprint14.sh failed (exit $ec) at line $line: $cmd" >&2
}
trap _on_err ERR

[ -f "$INFRA_STATE" ] || { echo "  [ERROR] Infra state not found: $INFRA_STATE" >&2; exit 1; }

mkdir -p "$PROGRESS_DIR"
cd "$PROGRESS_DIR"

source "$SCAFFOLD_DIR/do/oci_scaffold.sh"

ssh_opts=(
    -n
    -o StrictHostKeyChecking=no
    -o ConnectTimeout=15
    -o BatchMode=yes
)

scp_opts=(
    -B
    -o StrictHostKeyChecking=no
    -o ConnectTimeout=15
    -o BatchMode=yes
)

COMPARTMENT_OCID=$(jq -r '.compartment.ocid' "$INFRA_STATE")
SUBNET_OCID=$(jq -r '.subnet.ocid' "$INFRA_STATE")
SECRET_OCID=$(jq -r '.secret.ocid' "$INFRA_STATE")
PUBKEY_FILE="$SPRINT1_DIR/bv4db-key.pub"

[ -n "$COMPARTMENT_OCID" ] || { echo "  [ERROR] No compartment OCID in Sprint 1 infra state" >&2; exit 1; }
[ -f "$PUBKEY_FILE" ] || { echo "  [ERROR] SSH public key not found: $PUBKEY_FILE" >&2; exit 1; }

echo ""
echo "=========================================="
echo "  $SPRINT_LABEL: Database Workload + AWR"
echo "=========================================="
echo ""
echo "Configuration:"
echo "  Compute: $COMPUTE_SHAPE ($COMPUTE_OCPUS OCPUs, $COMPUTE_MEMORY_GB GB)"
echo "  Storage: $STORAGE_LAYOUT_MODE ($SIZE_SINGLE_GB GB, $VPU_SINGLE VPU/GB)"
echo "  Workload duration: $WORKLOAD_DURATION seconds"
echo "  Keep infra: $KEEP_INFRA"
echo ""

# Volume configuration
declare -A VOLUMES
VOLUMES[singleuhp]="/dev/oracleoci/oraclevdb:${VPU_SINGLE}:${SIZE_SINGLE_GB}"

enable_block_volume_plugin() {
    local instance_id="$1"
    oci compute instance update \
        --instance-id "$instance_id" \
        --agent-config '{"areAllPluginsDisabled":false,"isManagementDisabled":false,"isMonitoringDisabled":false,"pluginsConfig":[{"name":"Block Volume Management","desiredState":"ENABLED"}]}' \
        --force >/dev/null
}

prepare_guest_block_device() {
    local attach_id="$1"
    local expected_path="$2"
    local attachment_json iqn port
    local -a target_ips=()

    attachment_json=$(oci compute volume-attachment get --volume-attachment-id "$attach_id")
    iqn=$(echo "$attachment_json" | jq -r '.data.iqn')
    port=$(echo "$attachment_json" | jq -r '.data.port')
    mapfile -t target_ips < <(echo "$attachment_json" | jq -r '([.data.ipv4] + [.data."multipath-devices"[]?.ipv4]) | unique[]')

    _ssh_script sudo bash -s -- "$iqn" "$port" "$expected_path" "${target_ips[@]}" <<'EOF'
set -euo pipefail
IQN="$1"
PORT="$2"
DEVICE_PATH="$3"
shift 3
TARGETS=("$@")

systemctl enable --now iscsid >/dev/null
mpathconf --enable --with_multipathd y >/dev/null 2>&1 || true
systemctl enable --now multipathd >/dev/null

for host in "${TARGETS[@]}"; do
    iscsiadm -m node -o new -T "$IQN" -p "${host}:${PORT}" >/dev/null 2>&1 || true
    iscsiadm -m node -T "$IQN" -p "${host}:${PORT}" --op update -n node.startup -v automatic >/dev/null
    iscsiadm -m node -T "$IQN" -p "${host}:${PORT}" --login >/dev/null 2>&1 || true
done

udevadm settle
for _ in $(seq 1 24); do
    if [ -b "$DEVICE_PATH" ]; then
        exit 0
    fi
    sleep 5
done
exit 1
EOF
}

resolve_mpath_device() {
    local expected_path="$1"
    _ssh_script sudo bash -s -- "$expected_path" <<'EOF'
set -euo pipefail
EXPECTED_PATH="$1"
RESOLVED_PATH=$(readlink -f "$EXPECTED_PATH" 2>/dev/null || echo "$EXPECTED_PATH")
DEVICE="$RESOLVED_PATH"
while :; do
    TYPE=$(lsblk -dnro TYPE "$DEVICE" 2>/dev/null || true)
    if [ "$TYPE" = "mpath" ]; then
        echo "$DEVICE"
        exit 0
    fi
    PKNAME=$(lsblk -dnro PKNAME "$DEVICE" 2>/dev/null || true)
    if [ -z "${PKNAME:-}" ]; then
        break
    fi
    DEVICE="/dev/$PKNAME"
done
SERIAL=$(lsblk -dnro SERIAL "$RESOLVED_PATH" 2>/dev/null || true)
if [ -n "${SERIAL:-}" ]; then
    MAPPER_NAME=$(multipath -ll 2>/dev/null | awk -v s="3${SERIAL}" '$1 ~ /^mpath/ && $2 == "(" s ")" { print $1; exit }')
    if [ -n "${MAPPER_NAME:-}" ]; then
        echo "/dev/mapper/${MAPPER_NAME}"
        exit 0
    fi
fi
echo "$EXPECTED_PATH"
EOF
}

# Initialize state
[ -n "$OCI_REGION" ] && _state_set '.inputs.oci_region' "$OCI_REGION"
_state_set '.inputs.name_prefix'                      "$NAME_PREFIX"
_state_set '.inputs.oci_compartment'                  "$COMPARTMENT_OCID"
_state_set '.subnet.ocid'                             "$SUBNET_OCID"
_state_set '.inputs.compute_shape'                    "$COMPUTE_SHAPE"
_state_set '.inputs.compute_ocpus'                    "$COMPUTE_OCPUS"
_state_set '.inputs.compute_memory_gb'                "$COMPUTE_MEMORY_GB"
_state_set '.inputs.subnet_prohibit_public_ip'        'false'
_state_set '.inputs.compute_ssh_authorized_keys_file' "$PUBKEY_FILE"
_state_set '.inputs.storage_layout_mode'              "$STORAGE_LAYOUT_MODE"
_state_set '.inputs.workload_duration'                "$WORKLOAD_DURATION"

# Provision compute
echo "  [INFO] Provisioning compute instance ..."
ensure-compute.sh
enable_block_volume_plugin "$(_state_get '.compute.ocid')"
PUBLIC_IP=$(_state_get '.compute.public_ip')
INSTANCE_OCID=$(_state_get '.compute.ocid')
echo "  [INFO] Compute instance ready: $PUBLIC_IP"

# Get SSH key
TMPKEY=$(mktemp)
chmod 600 "$TMPKEY"
oci secrets secret-bundle get \
    --secret-id "$SECRET_OCID" \
    --query 'data."secret-bundle-content".content' --raw-output \
    | base64 --decode > "$TMPKEY"

_ssh() {
    ssh -i "$TMPKEY" "${ssh_opts[@]}" "opc@${PUBLIC_IP}" "$@"
}

_ssh_script() {
    ssh -i "$TMPKEY" -o StrictHostKeyChecking=no -o ConnectTimeout=15 -o BatchMode=yes "opc@${PUBLIC_IP}" "$@"
}

_scp_to_remote() {
    local src="$1"
    local dst="$2"
    scp -i "$TMPKEY" "${scp_opts[@]}" "$src" "opc@${PUBLIC_IP}:$dst"
}

_scp_from_remote() {
    local src="$1"
    local dst="$2"
    scp -i "$TMPKEY" "${scp_opts[@]}" "opc@${PUBLIC_IP}:$src" "$dst"
}

# Wait for SSH
echo "  [INFO] Waiting for SSH on $PUBLIC_IP ..."
ssh-keygen -R "$PUBLIC_IP" >/dev/null 2>&1 || true
elapsed=0
while ! _ssh true 2>/dev/null; do
    sleep 5
    elapsed=$((elapsed + 5))
    printf "\033[2K\r  [WAIT] SSH %ds" "$elapsed"
    if [ "$elapsed" -ge 300 ]; then
        echo ""
        echo "  [ERROR] SSH did not become available within 300 seconds" >&2
        exit 1
    fi
done
echo ""

# Provision block volume
echo "  [INFO] Provisioning block volume ..."
declare -A ATTACH_OCIDS
declare -A MPATH_DEVICES
MAIN_NAME_PREFIX="$NAME_PREFIX"

vol_name="singleuhp"
IFS=':' read -r dev_path vpu size_gb <<< "${VOLUMES[$vol_name]}"
echo "  [INFO] Provisioning block volume: $vol_name ($size_gb GB, $vpu VPU/GB) ..."

vol_state="$PROGRESS_DIR/state-bv-${vol_name}.json"
export NAME_PREFIX="bv-${vol_name}"
export STATE_FILE="$vol_state"

_state_set '.inputs.name_prefix' "$NAME_PREFIX"
_state_set '.inputs.oci_compartment' "$COMPARTMENT_OCID"
_state_set '.inputs.bv_size_gb' "$size_gb"
_state_set '.inputs.bv_vpus_per_gb' "$vpu"
_state_set '.inputs.bv_attach_type' 'iscsi'
_state_set '.inputs.bv_device_path' "$dev_path"
_state_set '.compute.ocid' "$INSTANCE_OCID"

ensure-blockvolume.sh

ATTACH_OCIDS[$vol_name]=$(_state_get '.blockvolume.attachment_ocid')
VOL_OCID=$(_state_get '.blockvolume.ocid')

echo "  [INFO] Preparing iSCSI for $vol_name ..."
prepare_guest_block_device "${ATTACH_OCIDS[$vol_name]}" "$dev_path"

MPATH_DEVICES[$vol_name]=$(resolve_mpath_device "$dev_path")
echo "  [INFO] $vol_name mpath device: ${MPATH_DEVICES[$vol_name]}"

export NAME_PREFIX="$MAIN_NAME_PREFIX"
export STATE_FILE="$PROGRESS_DIR/state-${NAME_PREFIX}.json"
_state_set ".volumes.${vol_name}.ocid" "$VOL_OCID"
_state_set ".volumes.${vol_name}.attachment_ocid" "${ATTACH_OCIDS[$vol_name]}"
_state_set ".volumes.${vol_name}.device_path" "$dev_path"

# Configure storage layout
echo "  [INFO] Configuring Oracle database storage layout ..."
_scp_to_remote "$REPO_DIR/tools/configure_oracle_db_layout.sh" "/tmp/configure_oracle_db_layout.sh"
_ssh "chmod +x /tmp/configure_oracle_db_layout.sh && \
      sudo STORAGE_LAYOUT_MODE=single_uhp \
           SINGLE_DEV='${MPATH_DEVICES[singleuhp]}' \
           LOG_FILE=/tmp/oracle-storage-layout.log \
           /tmp/configure_oracle_db_layout.sh"
echo "  [INFO] Storage layout configured"

# Install Oracle Database Free
echo "  [INFO] Installing Oracle Database Free 23ai ..."
_scp_to_remote "$REPO_DIR/tools/install_oracle_db_free.sh" "/tmp/install_oracle_db_free.sh"
_ssh "chmod +x /tmp/install_oracle_db_free.sh && \
      sudo ORACLE_PWD='$ORACLE_PWD' \
           LOG_FILE=/tmp/oracle-db-free-install.log \
           /tmp/install_oracle_db_free.sh"
_scp_from_remote "/tmp/oracle-db-free-install.log" "$PROGRESS_DIR/db-install.log" 2>/dev/null || true
echo "  [INFO] Oracle Database Free installed"

# Copy workload and AWR scripts
echo "  [INFO] Deploying workload and AWR scripts ..."
_scp_to_remote "$REPO_DIR/tools/run_oracle_workload.sh" "/tmp/run_oracle_workload.sh"
_scp_to_remote "$REPO_DIR/tools/capture_awr_snapshot.sh" "/tmp/capture_awr_snapshot.sh"
_scp_to_remote "$REPO_DIR/tools/export_awr_report.sh" "/tmp/export_awr_report.sh"
_ssh "chmod +x /tmp/run_oracle_workload.sh /tmp/capture_awr_snapshot.sh /tmp/export_awr_report.sh"

# Record benchmark start time
BENCHMARK_START=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
_state_set '.benchmark.start_time' "$BENCHMARK_START"

# Capture AWR begin snapshot
echo "  [INFO] Capturing AWR begin snapshot ..."
BEGIN_SNAP_ID=$(_ssh "sudo su - oracle -c '/tmp/capture_awr_snapshot.sh begin /tmp/awr_begin_snap_id.txt'" | tail -1)
echo "  [INFO] Begin snapshot ID: $BEGIN_SNAP_ID"
_state_set '.awr.begin_snap_id' "$BEGIN_SNAP_ID"

# Run workload
echo "  [INFO] Running database workload ($WORKLOAD_DURATION seconds) ..."
_ssh "sudo su - oracle -c 'WORKLOAD_DURATION=$WORKLOAD_DURATION LOG_FILE=/tmp/workload_results.log /tmp/run_oracle_workload.sh $WORKLOAD_DURATION'"
echo "  [INFO] Workload completed"

# Capture AWR end snapshot
echo "  [INFO] Capturing AWR end snapshot ..."
END_SNAP_ID=$(_ssh "sudo su - oracle -c '/tmp/capture_awr_snapshot.sh end /tmp/awr_end_snap_id.txt'" | tail -1)
echo "  [INFO] End snapshot ID: $END_SNAP_ID"
_state_set '.awr.end_snap_id' "$END_SNAP_ID"

# Record benchmark end time
BENCHMARK_END=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
_state_set '.benchmark.end_time' "$BENCHMARK_END"

# Export AWR report
echo "  [INFO] Generating AWR report ..."
_ssh "sudo su - oracle -c '/tmp/export_awr_report.sh $BEGIN_SNAP_ID $END_SNAP_ID /tmp/awr_report.html'"
echo "  [INFO] AWR report generated"

# Collect artifacts
echo "  [INFO] Collecting artifacts ..."
_scp_from_remote "/tmp/awr_begin_snap_id.txt" "$PROGRESS_DIR/awr_begin_snap_id.txt"
_scp_from_remote "/tmp/awr_end_snap_id.txt" "$PROGRESS_DIR/awr_end_snap_id.txt"
_scp_from_remote "/tmp/awr_report.html" "$PROGRESS_DIR/awr_report.html"
_scp_from_remote "/tmp/workload_results.log" "$PROGRESS_DIR/workload_results.log"
_scp_from_remote "/tmp/oracle-storage-layout.log" "$PROGRESS_DIR/storage-layout.log" 2>/dev/null || true

# Get database status
echo "  [INFO] Verifying database status ..."
DB_STATUS_OUTPUT=$(_ssh "sudo su - oracle -c 'source ~/.oracle_env && sqlplus -S / as sysdba' <<'SQL'
set linesize 200
set pagesize 100
col instance_name format a15
col status format a15
col name format a20
col open_mode format a15

prompt === Instance Status ===
select instance_name, status, database_status from v\$instance;

prompt
prompt === PDB Status ===
select name, open_mode from v\$pdbs;

prompt
prompt === AWR Snapshots for this run ===
select snap_id, to_char(end_interval_time, 'YYYY-MM-DD HH24:MI:SS') as snap_time
from dba_hist_snapshot
where snap_id >= $BEGIN_SNAP_ID
order by snap_id;

exit;
SQL
")
echo "$DB_STATUS_OUTPUT" > "$PROGRESS_DIR/db-status.log"

# Save state
_state_set '.database.oracle_home' '/opt/oracle/product/23ai/dbhomeFree'
_state_set '.database.oracle_sid' 'FREE'
_state_set '.database.oracle_pdb' 'FREEPDB1'
_state_set '.sprint' '14'

# Generate summary report
SUMMARY_FILE="$PROGRESS_DIR/sprint_14_summary.md"
{
    echo "# Sprint 14 Summary"
    echo ""
    echo "## Infrastructure"
    echo ""
    echo "- Compute: \`$COMPUTE_SHAPE\` ($COMPUTE_OCPUS OCPUs, $COMPUTE_MEMORY_GB GB RAM)"
    echo "- Public IP: \`$PUBLIC_IP\`"
    echo "- Storage: Single block volume ($SIZE_SINGLE_GB GB, $VPU_SINGLE VPU/GB)"
    echo ""
    echo "## Benchmark Window"
    echo ""
    echo "- Start: \`$BENCHMARK_START\`"
    echo "- End: \`$BENCHMARK_END\`"
    echo "- Workload duration: \`$WORKLOAD_DURATION seconds\`"
    echo ""
    echo "## AWR Snapshots"
    echo ""
    echo "- Begin Snapshot ID: \`$BEGIN_SNAP_ID\`"
    echo "- End Snapshot ID: \`$END_SNAP_ID\`"
    echo ""
    echo "## Artifacts"
    echo ""
    echo "| File | Description |"
    echo "|------|-------------|"
    echo "| \`awr_report.html\` | AWR report for benchmark window |"
    echo "| \`workload_results.log\` | Workload execution output |"
    echo "| \`awr_begin_snap_id.txt\` | Begin snapshot ID |"
    echo "| \`awr_end_snap_id.txt\` | End snapshot ID |"
    echo "| \`db-status.log\` | Database status verification |"
    echo ""
    echo "## Validation Results"
    echo ""
    echo "- [x] Workload executed automatically"
    echo "- [x] AWR begin snapshot captured"
    echo "- [x] AWR end snapshot captured"
    echo "- [x] AWR report generated and archived"
    echo ""
    echo "## Database Status"
    echo ""
    echo "\`\`\`"
    echo "$DB_STATUS_OUTPUT"
    echo "\`\`\`"
} > "$SUMMARY_FILE"

echo ""
echo "  [INFO] Summary saved: $SUMMARY_FILE"

rm -f "$TMPKEY"

# Teardown (unless KEEP_INFRA=true)
if [ "$KEEP_INFRA" = "true" ]; then
    echo ""
    echo "  [INFO] Infrastructure kept running (KEEP_INFRA=true)"
    echo "  [INFO] SSH: ssh -i <key> opc@$PUBLIC_IP"
else
    echo ""
    echo "  [INFO] Tearing down compute and block volumes ..."

    # Archive state files
    cp "$PROGRESS_DIR/state-bv-singleuhp.json" "$PROGRESS_DIR/state-bv-singleuhp-archived.json" 2>/dev/null || true
    cp "$PROGRESS_DIR/state-${MAIN_NAME_PREFIX}.json" "$PROGRESS_DIR/state-${MAIN_NAME_PREFIX}-archived.json" 2>/dev/null || true

    # Teardown volume
    vol_state="$PROGRESS_DIR/state-bv-singleuhp.json"
    if [ -f "$vol_state" ]; then
        export NAME_PREFIX="bv-singleuhp"
        export STATE_FILE="$vol_state"
        "$SCAFFOLD_DIR/do/teardown.sh" || true
    fi

    # Teardown compute
    export NAME_PREFIX="$MAIN_NAME_PREFIX"
    export STATE_FILE="$PROGRESS_DIR/state-${NAME_PREFIX}.json"
    "$SCAFFOLD_DIR/do/teardown.sh"

    echo "  [INFO] Teardown complete"
fi

echo ""
echo "=========================================="
echo "  $SPRINT_LABEL: Complete"
echo "=========================================="
echo ""

print_summary
