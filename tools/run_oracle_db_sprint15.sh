#!/usr/bin/env bash
# run_oracle_db_sprint15.sh — Sprint 15: Swingbench-standardized Oracle load run with AWR capture
#
# BV4DB-41: Swingbench as the standard Oracle Database Free load generator

set -euo pipefail
set -E

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCAFFOLD_DIR="$REPO_DIR/oci_scaffold"
PROGRESS_DIR="${PROGRESS_DIR:-$REPO_DIR/progress/sprint_15}"
SPRINT1_DIR="$REPO_DIR/progress/sprint_1"
INFRA_STATE="$SPRINT1_DIR/state-bv4db.json"
SPRINT_LABEL="${SPRINT_LABEL:-Sprint 15}"
SWINGBENCH_CONFIG_LOCAL="${SWINGBENCH_CONFIG_LOCAL:-$REPO_DIR/config/swingbench/SOE_Server_Side_V2.xml}"

export PATH="$SCAFFOLD_DIR/do:$SCAFFOLD_DIR/resource:$PATH"
export NAME_PREFIX="${NAME_PREFIX:-bv4db-oracle-sb}"
export OCI_REGION="${OCI_REGION:-}"
export OCI_CLI_REGION="${OCI_CLI_REGION:-${OCI_REGION:-}}"

COMPUTE_SHAPE="${COMPUTE_SHAPE:-VM.Standard.E5.Flex}"
COMPUTE_OCPUS="${COMPUTE_OCPUS:-2}"
COMPUTE_MEMORY_GB="${COMPUTE_MEMORY_GB:-16}"
STORAGE_LAYOUT_MODE="${STORAGE_LAYOUT_MODE:-single_uhp}"
VPU_SINGLE="${VPU_SINGLE:-10}"
SIZE_SINGLE_GB="${SIZE_SINGLE_GB:-600}"
ORACLE_PWD="${ORACLE_PWD:-BenchmarkPwd123}"
WORKLOAD_DURATION="${WORKLOAD_DURATION:-300}"
SWINGBENCH_USERS="${SWINGBENCH_USERS:-4}"
SWINGBENCH_SCALE="${SWINGBENCH_SCALE:-1}"
SWINGBENCH_BUILD_THREADS="${SWINGBENCH_BUILD_THREADS:-4}"
KEEP_INFRA="${KEEP_INFRA:-false}"

_on_err() {
    local ec=$? line=${BASH_LINENO[0]:-?} cmd=${BASH_COMMAND:-?}
    echo "  [FAIL] run_oracle_db_sprint15.sh failed (exit $ec) at line $line: $cmd" >&2
}
trap _on_err ERR

[ -f "$INFRA_STATE" ] || { echo "  [ERROR] Infra state not found: $INFRA_STATE" >&2; exit 1; }
[ -f "$SWINGBENCH_CONFIG_LOCAL" ] || { echo "  [ERROR] Swingbench config not found: $SWINGBENCH_CONFIG_LOCAL" >&2; exit 1; }

mkdir -p "$PROGRESS_DIR"
cd "$PROGRESS_DIR"

source "$SCAFFOLD_DIR/do/oci_scaffold.sh"

archive_stale_state_file() {
    local path="$1"
    [ -f "$path" ] || return 0
    local ts archived
    ts=$(date -u +"%Y%m%dT%H%M%SZ")
    archived="${path%.json}.pre-run-${ts}.json"
    mv "$path" "$archived"
    echo "  [INFO] Archived stale state file: $archived"
}

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
echo "  $SPRINT_LABEL: Swingbench + AWR"
echo "=========================================="
echo ""
echo "Configuration:"
echo "  Compute: $COMPUTE_SHAPE ($COMPUTE_OCPUS OCPUs, $COMPUTE_MEMORY_GB GB)"
echo "  Storage: $STORAGE_LAYOUT_MODE ($SIZE_SINGLE_GB GB, $VPU_SINGLE VPU/GB)"
echo "  Workload duration: $WORKLOAD_DURATION seconds"
echo "  Swingbench users: $SWINGBENCH_USERS"
echo "  Swingbench scale: $SWINGBENCH_SCALE"
echo "  Keep infra: $KEEP_INFRA"
echo ""

declare -A VOLUMES
VOLUMES[singleuhp]="/dev/oracleoci/oraclevdb:${VPU_SINGLE}:${SIZE_SINGLE_GB}"

archive_stale_state_file "$PROGRESS_DIR/state-${NAME_PREFIX}.json"
archive_stale_state_file "$PROGRESS_DIR/state-bv-singleuhp.json"

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

    local attempt
    for attempt in 1 2 3 4 5; do
        if _ssh_script sudo bash -s -- "$iqn" "$port" "$expected_path" "${target_ips[@]}" <<'EOF'
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
        then
            return 0
        fi
        echo "  [WARN] iSCSI guest preparation attempt $attempt failed; waiting for SSH recovery ..."
        sleep 15
        until _ssh true 2>/dev/null; do
            sleep 5
        done
    done
    return 1
}

wait_for_stable_ssh() {
    local label="$1"
    local timeout_seconds="${2:-180}"
    local elapsed=0
    local stable_hits=0
    while [ "$elapsed" -lt "$timeout_seconds" ]; do
        if _ssh true >/dev/null 2>&1; then
            stable_hits=$((stable_hits + 1))
            if [ "$stable_hits" -ge 3 ]; then
                return 0
            fi
        else
            stable_hits=0
        fi
        sleep 5
        elapsed=$((elapsed + 5))
    done
    echo "  [ERROR] SSH did not stabilize after $label within ${timeout_seconds}s" >&2
    return 1
}

resolve_mpath_device() {
    local expected_path="$1"
    local attempt
    for attempt in 1 2 3 4 5; do
        if _ssh_script sudo bash -s -- "$expected_path" <<'EOF'
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
        then
            return 0
        fi
        echo "  [WARN] multipath device resolution attempt $attempt failed; waiting for SSH recovery ..."
        sleep 15
        wait_for_stable_ssh "multipath device resolution" 180
    done
    return 1
}

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
_state_set '.load_generator.name'                     'swingbench'

echo "  [INFO] Provisioning compute instance ..."
ensure-compute.sh
enable_block_volume_plugin "$(_state_get '.compute.ocid')"
PUBLIC_IP=$(_state_get '.compute.public_ip')
INSTANCE_OCID=$(_state_get '.compute.ocid')
echo "  [INFO] Compute instance ready: $PUBLIC_IP"

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

_tail_remote_file() {
    local path="$1"
    _ssh "if [ -f '$path' ]; then tail -n 40 '$path'; fi" 2>/dev/null || true
}

_run_remote_step() {
    local step_name="$1"
    local run_as="$2"
    local timeout_seconds="$3"
    local remote_log="$4"
    local body="$5"

    local slug
    slug=$(echo "$step_name" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-')

    local local_script
    local_script=$(mktemp)

    local remote_script="/tmp/${slug}.sh"
    local remote_pid="/tmp/${slug}.pid"
    local remote_status="/tmp/${slug}.status"
    local remote_log_dir
    remote_log_dir=$(dirname "$remote_log")

    cat >"$local_script" <<EOF
#!/usr/bin/env bash
mkdir -p '$remote_log_dir'
STATUS_FILE='$remote_status'
LOG_FILE='$remote_log'
trap 'rc=\$?; printf "%s" "\$rc" > "\$STATUS_FILE"; exit "\$rc"' EXIT
exec >"\$LOG_FILE" 2>&1
set -euo pipefail
$body
EOF
    chmod 755 "$local_script"
    _scp_to_remote "$local_script" "$remote_script"
    rm -f "$local_script"

    _ssh "rm -f '$remote_pid' '$remote_status' '$remote_log'; chmod 755 '$remote_script'"

    if [ "$run_as" = "oracle" ]; then
        _ssh "nohup sudo su - oracle -c '$remote_script' </dev/null >/dev/null 2>&1 & echo \$! > '$remote_pid'"
    else
        _ssh "nohup sudo '$remote_script' </dev/null >/dev/null 2>&1 & echo \$! > '$remote_pid'"
    fi

    local elapsed=0
    local poll_interval=10
    local state
    while true; do
        state=$(_ssh "if [ -f '$remote_status' ]; then cat '$remote_status'; elif [ -f '$remote_pid' ] && kill -0 \$(cat '$remote_pid') 2>/dev/null; then echo RUNNING; else echo UNKNOWN; fi")
        case "$state" in
            RUNNING)
                elapsed=$((elapsed + poll_interval))
                printf "\033[2K\r  [WAIT] %s … %ds" "$step_name" "$elapsed"
                if [ "$elapsed" -ge "$timeout_seconds" ]; then
                    echo ""
                    echo "  [ERROR] $step_name timed out after ${timeout_seconds}s" >&2
                    _tail_remote_file "$remote_log" >&2
                    return 1
                fi
                sleep "$poll_interval"
                ;;
            ''|UNKNOWN)
                echo ""
                echo "  [ERROR] $step_name lost remote status tracking" >&2
                _tail_remote_file "$remote_log" >&2
                return 1
                ;;
            0)
                echo ""
                return 0
                ;;
            *)
                echo ""
                echo "  [ERROR] $step_name failed with remote exit code $state" >&2
                _tail_remote_file "$remote_log" >&2
                return 1
                ;;
        esac
    done
}

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
wait_for_stable_ssh "iSCSI guest preparation" 180

MPATH_DEVICES[$vol_name]=$(resolve_mpath_device "$dev_path")
echo "  [INFO] $vol_name mpath device: ${MPATH_DEVICES[$vol_name]}"

export NAME_PREFIX="$MAIN_NAME_PREFIX"
export STATE_FILE="$PROGRESS_DIR/state-${NAME_PREFIX}.json"
_state_set ".volumes.${vol_name}.ocid" "$VOL_OCID"
_state_set ".volumes.${vol_name}.attachment_ocid" "${ATTACH_OCIDS[$vol_name]}"
_state_set ".volumes.${vol_name}.device_path" "$dev_path"

echo "  [INFO] Configuring Oracle database storage layout ..."
_scp_to_remote "$REPO_DIR/tools/configure_oracle_db_layout.sh" "/tmp/configure_oracle_db_layout.sh"
_ssh "chmod +x /tmp/configure_oracle_db_layout.sh"
_run_remote_step \
    "Oracle storage layout" \
    root \
    900 \
    /tmp/oracle-storage-layout.log \
    "STORAGE_LAYOUT_MODE=single_uhp SINGLE_DEV='${MPATH_DEVICES[singleuhp]}' LOG_FILE=/tmp/oracle-storage-layout.log /tmp/configure_oracle_db_layout.sh"

echo "  [INFO] Installing Oracle Database Free 23ai ..."
_scp_to_remote "$REPO_DIR/tools/install_oracle_db_free.sh" "/tmp/install_oracle_db_free.sh"
_ssh "chmod +x /tmp/install_oracle_db_free.sh"
_run_remote_step \
    "Oracle Database install" \
    root \
    2400 \
    /tmp/oracle-db-free-install.log \
    "ORACLE_PWD='$ORACLE_PWD' LOG_FILE=/tmp/oracle-db-free-install.log /tmp/install_oracle_db_free.sh"
_scp_from_remote "/tmp/oracle-db-free-install.log" "$PROGRESS_DIR/db-install.log" 2>/dev/null || true

echo "  [INFO] Deploying Swingbench and AWR scripts ..."
_scp_to_remote "$REPO_DIR/tools/install_swingbench.sh" "/tmp/install_swingbench.sh"
_scp_to_remote "$REPO_DIR/tools/install_hammerdb.sh" "/tmp/install_hammerdb.sh"
_scp_to_remote "$REPO_DIR/tools/run_oracle_swingbench.sh" "/tmp/run_oracle_swingbench.sh"
_scp_to_remote "$REPO_DIR/tools/capture_awr_snapshot.sh" "/tmp/capture_awr_snapshot.sh"
_scp_to_remote "$REPO_DIR/tools/export_awr_report.sh" "/tmp/export_awr_report.sh"
_scp_to_remote "$SWINGBENCH_CONFIG_LOCAL" "/tmp/SOE_Server_Side_V2.xml"
_ssh "chmod +x /tmp/install_swingbench.sh /tmp/install_hammerdb.sh /tmp/run_oracle_swingbench.sh /tmp/capture_awr_snapshot.sh /tmp/export_awr_report.sh"

echo "  [INFO] Installing Swingbench ..."
_run_remote_step \
    "Swingbench install" \
    root \
    600 \
    /tmp/install-swingbench.log \
    "INSTALL_DIR=/opt/swingbench INSTALL_OWNER=oracle:oinstall LOG_FILE=/tmp/install-swingbench.log /tmp/install_swingbench.sh"
_scp_from_remote "/tmp/install-swingbench.log" "$PROGRESS_DIR/install-swingbench.log" 2>/dev/null || true

BENCHMARK_START=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
_state_set '.benchmark.start_time' "$BENCHMARK_START"

echo "  [INFO] Capturing AWR begin snapshot ..."
BEGIN_SNAP_ID=$(_ssh "sudo su - oracle -c '/tmp/capture_awr_snapshot.sh begin /tmp/awr_begin_snap_id.txt'" | tail -1)
echo "  [INFO] Begin snapshot ID: $BEGIN_SNAP_ID"
_state_set '.awr.begin_snap_id' "$BEGIN_SNAP_ID"

echo "  [INFO] Running Swingbench workload ($WORKLOAD_DURATION seconds) ..."
_run_remote_step \
    "Swingbench workload" \
    oracle \
    "$((WORKLOAD_DURATION + 1800))" \
    /tmp/swingbench/charbench.log \
    "ORACLE_PWD=$ORACLE_PWD \
WORKLOAD_DURATION=$WORKLOAD_DURATION \
SWINGBENCH_USERS=$SWINGBENCH_USERS \
SWINGBENCH_SCALE=$SWINGBENCH_SCALE \
SWINGBENCH_BUILD_THREADS=$SWINGBENCH_BUILD_THREADS \
RESULTS_DIR=/tmp/swingbench \
LOG_FILE=/tmp/swingbench/charbench.log \
RESULTS_XML=/tmp/swingbench/results.xml \
RESULTS_TXT=/tmp/swingbench/results.txt \
RESULTS_DB_JSON=/tmp/swingbench/results_db.json \
CONFIG_FILE=/tmp/SOE_Server_Side_V2.xml \
SWINGBENCH_HOME=/opt/swingbench \
/tmp/run_oracle_swingbench.sh $WORKLOAD_DURATION"

echo "  [INFO] Capturing AWR end snapshot ..."
END_SNAP_ID=$(_ssh "sudo su - oracle -c '/tmp/capture_awr_snapshot.sh end /tmp/awr_end_snap_id.txt'" | tail -1)
echo "  [INFO] End snapshot ID: $END_SNAP_ID"
_state_set '.awr.end_snap_id' "$END_SNAP_ID"

BENCHMARK_END=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
_state_set '.benchmark.end_time' "$BENCHMARK_END"

echo "  [INFO] Generating AWR report ..."
_run_remote_step \
    "AWR report export" \
    oracle \
    900 \
    /tmp/awr_export.log \
    "/tmp/export_awr_report.sh $BEGIN_SNAP_ID $END_SNAP_ID /tmp/awr_report.html"

_ssh "sudo chmod a+r /tmp/awr_begin_snap_id.txt /tmp/awr_end_snap_id.txt /tmp/awr_report.html 2>/dev/null || true; \
      sudo chmod -R a+rX /tmp/swingbench 2>/dev/null || true; \
      sudo chmod a+r /tmp/oracle-storage-layout.log 2>/dev/null || true"

echo "  [INFO] Collecting artifacts ..."
_scp_from_remote "/tmp/awr_begin_snap_id.txt" "$PROGRESS_DIR/awr_begin_snap_id.txt"
_scp_from_remote "/tmp/awr_end_snap_id.txt" "$PROGRESS_DIR/awr_end_snap_id.txt"
_scp_from_remote "/tmp/awr_report.html" "$PROGRESS_DIR/awr_report.html"
_scp_from_remote "/tmp/swingbench/charbench.log" "$PROGRESS_DIR/swingbench_charbench.log"
_scp_from_remote "/tmp/swingbench/results.xml" "$PROGRESS_DIR/swingbench_results.xml"
_scp_from_remote "/tmp/swingbench/results.txt" "$PROGRESS_DIR/swingbench_results.txt" 2>/dev/null || true
_scp_from_remote "/tmp/swingbench/results_db.json" "$PROGRESS_DIR/swingbench_results_db.json" 2>/dev/null || true
_scp_from_remote "/tmp/oracle-storage-layout.log" "$PROGRESS_DIR/storage-layout.log" 2>/dev/null || true
cp "$SWINGBENCH_CONFIG_LOCAL" "$PROGRESS_DIR/swingbench_config.xml"

echo "  [INFO] Rendering Swingbench HTML report ..."
"$REPO_DIR/tools/render_swingbench_report_html.sh" \
    "$PROGRESS_DIR/swingbench_results.xml" \
    "$PROGRESS_DIR/swingbench_charbench.log" \
    "$PROGRESS_DIR/swingbench_results_db.json" \
    "$PROGRESS_DIR/swingbench_report.html"

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

exit;
SQL
")
echo "$DB_STATUS_OUTPUT" > "$PROGRESS_DIR/db-status.log"

_state_set '.database.oracle_home' '/opt/oracle/product/23ai/dbhomeFree'
_state_set '.database.oracle_sid' 'FREE'
_state_set '.database.oracle_pdb' 'FREEPDB1'
_state_set '.sprint' '15'

SUMMARY_FILE="$PROGRESS_DIR/sprint_15_summary.md"
{
    echo "# Sprint 15 Summary"
    echo ""
    echo "## Standard Load Generator"
    echo ""
    echo "- Primary tool: \`Swingbench\`"
    echo "- Fallback tool: \`HammerDB\` (documented installer only; activate if Swingbench proves unsuitable)"
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
    echo "- Swingbench users: \`$SWINGBENCH_USERS\`"
    echo "- Swingbench scale: \`$SWINGBENCH_SCALE\`"
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
    echo "| \`swingbench_charbench.log\` | Charbench execution log |"
    echo "| \`swingbench_config.xml\` | Project-owned Swingbench workload configuration used for the run |"
    echo "| \`swingbench_results.xml\` | Raw Swingbench XML results |"
    echo "| \`swingbench_report.html\` | HTML presentation of Swingbench benchmark results |"
    echo "| \`swingbench_results.txt\` | Text-rendered Swingbench summary |"
    echo "| \`swingbench_results_db.json\` | Latest BENCHMARK_RESULTS row exported from Oracle |"
    echo "| \`awr_report.html\` | AWR report for benchmark window |"
    echo "| \`db-status.log\` | Database status verification |"
    echo ""
    echo "## Validation Results"
    echo ""
    echo "- [x] Swingbench installed automatically"
    echo "- [x] Swingbench SOE workload executed automatically"
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

if [ "$KEEP_INFRA" = "true" ]; then
    echo ""
    echo "  [INFO] Infrastructure kept running (KEEP_INFRA=true)"
    echo "  [INFO] SSH: ssh -i <key> opc@$PUBLIC_IP"
else
    echo ""
    echo "  [INFO] Tearing down compute and block volumes ..."

    cp "$PROGRESS_DIR/state-bv-singleuhp.json" "$PROGRESS_DIR/state-bv-singleuhp-archived.json" 2>/dev/null || true
    cp "$PROGRESS_DIR/state-${MAIN_NAME_PREFIX}.json" "$PROGRESS_DIR/state-${MAIN_NAME_PREFIX}-archived.json" 2>/dev/null || true

    vol_state="$PROGRESS_DIR/state-bv-singleuhp.json"
    if [ -f "$vol_state" ]; then
        export NAME_PREFIX="bv-singleuhp"
        export STATE_FILE="$vol_state"
        "$SCAFFOLD_DIR/do/teardown.sh" || true
    fi

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
