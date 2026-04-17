#!/usr/bin/env bash
# run_bv_fio_perf.sh — provision Sprint 2 maximum-performance compute + UHP block volume,
# run the Sprint 2 fio benchmark window, save raw results + analysis, then tear down.

set -euo pipefail
set -E

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCAFFOLD_DIR="$REPO_DIR/oci_scaffold"
PROGRESS_DIR="$REPO_DIR/progress/sprint_2"
SPRINT1_DIR="$REPO_DIR/progress/sprint_1"
INFRA_STATE="$SPRINT1_DIR/state-bv4db.json"

export PATH="$SCAFFOLD_DIR/do:$SCAFFOLD_DIR/resource:$PATH"
export NAME_PREFIX="bv4db-perf-run"
export OCI_REGION="${OCI_REGION:-}"
export OCI_CLI_REGION="${OCI_CLI_REGION:-${OCI_REGION:-}}"
FIO_TOTAL_RUNTIME_SEC="${FIO_TOTAL_RUNTIME_SEC:-60}"
SEQ_RUNTIME_SEC="${SEQ_RUNTIME_SEC:-$((FIO_TOTAL_RUNTIME_SEC / 2))}"
RAND_RUNTIME_SEC="${RAND_RUNTIME_SEC:-$((FIO_TOTAL_RUNTIME_SEC - SEQ_RUNTIME_SEC))}"

_on_err() {
  local ec=$? line=${BASH_LINENO[0]:-?} cmd=${BASH_COMMAND:-?}
  echo "  [FAIL] run_bv_fio_perf.sh failed (exit $ec) at line $line: $cmd" >&2
}
trap _on_err ERR

[ -f "$INFRA_STATE" ] || { echo "  [ERROR] Infra state not found: $INFRA_STATE — Sprint 1 shared infra is required" >&2; exit 1; }

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

enable_block_volume_plugin() {
  local instance_id="$1"

  echo "  [INFO] Enabling OCI Block Volume Management plugin on instance ..."
  oci compute instance update \
    --instance-id "$instance_id" \
    --agent-config '{"areAllPluginsDisabled":false,"isManagementDisabled":false,"isMonitoringDisabled":false,"pluginsConfig":[{"name":"Block Volume Management","desiredState":"ENABLED"}]}' \
    --force >/dev/null

  local desired_state
  desired_state=$(oci compute instance get \
    --instance-id "$instance_id" \
    | jq -r '.data."agent-config"."plugins-config"[]? | select(.name == "Block Volume Management") | ."desired-state"' \
    | head -n 1)

  if [ "$desired_state" != "ENABLED" ]; then
    echo "  [ERROR] OCI Block Volume Management plugin is not enabled for instance $instance_id" >&2
    exit 1
  fi
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

  [ "${#target_ips[@]}" -gt 0 ] || {
    echo "  [ERROR] No iSCSI target IPs found for attachment $attach_id" >&2
    exit 1
  }

  echo "  [INFO] Configuring guest iSCSI sessions and multipath (${#target_ips[@]} paths) ..."
  _ssh_script sudo bash -s -- "$iqn" "$port" "$expected_path" "${target_ips[@]}" <<'EOF'
set -euo pipefail

IQN="$1"
PORT="$2"
DEVICE_PATH="$3"
shift 3
TARGETS=("$@")

systemctl enable --now iscsid >/dev/null
mpathconf --enable --with_multipathd y >/dev/null
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

echo "Expected device path not present after iSCSI login: $DEVICE_PATH" >&2
iscsiadm -m session || true
multipath -ll || true
ls -l /dev/oracleoci || true
exit 1
EOF
}

resolve_benchmark_device() {
  local expected_path="$1"

  _ssh_script sudo bash -s -- "$expected_path" <<'EOF'
set -euo pipefail

EXPECTED_PATH="$1"
RESOLVED_PATH=$(readlink -f "$EXPECTED_PATH" 2>/dev/null || echo "$EXPECTED_PATH")
MAPPER_PATH=$(lsblk -nrpo NAME,TYPE "$RESOLVED_PATH" | awk '$2 == "mpath" { print $1; exit }')

if [ -n "${MAPPER_PATH:-}" ]; then
  echo "$MAPPER_PATH"
else
  echo "$EXPECTED_PATH"
fi
EOF
}

run_remote_fio() {
  local job_name="$1"
  local runtime_sec="$2"
  local rw_mode="$3"
  local block_size="$4"
  local numjobs="$5"
  local iodepth="$6"
  local remote_json="$7"
  local remote_log="$8"
  local exit_file="${remote_json}.exit"
  local pid_file="${remote_json}.pid"
  local local_json="$9"
  local max_wait_sec=$((runtime_sec + 180))
  local elapsed=0

  _ssh_script sudo bash -s -- \
    "$job_name" "$runtime_sec" "$rw_mode" "$block_size" "$numjobs" "$iodepth" \
    "$remote_json" "$remote_log" "$exit_file" "$pid_file" <<'EOF'
set -euo pipefail

JOB_NAME="$1"
RUNTIME_SEC="$2"
RW_MODE="$3"
BLOCK_SIZE="$4"
NUMJOBS="$5"
IODEPTH="$6"
REMOTE_JSON="$7"
REMOTE_LOG="$8"
EXIT_FILE="$9"
PID_FILE="${10}"

rm -f "$REMOTE_JSON" "$REMOTE_LOG" "$EXIT_FILE" "$PID_FILE"

(
  fio \
    --name="$JOB_NAME" \
    --rw="$RW_MODE" \
    --bs="$BLOCK_SIZE" \
    --size=64G \
    --time_based=1 \
    --runtime="$RUNTIME_SEC" \
    --numjobs="$NUMJOBS" \
    --iodepth="$IODEPTH" \
    --ioengine=libaio \
    --direct=1 \
    --group_reporting \
    --output="$REMOTE_JSON" \
    --output-format=json \
    --filename=/mnt/bv/testfile-perf
  echo $? > "$EXIT_FILE"
) </dev/null >"$REMOTE_LOG" 2>&1 &

echo $! > "$PID_FILE"
EOF

  echo "  [INFO] Waiting for ${job_name} completion (${runtime_sec}s) ..."
  while ! _ssh "sudo test -f '$exit_file'"; do
    sleep 5
    elapsed=$((elapsed + 5))
    printf "\033[2K\r  [WAIT] ${job_name} %ds" "$elapsed"
    if [ "$elapsed" -ge "$max_wait_sec" ]; then
      echo ""
      echo "  [ERROR] ${job_name} did not finish within ${max_wait_sec} seconds" >&2
      _ssh "sudo tail -n 40 '$remote_log' || true" >&2 || true
      exit 1
    fi
  done
  echo ""

  local exit_code
  exit_code=$(_ssh "sudo cat '$exit_file'")
  if [ "$exit_code" != "0" ]; then
    echo "  [ERROR] ${job_name} failed with exit code $exit_code" >&2
    _ssh "sudo tail -n 80 '$remote_log' || true" >&2 || true
    exit 1
  fi

  _scp "$remote_json" "$local_json"
  _ssh "sudo rm -f '$remote_json' '$remote_log' '$exit_file' '$pid_file'"
}

[ -n "$OCI_REGION" ] && _state_set '.inputs.oci_region' "$OCI_REGION"
_state_set '.inputs.name_prefix'                      "$NAME_PREFIX"
_state_set '.inputs.oci_compartment'                  "$COMPARTMENT_OCID"
_state_set '.subnet.ocid'                             "$SUBNET_OCID"
_state_set '.inputs.compute_shape'                    'VM.Standard.E5.Flex'
_state_set '.inputs.compute_ocpus'                    '40'
_state_set '.inputs.compute_memory_gb'                '64'
_state_set '.inputs.subnet_prohibit_public_ip'        'false'
_state_set '.inputs.compute_ssh_authorized_keys_file' "$PUBKEY_FILE"
_state_set '.inputs.bv_size_gb'                       '1500'
_state_set '.inputs.bv_vpus_per_gb'                   '120'
_state_set '.inputs.bv_attach_type'                   'iscsi'
_state_set '.inputs.bv_device_path'                   '/dev/oracleoci/oraclevdb'

ensure-compute.sh
enable_block_volume_plugin "$(_state_get '.compute.ocid')"
PUBLIC_IP=$(_state_get '.compute.public_ip')

ensure-blockvolume.sh
ATTACH_OCID=$(_state_get '.blockvolume.attachment_ocid')
DEVICE_PATH=$(_state_get '.blockvolume.device_path')
DEVICE_PATH="${DEVICE_PATH:-/dev/oracleoci/oraclevdb}"
IS_MULTIPATH=$(_state_get '.blockvolume.is_multipath')
VPU=$(_state_get '.blockvolume.vpus_per_gb')

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

_scp() {
  scp -i "$TMPKEY" "${scp_opts[@]}" "opc@${PUBLIC_IP}:$1" "$2"
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

if [ "$IS_MULTIPATH" != "true" ]; then
  echo "  [ERROR] Volume attachment is not multipath-enabled: $ATTACH_OCID" >&2
  exit 1
fi

echo "  [INFO] Multipath-enabled attachment confirmed"
prepare_guest_block_device "$ATTACH_OCID" "$DEVICE_PATH"
echo "  [INFO] Consistent device path ready: $DEVICE_PATH"
BENCH_DEVICE=$(resolve_benchmark_device "$DEVICE_PATH")
echo "  [INFO] Using benchmark device: $BENCH_DEVICE"

echo "  [INFO] Preparing block volume ..."
_ssh "sudo mkdir -p /mnt/bv"
_ssh "sudo bash -lc 'if ! blkid \"$BENCH_DEVICE\" >/dev/null 2>&1; then mkfs.ext4 -F \"$BENCH_DEVICE\"; fi; if ! mountpoint -q /mnt/bv; then mount \"$BENCH_DEVICE\" /mnt/bv; fi'"
_ssh "sudo chown opc:opc /mnt/bv"

echo "  [INFO] Installing fio ..."
_ssh "sudo dnf install -y fio jq >/dev/null"

SEQ_TMP=$(mktemp)
RAND_TMP=$(mktemp)

echo "  [INFO] Running fio sequential workload (${SEQ_RUNTIME_SEC}s) ..."
run_remote_fio \
  "seq-rw-perf" "$SEQ_RUNTIME_SEC" "rw" "1M" "1" "1" \
  "/tmp/fio-seq-perf.json" "/tmp/fio-seq-perf.log" "$SEQ_TMP"
FIO_SEQ=$(cat "$SEQ_TMP")

echo "  [INFO] Running fio random workload (${RAND_RUNTIME_SEC}s) ..."
run_remote_fio \
  "rand-rw-perf" "$RAND_RUNTIME_SEC" "randrw" "4k" "4" "32" \
  "/tmp/fio-rand-perf.json" "/tmp/fio-rand-perf.log" "$RAND_TMP"
FIO_RAND=$(cat "$RAND_TMP")
rm -f "$SEQ_TMP" "$RAND_TMP"

RESULT_JSON="$PROGRESS_DIR/fio-results-perf.json"
jq -s '{"sequential": .[0], "random": .[1]}' \
  <(echo "$FIO_SEQ") <(echo "$FIO_RAND") > "$RESULT_JSON"
echo "  [INFO] Results saved: $RESULT_JSON"

ANALYSIS_MD="$PROGRESS_DIR/fio_analysis.md"
{
  echo "# Sprint 2 — fio Analysis"
  echo ""
  echo "## Context"
  echo ""
  echo "- Region: \`$OCI_REGION\`"
  echo "- Compute shape: \`VM.Standard.E5.Flex\`"
  echo "- OCPUs: \`40\`"
  echo "- Block volume size: \`1500 GB\`"
  echo "- Block volume VPUs/GB: \`$VPU\`"
  echo "- Attachment multipath-enabled: \`$IS_MULTIPATH\`"
  echo "- Total fio runtime window: \`${FIO_TOTAL_RUNTIME_SEC} seconds\`"
  echo ""
  echo "## Summary"
  echo ""
  jq -r '
    . as $r |
    "Sequential read: \($r.sequential.jobs[0].read.iops|round) IOPS, \($r.sequential.jobs[0].read.bw/1024|round) MB/s, mean latency \((($r.sequential.jobs[0].read.lat_ns.mean)/1000000)|round) ms",
    "Sequential write: \($r.sequential.jobs[0].write.iops|round) IOPS, \($r.sequential.jobs[0].write.bw/1024|round) MB/s, mean latency \((($r.sequential.jobs[0].write.lat_ns.mean)/1000000)|round) ms",
    "Random read: \($r.random.jobs[0].read.iops|round) IOPS, \($r.random.jobs[0].read.bw/1024|round) MB/s, mean latency \((($r.random.jobs[0].read.lat_ns.mean)/1000000)|round) ms",
    "Random write: \($r.random.jobs[0].write.iops|round) IOPS, \($r.random.jobs[0].write.bw/1024|round) MB/s, mean latency \((($r.random.jobs[0].write.lat_ns.mean)/1000000)|round) ms"
  ' "$RESULT_JSON"
  echo ""
  echo "## Comparison to Sprint 1"
  echo ""
  echo "This artifact is intended to be compared directly with \`progress/sprint_1/fio-results.json\` and \`progress/sprint_1/fio_analysis.md\`."
} > "$ANALYSIS_MD"
echo "  [INFO] Analysis saved: $ANALYSIS_MD"

rm -f "$TMPKEY"

echo ""
echo "  [INFO] Tearing down compute and block volume ..."
"$SCAFFOLD_DIR/do/teardown.sh"
echo "  [INFO] Teardown complete"

print_summary
