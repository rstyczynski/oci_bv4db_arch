#!/usr/bin/env bash
# run_oracle_db_sprint17.sh — Sprint 17 consolidated Oracle multi-volume UHP benchmark

set -euo pipefail
set -E

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCAFFOLD_DIR="$REPO_DIR/oci_scaffold"
PROGRESS_DIR="${PROGRESS_DIR:-$REPO_DIR/progress/sprint_17}"
SPRINT1_DIR="$REPO_DIR/progress/sprint_1"
INFRA_STATE="$SPRINT1_DIR/state-bv4db.json"
SPRINT_LABEL="${SPRINT_LABEL:-Sprint 17}"
SPRINT_NUMBER="${SPRINT_NUMBER:-17}"
PROFILE_FILE="${PROFILE_FILE:-$REPO_DIR/progress/sprint_10/oracle-layout-4k-redo.fio}"
SWINGBENCH_CONFIG_LOCAL="${SWINGBENCH_CONFIG_LOCAL:-$REPO_DIR/config/swingbench/SOE_Server_Side_V2.xml}"
METRICS_STATE_PREFIX="${METRICS_STATE_PREFIX:-metrics-sprint17}"
SUMMARY_BASENAME="${SUMMARY_BASENAME:-sprint_17_summary.md}"
OUTPUT_INDEX_BASENAME="${OUTPUT_INDEX_BASENAME:-sprint_17_outputs.md}"

export PATH="$SCAFFOLD_DIR/do:$SCAFFOLD_DIR/resource:$PATH"
export NAME_PREFIX="${NAME_PREFIX:-bv4db-oracle17-run}"
export OCI_REGION="${OCI_REGION:-}"
export OCI_CLI_REGION="${OCI_CLI_REGION:-${OCI_REGION:-}}"

COMPUTE_SHAPE="${COMPUTE_SHAPE:-VM.Standard.E5.Flex}"
COMPUTE_OCPUS="${COMPUTE_OCPUS:-40}"
COMPUTE_MEMORY_GB="${COMPUTE_MEMORY_GB:-64}"

SIZE_DATA_GB="${SIZE_DATA_GB:-200}"
SIZE_REDO_GB="${SIZE_REDO_GB:-50}"
SIZE_FRA_GB="${SIZE_FRA_GB:-100}"
VPU_DATA="${VPU_DATA:-120}"
VPU_REDO="${VPU_REDO:-20}"
VPU_FRA="${VPU_FRA:-10}"

ORACLE_PWD="${ORACLE_PWD:-BenchmarkPwd123}"
FIO_RUNTIME_SEC="${FIO_RUNTIME_SEC:-300}"
SWINGBENCH_WORKLOAD_DURATION="${SWINGBENCH_WORKLOAD_DURATION:-300}"
SWINGBENCH_USERS="${SWINGBENCH_USERS:-4}"
SWINGBENCH_SCALE="${SWINGBENCH_SCALE:-1}"
SWINGBENCH_BUILD_THREADS="${SWINGBENCH_BUILD_THREADS:-4}"
KEEP_INFRA="${KEEP_INFRA:-false}"
REUSE_EXISTING_INFRA="${REUSE_EXISTING_INFRA:-false}"
SKIP_FIO_PHASE="${SKIP_FIO_PHASE:-false}"
SKIP_DB_INSTALL="${SKIP_DB_INSTALL:-false}"

FIO_ARTIFACT_PREFIX="${FIO_ARTIFACT_PREFIX:-oracle17-fio-uhp-multi}"
SWINGBENCH_ARTIFACT_PREFIX="${SWINGBENCH_ARTIFACT_PREFIX:-oracle17-swingbench-uhp-multi}"

_on_err() {
    local ec=$? line=${BASH_LINENO[0]:-?} cmd=${BASH_COMMAND:-?}
    echo "  [FAIL] run_oracle_db_sprint17.sh failed (exit $ec) at line $line: $cmd" >&2
}
trap _on_err ERR

[ -f "$INFRA_STATE" ] || { echo "  [ERROR] Infra state not found: $INFRA_STATE" >&2; exit 1; }
[ -f "$PROFILE_FILE" ] || { echo "  [ERROR] fio profile not found: $PROFILE_FILE" >&2; exit 1; }
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

restore_reusable_state_file() {
    local target="$1"
    [ -f "$target" ] && return 0

    local base dir candidate
    dir=$(dirname "$target")
    base=$(basename "$target" .json)

    for candidate in \
        "$dir/${base}-archived.json" \
        $(ls -1t "$dir/${base}.deleted-"*.json 2>/dev/null) \
        $(ls -1t "$dir/${base}.pre-run-"*.json 2>/dev/null); do
        [ -n "${candidate:-}" ] || continue
        [ -f "$candidate" ] || continue
        cp "$candidate" "$target"
        echo "  [INFO] Restored reusable state file: $target <- $(basename "$candidate")"
        return 0
    done
    return 1
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
echo "  $SPRINT_LABEL: Consolidated Oracle UHP Benchmark"
echo "=========================================="
echo ""
echo "Configuration:"
echo "  Compute: $COMPUTE_SHAPE ($COMPUTE_OCPUS OCPUs, $COMPUTE_MEMORY_GB GB)"
echo "  Storage: multi_volume (2x DATA, 2x REDO, 1x FRA)"
echo "  FIO runtime: $FIO_RUNTIME_SEC seconds"
echo "  Swingbench runtime: $SWINGBENCH_WORKLOAD_DURATION seconds"
echo "  Swingbench users: $SWINGBENCH_USERS"
echo "  Keep infra: $KEEP_INFRA"
echo ""

declare -A VOLUMES
VOLUMES[data1]="/dev/oracleoci/oraclevdb:${VPU_DATA}:${SIZE_DATA_GB}"
VOLUMES[data2]="/dev/oracleoci/oraclevdc:${VPU_DATA}:${SIZE_DATA_GB}"
VOLUMES[redo1]="/dev/oracleoci/oraclevdd:${VPU_REDO}:${SIZE_REDO_GB}"
VOLUMES[redo2]="/dev/oracleoci/oraclevde:${VPU_REDO}:${SIZE_REDO_GB}"
VOLUMES[fra]="/dev/oracleoci/oraclevdf:${VPU_FRA}:${SIZE_FRA_GB}"

if [ "$REUSE_EXISTING_INFRA" = "true" ]; then
    if [ ! -f "$PROGRESS_DIR/state-${NAME_PREFIX}.json" ] || [ "$(jq -r '.compute.public_ip // empty' "$PROGRESS_DIR/state-${NAME_PREFIX}.json" 2>/dev/null)" = "" ]; then
        rm -f "$PROGRESS_DIR/state-${NAME_PREFIX}.json"
        restore_reusable_state_file "$PROGRESS_DIR/state-${NAME_PREFIX}.json" || true
    fi
    for vol_name in data1 data2 redo1 redo2 fra; do
        restore_reusable_state_file "$PROGRESS_DIR/state-bv-${vol_name}.json" || true
    done
else
    archive_stale_state_file "$PROGRESS_DIR/state-${NAME_PREFIX}.json"
    for vol_name in data1 data2 redo1 redo2 fra; do
        archive_stale_state_file "$PROGRESS_DIR/state-bv-${vol_name}.json"
    done
    archive_stale_state_file "$PROGRESS_DIR/state-${METRICS_STATE_PREFIX}-fio.json"
    archive_stale_state_file "$PROGRESS_DIR/state-${METRICS_STATE_PREFIX}-swingbench.json"
fi

enable_block_volume_plugin() {
    local instance_id="$1"
    oci compute instance update \
        --instance-id "$instance_id" \
        --agent-config '{"areAllPluginsDisabled":false,"isManagementDisabled":false,"isMonitoringDisabled":false,"pluginsConfig":[{"name":"Block Volume Management","desiredState":"ENABLED"}]}' \
        --force >/dev/null
}

ensure_compute_with_fallback() {
    local requested_ocpus="$COMPUTE_OCPUS"
    local requested_memory="$COMPUTE_MEMORY_GB"
    local -a profiles=(
        "${requested_ocpus}:${requested_memory}"
        "20:64"
        "16:64"
        "8:32"
    )
    local tried=""
    local profile ocpus memory rc output

    for profile in "${profiles[@]}"; do
        [ -n "$profile" ] || continue
        if [[ ",$tried," == *",$profile,"* ]]; then
            continue
        fi
        tried="${tried},${profile}"
        IFS=':' read -r ocpus memory <<< "$profile"
        export COMPUTE_OCPUS="$ocpus"
        export COMPUTE_MEMORY_GB="$memory"
        _state_set '.inputs.compute_ocpus' "$COMPUTE_OCPUS"
        _state_set '.inputs.compute_memory_gb' "$COMPUTE_MEMORY_GB"
        echo "  [INFO] Trying compute profile: $COMPUTE_SHAPE ($COMPUTE_OCPUS OCPUs, $COMPUTE_MEMORY_GB GB)"
        set +e
        output=$(ensure-compute.sh 2>&1)
        rc=$?
        set -e
        printf '%s\n' "$output"
        if [ "$rc" -eq 0 ]; then
            return 0
        fi
        if printf '%s\n' "$output" | grep -q 'Out of host capacity'; then
            echo "  [WARN] OCI capacity unavailable for $COMPUTE_OCPUS OCPUs / $COMPUTE_MEMORY_GB GB; trying next profile ..."
            continue
        fi
        return "$rc"
    done
    echo "  [ERROR] No compute profile succeeded after OCI capacity fallback attempts" >&2
    return 1
}

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
    _ssh "if [ -f '$path' ]; then tail -n 60 '$path'; fi" 2>/dev/null || true
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

    _ssh "sudo rm -f '$remote_pid' '$remote_status' '$remote_log'; chmod 755 '$remote_script'"

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

write_metrics_definition() {
    local output_file="$1"
    local title="$2"
    cat >"$output_file" <<EOF
{
  "title": "$title",
  "resource_classes": {
    "compute": {
      "namespace": "oci_computeagent",
      "resource_source": "compute_ocid",
      "compartment_source": "inputs_compartment",
      "interval": "1m",
      "metrics": [
        { "name": "CpuUtilization", "stat": "mean", "unit": "percent", "scale": 1, "suffix": "%", "decimals": 2 },
        { "name": "MemoryUtilization", "stat": "mean", "unit": "percent", "scale": 1, "suffix": "%", "decimals": 2 },
        { "name": "DiskBytesRead", "stat": "rate", "unit": "bytes/s", "scale": 1048576, "suffix": " MiB/s", "decimals": 2 },
        { "name": "DiskBytesWritten", "stat": "rate", "unit": "bytes/s", "scale": 1048576, "suffix": " MiB/s", "decimals": 2 }
      ]
    },
    "blockvolume": {
      "namespace": "oci_blockstore",
      "resource_source": "volume_ocids",
      "compartment_source": "inputs_compartment",
      "interval": "1m",
      "metrics": [
        { "name": "VolumeReadThroughput", "stat": "mean", "unit": "bytes/interval", "scale": 1048576, "suffix": " MiB", "decimals": 2 },
        { "name": "VolumeWriteThroughput", "stat": "mean", "unit": "bytes/interval", "scale": 1048576, "suffix": " MiB", "decimals": 2 },
        { "name": "VolumeReadOps", "stat": "mean", "unit": "ops", "scale": 1, "suffix": "", "decimals": 2 },
        { "name": "VolumeWriteOps", "stat": "mean", "unit": "ops", "scale": 1, "suffix": "", "decimals": 2 }
      ]
    },
    "network": {
      "namespace": "oci_vcn",
      "resource_source": "primary_vnic",
      "compartment_source": "subnet_compartment",
      "interval": "1m",
      "metrics": [
        { "name": "VnicFromNetworkBytes", "stat": "mean", "unit": "bytes/interval", "scale": 1048576, "suffix": " MiB", "decimals": 2 },
        { "name": "VnicToNetworkBytes", "stat": "mean", "unit": "bytes/interval", "scale": 1048576, "suffix": " MiB", "decimals": 2 },
        { "name": "VnicEgressDropsSecurityList", "stat": "mean", "unit": "packets", "scale": 1, "suffix": "", "decimals": 2 },
        { "name": "VnicIngressDropsSecurityList", "stat": "mean", "unit": "packets", "scale": 1, "suffix": "", "decimals": 2 }
      ]
    }
  }
}
EOF
}

ensure_boot_volume_state() {
    local boot_ocid compute_ocid compartment_ocid availability_domain
    boot_ocid=$(_state_get '.boot_volume.ocid')
    if [ -n "${boot_ocid:-}" ] && [ "$boot_ocid" != "null" ]; then
        return 0
    fi

    compute_ocid=$(_state_get '.compute.ocid')
    compartment_ocid=$(_state_get '.inputs.oci_compartment')
    [ -n "${compute_ocid:-}" ] && [ "$compute_ocid" != "null" ] || return 0
    [ -n "${compartment_ocid:-}" ] && [ "$compartment_ocid" != "null" ] || return 0

    availability_domain=$(oci compute instance get \
        --instance-id "$compute_ocid" \
        --query 'data."availability-domain"' --raw-output 2>/dev/null || true)
    [ -n "${availability_domain:-}" ] || return 0

    boot_ocid=$(oci compute boot-volume-attachment list \
        --availability-domain "$availability_domain" \
        --compartment-id "$compartment_ocid" \
        --instance-id "$compute_ocid" \
        --query 'data[0]."boot-volume-id"' --raw-output 2>/dev/null || true)
    if [ -n "${boot_ocid:-}" ] && [ "$boot_ocid" != "null" ]; then
        _state_set '.boot_volume.ocid' "$boot_ocid"
    fi
}

run_metrics_phase() {
    local phase="$1"
    local title="$2"
    local start_time="$3"
    local end_time="$4"

    local metrics_prefix="${METRICS_STATE_PREFIX}-${phase}"
    local metrics_state="$PROGRESS_DIR/state-${metrics_prefix}.json"
    local metrics_def="$PROGRESS_DIR/${phase}_metrics_definition.json"
    local report_md="$PROGRESS_DIR/${phase}_oci_metrics_report.md"
    local report_html="$PROGRESS_DIR/${phase}_oci_metrics_report.html"
    local raw_file="$PROGRESS_DIR/${phase}_oci_metrics_raw.json"

    ensure_boot_volume_state
    write_metrics_definition "$metrics_def" "$title"
    jq \
      --arg start "$start_time" \
      --arg end "$end_time" \
      --arg def "$metrics_def" \
      --arg report_md "$report_md" \
      --arg report_html "$report_html" \
      --arg raw "$raw_file" \
      '
      .test_window = {start_time:$start, end_time:$end}
      | .inputs = ((.inputs // {}) + {
          metrics_definition_file:$def,
          metrics_report_file:$report_md,
          metrics_html_report_file:$report_html,
          metrics_raw_file:$raw,
          metrics_resolution:"1m"
        })
      ' "$PROGRESS_DIR/state-${MAIN_NAME_PREFIX}.json" > "$metrics_state"

    (
        cd "$PROGRESS_DIR"
        NAME_PREFIX="$metrics_prefix" "$REPO_DIR/oci_scaffold/resource/operate-metrics.sh"
    )
}

collect_oci_agent_multipath_diagnostics() {
    local remote_file="/tmp/oci_agent_multipath_diagnostics.txt"
    local local_file="$PROGRESS_DIR/oci_agent_multipath_diagnostics.txt"
    local plugin_log="/var/log/oracle-cloud-agent/plugins/oci-blockautoconfig/oci-blockautoconfig.log"
    local plugin_log_copy="/tmp/oci-blockautoconfig.log"
    local plugin_log_local="$PROGRESS_DIR/oci-blockautoconfig.log"
    local plugin_tail_local="$PROGRESS_DIR/oci-blockautoconfig-tail.log"

    _ssh "sudo bash -lc '
set -e
{
  echo \"# OCI Agent Multipath Diagnostics\"
  echo
  echo \"Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)\"
  echo
  echo \"## File ownership\"
  ls -ld /etc /etc/multipath.conf 2>&1 || true
  echo
  echo \"## File stat\"
  stat /etc/multipath.conf 2>&1 || true
  echo
  echo \"## SELinux context\"
  ls -lZ /etc/multipath.conf 2>&1 || true
  echo
  echo \"## ACL\"
  getfacl /etc/multipath.conf 2>&1 || true
  echo
  echo \"## Multipath service\"
  systemctl status multipathd --no-pager -l 2>&1 || true
  echo
  echo \"## Multipath overview\"
  multipath -ll 2>&1 || true
  echo
  echo \"## Process ownership\"
  ps -ef | egrep \"oracle-cloud-agent|ocid|multipathd|iscsid\" | grep -v egrep 2>&1 || true
  echo
  echo \"## Oracle Cloud Agent service\"
  systemctl status oracle-cloud-agent --no-pager -l 2>&1 || true
} > \"$remote_file\"
chmod a+r \"$remote_file\"

if [ -f \"$plugin_log\" ]; then
  cp \"$plugin_log\" \"$plugin_log_copy\"
  chmod a+r \"$plugin_log_copy\"
  tail -n 200 \"$plugin_log\" > /tmp/oci-blockautoconfig-tail.log
  chmod a+r /tmp/oci-blockautoconfig-tail.log
fi
'"
    _scp_from_remote "$remote_file" "$local_file"
    _scp_from_remote "$plugin_log_copy" "$plugin_log_local" 2>/dev/null || true
    _scp_from_remote "/tmp/oci-blockautoconfig-tail.log" "$plugin_tail_local" 2>/dev/null || true
}

run_remote_fio_phase() {
    local runtime_sec="$1"
    local remote_profile="/tmp/oracle17-layout.fio"
    local remote_json="/tmp/fio-${FIO_ARTIFACT_PREFIX}.json"
    local remote_iostat="/tmp/iostat-${FIO_ARTIFACT_PREFIX}.json"
    local remote_log="/tmp/fio-${FIO_ARTIFACT_PREFIX}.log"
    local local_json="$PROGRESS_DIR/fio_results.json"
    local local_iostat="$PROGRESS_DIR/fio_iostat.json"
    local local_log="$PROGRESS_DIR/fio_phase.log"
    local iostat_samples=$((((runtime_sec + 30) / 10) + 3))
    local ramp_time_sec
    local max_wait_sec
    local tmp_profile

    tmp_profile=$(mktemp)
    awk -v runtime="$runtime_sec" '
        /^runtime=/ { print "runtime=" runtime; next }
        { print }
    ' "$PROFILE_FILE" > "$tmp_profile"
    ramp_time_sec=$(awk -F= '/^ramp_time=/ { gsub(/[[:space:]]/, "", $2); print $2; exit }' "$tmp_profile")
    [ -n "${ramp_time_sec:-}" ] || ramp_time_sec=0
    max_wait_sec=$((runtime_sec + ramp_time_sec + 900))

    _scp_to_remote "$tmp_profile" "$remote_profile"
    rm -f "$tmp_profile"
    _ssh "sudo chown opc:opc '$remote_profile'"

    _run_remote_step \
        "FIO phase" \
        root \
        "$max_wait_sec" \
        "$remote_log" \
        "iostat -xdmz 10 '$iostat_samples' -o JSON > '$remote_iostat' 2>&1 & \
IOSTAT_PID=\$!; \
fio --runtime='$runtime_sec' --output='$remote_json' --output-format=json '$remote_profile'; \
rc=\$?; \
wait \$IOSTAT_PID 2>/dev/null || true; \
rm -f /u02/oradata/testfile /u03/redo/testfile /u04/fra/testfile >/dev/null 2>&1 || true; \
exit \$rc"

    _ssh "sudo chmod a+r '$remote_json' '$remote_iostat' '$remote_log' 2>/dev/null || true"
    _scp_from_remote "$remote_json" "$local_json"
    _scp_from_remote "$remote_iostat" "$local_iostat"
    _scp_from_remote "$remote_log" "$local_log"
    _ssh "sudo rm -f '$remote_profile' '$remote_json' '$remote_iostat' '$remote_log'"

    echo "$local_json"
}

write_fio_analysis_md() {
    local fio_json="$1"
    local iostat_json="$2"
    local output_md="$3"
    python3 - "$fio_json" "$iostat_json" "$output_md" "$SPRINT_LABEL" <<'PY'
import json
import sys

fio_json, iostat_json, output_md, sprint_label = sys.argv[1:5]
with open(fio_json, "r", encoding="utf-8") as handle:
    fio = json.load(handle)
with open(iostat_json, "r", encoding="utf-8") as handle:
    iostat = json.load(handle)

jobs = fio.get("jobs", [])
stats = (((iostat.get("sysstat") or {}).get("hosts") or [{}])[0].get("statistics") or [])
devices = {}
for snap in stats:
    for disk in snap.get("disk", []):
        name = disk.get("disk_device", "unknown")
        devices.setdefault(name, []).append({
            "read": float(disk.get("rMB/s", 0.0)),
            "write": float(disk.get("wMB/s", 0.0)),
            "util": float(disk.get("util", 0.0)),
        })

lines = []
lines.append(f"# {sprint_label} FIO Phase Analysis")
lines.append("")
lines.append("## fio Jobs")
lines.append("")
for job in jobs:
    read = job.get("read", {})
    write = job.get("write", {})
    lines.append(f"### {job.get('jobname', 'unknown')}")
    lines.append(f"- Read IOPS: `{round(read.get('iops', 0), 2)}`")
    lines.append(f"- Read MiB/s: `{round(read.get('bw', 0) / 1024, 2)}`")
    lines.append(f"- Write IOPS: `{round(write.get('iops', 0), 2)}`")
    lines.append(f"- Write MiB/s: `{round(write.get('bw', 0) / 1024, 2)}`")
    lines.append("")

lines.append("## Guest iostat")
lines.append("")
ranked = []
for name, samples in devices.items():
    if not samples:
        continue
    avg_read = sum(s["read"] for s in samples) / len(samples)
    avg_write = sum(s["write"] for s in samples) / len(samples)
    avg_util = sum(s["util"] for s in samples) / len(samples)
    ranked.append((avg_util, avg_read, avg_write, name))

for avg_util, avg_read, avg_write, name in sorted(ranked, reverse=True)[:15]:
    lines.append(f"- `{name}` avg read `{avg_read:.2f} MiB/s`, avg write `{avg_write:.2f} MiB/s`, avg util `{avg_util:.2f}%`")

lines.append("")
lines.append("## Interpretation")
lines.append("")
lines.append("- This phase validates the Oracle-style fio profile on the multi-volume benchmark topology.")
lines.append("- Guest iostat shows which devices absorbed the fio load during the benchmark window.")
lines.append("- OCI metrics for the same window are archived separately and can be compared with this guest-side evidence.")

with open(output_md, "w", encoding="utf-8") as handle:
    handle.write("\n".join(lines) + "\n")
PY
}

write_sprint17_summary() {
    local output_md="$1"
    local fio_start="$2"
    local fio_end="$3"
    local swing_start="$4"
    local swing_end="$5"
    local begin_snap="$6"
    local end_snap="$7"

    python3 - "$PROGRESS_DIR/fio_results.json" "$PROGRESS_DIR/swingbench_results.xml" "$output_md" "$fio_start" "$fio_end" "$swing_start" "$swing_end" "$begin_snap" "$end_snap" "$SPRINT_LABEL" "$SPRINT_NUMBER" <<'PY'
import json
import sys
import xml.etree.ElementTree as ET

fio_json, swingbench_xml, output_md, fio_start, fio_end, swing_start, swing_end, begin_snap, end_snap, sprint_label, sprint_number = sys.argv[1:12]

with open(fio_json, "r", encoding="utf-8") as handle:
    fio = json.load(handle)
jobs = fio.get("jobs", [])

ns = {"sb": "http://www.dominicgiles.com/swingbench/results"}
root = ET.parse(swingbench_xml).getroot()
def text(tag, default="n/a"):
    node = root.find(f".//sb:{tag}", ns)
    return node.text if node is not None and node.text is not None else default

lines = []
lines.append(f"# {sprint_label} Summary")
lines.append("")
lines.append("## Scope")
lines.append("")
lines.append("- Multi-volume Oracle-style benchmark topology on a UHP-sized compute profile")
lines.append("- Phase 1: Oracle-style `fio` with guest `iostat` and OCI metrics")
lines.append("- Phase 2: Oracle Database Free `Swingbench` with guest `iostat`, OCI metrics, and AWR")
lines.append("")
lines.append("## Phase Windows")
lines.append("")
lines.append(f"- FIO phase: `{fio_start}` -> `{fio_end}`")
lines.append(f"- Swingbench phase: `{swing_start}` -> `{swing_end}`")
lines.append(f"- AWR snapshots: `{begin_snap}` -> `{end_snap}`")
lines.append("")
lines.append("## FIO Highlights")
lines.append("")
for job in jobs:
    read = job.get("read", {})
    write = job.get("write", {})
    lines.append(f"- `{job.get('jobname', 'unknown')}`: read `{round(read.get('bw', 0) / 1024, 2)} MiB/s`, write `{round(write.get('bw', 0) / 1024, 2)} MiB/s`")
lines.append("")
lines.append("## Swingbench Highlights")
lines.append("")
lines.append(f"- Benchmark: `{text('BenchmarkName')}`")
lines.append(f"- Run time: `{text('TotalRunTime')}`")
lines.append(f"- Completed transactions: `{text('TotalCompletedTransactions')}`")
lines.append(f"- Failed transactions: `{text('TotalFailedTransactions')}`")
lines.append(f"- Average TPS: `{text('AverageTransactionsPerSecond')}`")
lines.append("")
lines.append("## HTML Reports")
lines.append("")
lines.append("- `fio_report.html`")
lines.append("- `fio_oci_metrics_report.html`")
lines.append("- `swingbench_report.html`")
lines.append("- `swingbench_oci_metrics_report.html`")
lines.append("- `awr_report.html`")
lines.append("")
lines.append("## Consolidated Conclusion")
lines.append("")
lines.append(f"- {sprint_label} combines storage-only stress and database-level stress on one repeatable Oracle-style topology.")
lines.append("- The result set now aligns benchmark output, guest iostat, OCI metrics, and AWR into one end-to-end benchmark package.")

with open(output_md, "w", encoding="utf-8") as handle:
    handle.write("\n".join(lines) + "\n")
PY
}

vol_names=(data1 data2 redo1 redo2 fra)

[ -n "$OCI_REGION" ] && _state_set '.inputs.oci_region' "$OCI_REGION"
_state_set '.inputs.name_prefix' "$NAME_PREFIX"
_state_set '.inputs.oci_compartment' "$COMPARTMENT_OCID"
_state_set '.subnet.ocid' "$SUBNET_OCID"
_state_set '.inputs.compute_shape' "$COMPUTE_SHAPE"
_state_set '.inputs.compute_ocpus' "$COMPUTE_OCPUS"
_state_set '.inputs.compute_memory_gb' "$COMPUTE_MEMORY_GB"
_state_set '.inputs.subnet_prohibit_public_ip' 'false'
_state_set '.inputs.compute_ssh_authorized_keys_file' "$PUBKEY_FILE"
_state_set '.inputs.storage_layout_mode' 'multi_volume'
_state_set '.inputs.fio_runtime_sec' "$FIO_RUNTIME_SEC"
_state_set '.inputs.swingbench_workload_duration' "$SWINGBENCH_WORKLOAD_DURATION"
_state_set '.load_generator.name' 'swingbench'

if [ "$REUSE_EXISTING_INFRA" = "true" ]; then
    PUBLIC_IP=$(_state_get '.compute.public_ip')
    INSTANCE_OCID=$(_state_get '.compute.ocid')
    [ -n "${PUBLIC_IP:-}" ] && [ "$PUBLIC_IP" != "null" ] || { echo "  [ERROR] Reuse requested but no compute public IP found in state" >&2; exit 1; }
    [ -n "${INSTANCE_OCID:-}" ] && [ "$INSTANCE_OCID" != "null" ] || { echo "  [ERROR] Reuse requested but no compute OCID found in state" >&2; exit 1; }
    echo "  [INFO] Reusing existing compute instance: $PUBLIC_IP"
else
    echo "  [INFO] Provisioning compute instance ..."
    ensure_compute_with_fallback
    enable_block_volume_plugin "$(_state_get '.compute.ocid')"
    PUBLIC_IP=$(_state_get '.compute.public_ip')
    INSTANCE_OCID=$(_state_get '.compute.ocid')
    COMPUTE_VNIC_OCID=$(oci compute instance list-vnics --instance-id "$INSTANCE_OCID" --compartment-id "$COMPARTMENT_OCID" 2>/dev/null | jq -r '.data[0]."vnic-id" // .data[0].id // empty') || true
    [ -n "${COMPUTE_VNIC_OCID:-}" ] && [ "$COMPUTE_VNIC_OCID" != "null" ] && _state_set '.compute.vnic_ocid' "$COMPUTE_VNIC_OCID"
    echo "  [INFO] Compute instance ready: $PUBLIC_IP"
fi

TMPKEY=$(mktemp)
chmod 600 "$TMPKEY"
oci secrets secret-bundle get \
    --secret-id "$SECRET_OCID" \
    --query 'data."secret-bundle-content".content' --raw-output \
    | base64 --decode > "$TMPKEY"

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

declare -A ATTACH_OCIDS
declare -A MPATH_DEVICES
MAIN_NAME_PREFIX="$NAME_PREFIX"

if [ "$REUSE_EXISTING_INFRA" = "true" ]; then
    for vol_name in "${vol_names[@]}"; do
        IFS=':' read -r dev_path _ <<< "${VOLUMES[$vol_name]}"
        ATTACH_OCIDS[$vol_name]=$(_state_get ".volumes.${vol_name}.attachment_ocid")
        MPATH_DEVICES[$vol_name]=$(resolve_mpath_device "$dev_path")
        echo "  [INFO] Reusing $vol_name mpath device: ${MPATH_DEVICES[$vol_name]}"
    done
else
    for vol_name in "${vol_names[@]}"; do
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
        VOL_VPUS=$(_state_get '.blockvolume.vpus_per_gb')

        echo "  [INFO] Preparing iSCSI for $vol_name ..."
        prepare_guest_block_device "${ATTACH_OCIDS[$vol_name]}" "$dev_path"
        wait_for_stable_ssh "iSCSI guest preparation for $vol_name" 180
        MPATH_DEVICES[$vol_name]=$(resolve_mpath_device "$dev_path")
        echo "  [INFO] $vol_name mpath device: ${MPATH_DEVICES[$vol_name]}"

        export NAME_PREFIX="$MAIN_NAME_PREFIX"
        export STATE_FILE="$PROGRESS_DIR/state-${NAME_PREFIX}.json"
        _state_set ".volumes.${vol_name}.ocid" "$VOL_OCID"
        _state_set ".volumes.${vol_name}.attachment_ocid" "${ATTACH_OCIDS[$vol_name]}"
        _state_set ".volumes.${vol_name}.device_path" "$dev_path"
        [ -n "${VOL_VPUS:-}" ] && [ "$VOL_VPUS" != "null" ] && _state_set ".volumes.${vol_name}.vpus_per_gb" "$VOL_VPUS"
    done
fi

export NAME_PREFIX="$MAIN_NAME_PREFIX"
export STATE_FILE="$PROGRESS_DIR/state-${NAME_PREFIX}.json"

echo "  [INFO] Configuring Oracle-style multi-volume storage layout ..."
_scp_to_remote "$REPO_DIR/tools/configure_oracle_db_layout.sh" "/tmp/configure_oracle_db_layout.sh"
_ssh "chmod +x /tmp/configure_oracle_db_layout.sh"
_run_remote_step \
    "Oracle storage layout" \
    root \
    900 \
    /tmp/oracle-storage-layout.log \
    "STORAGE_LAYOUT_MODE=multi_volume \
DATA1_DEV='${MPATH_DEVICES[data1]}' \
DATA2_DEV='${MPATH_DEVICES[data2]}' \
REDO1_DEV='${MPATH_DEVICES[redo1]}' \
REDO2_DEV='${MPATH_DEVICES[redo2]}' \
FRA_DEV='${MPATH_DEVICES[fra]}' \
LOG_FILE=/tmp/oracle-storage-layout.log \
/tmp/configure_oracle_db_layout.sh"
_scp_from_remote "/tmp/oracle-storage-layout.log" "$PROGRESS_DIR/storage-layout.log" 2>/dev/null || true

echo "  [INFO] Capturing OCI agent and multipath diagnostics ..."
collect_oci_agent_multipath_diagnostics

echo "  [INFO] Installing fio, sysstat, and jq ..."
_ssh "sudo dnf install -y fio sysstat jq >/dev/null"

if [ "$SKIP_FIO_PHASE" = "true" ]; then
    FIO_START=$(_state_get '.fio_phase.start_time')
    FIO_END=$(_state_get '.fio_phase.end_time')
    [ -f "$PROGRESS_DIR/fio_results.json" ] || { echo "  [ERROR] SKIP_FIO_PHASE=true but fio_results.json is missing" >&2; exit 1; }
    [ -f "$PROGRESS_DIR/fio_iostat.json" ] || { echo "  [ERROR] SKIP_FIO_PHASE=true but fio_iostat.json is missing" >&2; exit 1; }
    echo "  [INFO] Reusing existing FIO artifacts and skipping FIO phase"
else
    FIO_START=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    _state_set '.fio_phase.start_time' "$FIO_START"
    echo "  [INFO] Running FIO phase ($FIO_RUNTIME_SEC seconds) ..."
    run_remote_fio_phase "$FIO_RUNTIME_SEC"
    FIO_END=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    _state_set '.fio_phase.end_time' "$FIO_END"
    write_fio_analysis_md "$PROGRESS_DIR/fio_results.json" "$PROGRESS_DIR/fio_iostat.json" "$PROGRESS_DIR/fio_analysis.md"
    "$REPO_DIR/tools/render_fio_report_html.sh" \
        "$PROGRESS_DIR/fio_results.json" \
        "$PROGRESS_DIR/fio_iostat.json" \
        "$PROGRESS_DIR/fio_report.html" \
        "$SPRINT_LABEL FIO Dashboard"
    echo "  [INFO] Collecting OCI metrics for FIO phase ..."
    run_metrics_phase "fio" "$SPRINT_LABEL FIO OCI Metrics" "$FIO_START" "$FIO_END"
fi

if [ "$SKIP_DB_INSTALL" = "true" ]; then
    echo "  [INFO] Skipping Oracle Database install and reusing the existing database instance"
else
    echo "  [INFO] Installing Oracle Database Free 23ai ..."
    _scp_to_remote "$REPO_DIR/tools/install_oracle_db_free.sh" "/tmp/install_oracle_db_free.sh"
    _ssh "chmod +x /tmp/install_oracle_db_free.sh"
    _run_remote_step \
        "Oracle Database install" \
        root \
        2400 \
        /tmp/oracle-db-free-install.log \
        "ORACLE_PWD='$ORACLE_PWD' FORCE_DB_RECREATE_ON_MISPLACEMENT=true LOG_FILE=/tmp/oracle-db-free-install.log /tmp/install_oracle_db_free.sh"
    _scp_from_remote "/tmp/oracle-db-free-install.log" "$PROGRESS_DIR/db-install.log" 2>/dev/null || true
fi

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

SWINGBENCH_START=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
_state_set '.benchmark.start_time' "$SWINGBENCH_START"

echo "  [INFO] Capturing AWR begin snapshot ..."
BEGIN_SNAP_ID=$(_ssh "sudo su - oracle -c '/tmp/capture_awr_snapshot.sh begin /tmp/awr_begin_snap_id.txt'" | tail -1)
echo "  [INFO] Begin snapshot ID: $BEGIN_SNAP_ID"
_state_set '.awr.begin_snap_id' "$BEGIN_SNAP_ID"

echo "  [INFO] Running Swingbench phase ($SWINGBENCH_WORKLOAD_DURATION seconds) ..."
SWINGBENCH_IOSTAT_SAMPLES=$((((SWINGBENCH_WORKLOAD_DURATION + 30) / 10) + 3))
_run_remote_step \
    "Swingbench phase" \
    root \
    "$((SWINGBENCH_WORKLOAD_DURATION + 1800))" \
    /tmp/swingbench-phase.log \
    "mkdir -p /tmp/swingbench; \
chown oracle:oinstall /tmp/swingbench; \
iostat -xdmz 10 '$SWINGBENCH_IOSTAT_SAMPLES' -o JSON > /tmp/swingbench/iostat.json 2>&1 & \
IOSTAT_PID=\$!; \
sudo su - oracle -c 'ORACLE_PWD=$ORACLE_PWD \
WORKLOAD_DURATION=$SWINGBENCH_WORKLOAD_DURATION \
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
/tmp/run_oracle_swingbench.sh $SWINGBENCH_WORKLOAD_DURATION'; \
rc=\$?; \
wait \$IOSTAT_PID 2>/dev/null || true; \
chmod -R a+rX /tmp/swingbench 2>/dev/null || true; \
exit \$rc"

echo "  [INFO] Capturing AWR end snapshot ..."
END_SNAP_ID=$(_ssh "sudo su - oracle -c '/tmp/capture_awr_snapshot.sh end /tmp/awr_end_snap_id.txt'" | tail -1)
echo "  [INFO] End snapshot ID: $END_SNAP_ID"
_state_set '.awr.end_snap_id' "$END_SNAP_ID"

SWINGBENCH_END=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
_state_set '.benchmark.end_time' "$SWINGBENCH_END"

echo "  [INFO] Generating AWR report ..."
_run_remote_step \
    "AWR report export" \
    oracle \
    900 \
    /tmp/awr_export.log \
    "/tmp/export_awr_report.sh $BEGIN_SNAP_ID $END_SNAP_ID /tmp/awr_report.html"

_ssh "sudo chmod a+r /tmp/awr_begin_snap_id.txt /tmp/awr_end_snap_id.txt /tmp/awr_report.html /tmp/swingbench-phase.log 2>/dev/null || true; \
      sudo chmod -R a+rX /tmp/swingbench 2>/dev/null || true"

echo "  [INFO] Collecting Swingbench artifacts ..."
_scp_from_remote "/tmp/awr_begin_snap_id.txt" "$PROGRESS_DIR/awr_begin_snap_id.txt"
_scp_from_remote "/tmp/awr_end_snap_id.txt" "$PROGRESS_DIR/awr_end_snap_id.txt"
_scp_from_remote "/tmp/awr_report.html" "$PROGRESS_DIR/awr_report.html"
_scp_from_remote "/tmp/swingbench/charbench.log" "$PROGRESS_DIR/swingbench_charbench.log"
_scp_from_remote "/tmp/swingbench/results.xml" "$PROGRESS_DIR/swingbench_results.xml"
_scp_from_remote "/tmp/swingbench/results.txt" "$PROGRESS_DIR/swingbench_results.txt" 2>/dev/null || true
_scp_from_remote "/tmp/swingbench/results_db.json" "$PROGRESS_DIR/swingbench_results_db.json" 2>/dev/null || true
_scp_from_remote "/tmp/swingbench/iostat.json" "$PROGRESS_DIR/swingbench_iostat.json"
_scp_from_remote "/tmp/swingbench-phase.log" "$PROGRESS_DIR/swingbench_phase.log"
cp "$SWINGBENCH_CONFIG_LOCAL" "$PROGRESS_DIR/swingbench_config.xml"

echo "  [INFO] Rendering Swingbench HTML report ..."
"$REPO_DIR/tools/render_swingbench_report_html.sh" \
    "$PROGRESS_DIR/swingbench_results.xml" \
    "$PROGRESS_DIR/swingbench_charbench.log" \
    "$PROGRESS_DIR/swingbench_results_db.json" \
    "$PROGRESS_DIR/swingbench_report.html"

echo "  [INFO] Collecting OCI metrics for Swingbench phase ..."
run_metrics_phase "swingbench" "$SPRINT_LABEL Swingbench OCI Metrics" "$SWINGBENCH_START" "$SWINGBENCH_END"

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
_state_set '.sprint' "$SPRINT_NUMBER"

write_sprint17_summary \
    "$PROGRESS_DIR/$SUMMARY_BASENAME" \
    "$FIO_START" "$FIO_END" \
    "$SWINGBENCH_START" "$SWINGBENCH_END" \
    "$BEGIN_SNAP_ID" "$END_SNAP_ID"

cat > "$PROGRESS_DIR/$OUTPUT_INDEX_BASENAME" <<EOF
# $SPRINT_LABEL Output Index

## FIO Phase

- \`fio_results.json\`
- \`fio_iostat.json\`
- \`fio_analysis.md\`
- \`fio_report.html\`
- \`fio_oci_metrics_report.md\`
- \`fio_oci_metrics_report.html\`

## Swingbench Phase

- \`swingbench_results.xml\`
- \`swingbench_results_db.json\`
- \`swingbench_iostat.json\`
- \`swingbench_report.html\`
- \`swingbench_oci_metrics_report.md\`
- \`swingbench_oci_metrics_report.html\`
- \`awr_report.html\`
- \`oci_agent_multipath_diagnostics.txt\`
- \`oci-blockautoconfig.log\`
- \`oci-blockautoconfig-tail.log\`

## Summary

- \`$SUMMARY_BASENAME\`
- \`db-status.log\`
EOF

rm -f "$TMPKEY"

if [ "$KEEP_INFRA" = "true" ]; then
    echo ""
    echo "  [INFO] Infrastructure kept running (KEEP_INFRA=true)"
    echo "  [INFO] SSH: ssh -i <key> opc@$PUBLIC_IP"
else
    echo ""
    echo "  [INFO] Tearing down compute and block volumes ..."

    for vol_name in "${vol_names[@]}"; do
        cp "$PROGRESS_DIR/state-bv-${vol_name}.json" "$PROGRESS_DIR/state-bv-${vol_name}-archived.json" 2>/dev/null || true
    done
    cp "$PROGRESS_DIR/state-${MAIN_NAME_PREFIX}.json" "$PROGRESS_DIR/state-${MAIN_NAME_PREFIX}-archived.json" 2>/dev/null || true

    for vol_name in "${vol_names[@]}"; do
        vol_state="$PROGRESS_DIR/state-bv-${vol_name}.json"
        if [ -f "$vol_state" ]; then
            export NAME_PREFIX="bv-${vol_name}"
            export STATE_FILE="$vol_state"
            "$SCAFFOLD_DIR/do/teardown.sh" || true
        fi
    done

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
