#!/usr/bin/env bash
# run_bv_fio_mixed8k.sh — Sprint 3 mixed-8k fio profile on Sprint 2 UHP topology.

set -euo pipefail
set -E

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCAFFOLD_DIR="$REPO_DIR/oci_scaffold"
PROGRESS_DIR="$REPO_DIR/progress/sprint_3"
SPRINT1_DIR="$REPO_DIR/progress/sprint_1"
INFRA_STATE="$SPRINT1_DIR/state-bv4db.json"
PROFILE_FILE="$PROGRESS_DIR/mixed-8k.fio"

export PATH="$SCAFFOLD_DIR/do:$SCAFFOLD_DIR/resource:$PATH"
export NAME_PREFIX="bv4db-mixed8k-run"
export OCI_REGION="${OCI_REGION:-}"
export OCI_CLI_REGION="${OCI_CLI_REGION:-${OCI_REGION:-}}"
RUN_LEVEL="${RUN_LEVEL:-smoke}"
FIO_RUNTIME_SEC="${FIO_RUNTIME_SEC:-60}"

_on_err() {
  local ec=$? line=${BASH_LINENO[0]:-?} cmd=${BASH_COMMAND:-?}
  echo "  [FAIL] run_bv_fio_mixed8k.sh failed (exit $ec) at line $line: $cmd" >&2
}
trap _on_err ERR

[ -f "$INFRA_STATE" ] || { echo "  [ERROR] Infra state not found: $INFRA_STATE" >&2; exit 1; }
[ -f "$PROFILE_FILE" ] || { echo "  [ERROR] fio profile not found: $PROFILE_FILE" >&2; exit 1; }

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

run_remote_profile() {
  local runtime_sec="$1"
  local remote_profile="/tmp/mixed-8k.fio"
  local remote_json="/tmp/fio-mixed8k-${RUN_LEVEL}.json"
  local remote_log="/tmp/fio-mixed8k-${RUN_LEVEL}.log"
  local exit_file="${remote_json}.exit"
  local pid_file="${remote_json}.pid"
  local remote_runner="/tmp/run-mixed8k-${RUN_LEVEL}.sh"
  local local_json="$PROGRESS_DIR/fio-results-mixed8k-${RUN_LEVEL}.json"
  local max_wait_sec=$((runtime_sec + 180))
  local elapsed=0
  local tmp_profile

  tmp_profile=$(mktemp)
  awk -v runtime="$runtime_sec" '
    /^runtime=/ { print "runtime=" runtime; next }
    { print }
  ' "$PROFILE_FILE" > "$tmp_profile"
  _scp_to_remote "$tmp_profile" "$remote_profile"
  rm -f "$tmp_profile"
  _ssh "sudo chown opc:opc '$remote_profile'"

  _ssh_script bash -s -- \
    "$runtime_sec" "$remote_profile" "$remote_json" "$remote_log" "$exit_file" "$pid_file" "$remote_runner" <<'EOF'
set -euo pipefail
RUNTIME_SEC="$1"
REMOTE_PROFILE="$2"
REMOTE_JSON="$3"
REMOTE_LOG="$4"
EXIT_FILE="$5"
PID_FILE="$6"
REMOTE_RUNNER="$7"
rm -f "$REMOTE_JSON" "$REMOTE_LOG" "$EXIT_FILE" "$PID_FILE" "$REMOTE_RUNNER"
cat > "$REMOTE_RUNNER" <<RUNNER
#!/usr/bin/env bash
fio --runtime="$RUNTIME_SEC" --output="$REMOTE_JSON" --output-format=json "$REMOTE_PROFILE" >"$REMOTE_LOG" 2>&1
rc=\$?
echo "\$rc" > "$EXIT_FILE"
RUNNER
chmod +x "$REMOTE_RUNNER"
nohup bash "$REMOTE_RUNNER" >/dev/null 2>&1 &
echo $! > "$PID_FILE"
EOF

  echo "  [INFO] Waiting for mixed-8k completion (${runtime_sec}s) ..."
  while ! _ssh "test -f '$exit_file'"; do
    sleep 5
    elapsed=$((elapsed + 5))
    printf "\033[2K\r  [WAIT] mixed-8k %ds" "$elapsed"
    if [ "$elapsed" -ge "$max_wait_sec" ]; then
      echo ""
      echo "  [ERROR] mixed-8k did not finish within ${max_wait_sec} seconds" >&2
      _ssh "tail -n 80 '$remote_log' || true" >&2 || true
      exit 1
    fi
  done
  echo ""

  local exit_code
  exit_code=$(_ssh "cat '$exit_file'")
  if [ "$exit_code" != "0" ]; then
    echo "  [ERROR] mixed-8k failed with exit code $exit_code" >&2
    _ssh "tail -n 80 '$remote_log' || true" >&2 || true
    exit 1
  fi

  _scp_from_remote "$remote_json" "$local_json"
  _ssh "rm -f '$remote_profile' '$remote_json' '$remote_log' '$exit_file' '$pid_file' '$remote_runner'"
  echo "$local_json"
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
_state_set '.inputs.run_level'                        "$RUN_LEVEL"
_state_set '.inputs.fio_runtime_sec'                  "$FIO_RUNTIME_SEC"

ensure-compute.sh
enable_block_volume_plugin "$(_state_get '.compute.ocid')"
PUBLIC_IP=$(_state_get '.compute.public_ip')

ensure-blockvolume.sh
ATTACH_OCID=$(_state_get '.blockvolume.attachment_ocid')
DEVICE_PATH=$(_state_get '.blockvolume.device_path')
DEVICE_PATH="${DEVICE_PATH:-/dev/oracleoci/oraclevdb}"

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

echo "  [INFO] Preparing UHP multipath block device ..."
prepare_guest_block_device "$ATTACH_OCID" "$DEVICE_PATH"
BENCH_DEVICE=$(resolve_benchmark_device "$DEVICE_PATH")
echo "  [INFO] Using benchmark device: $BENCH_DEVICE"

_ssh "sudo mkdir -p /mnt/bv"
_ssh "sudo bash -lc 'if ! blkid \"$BENCH_DEVICE\" >/dev/null 2>&1; then mkfs.ext4 -F \"$BENCH_DEVICE\"; fi; if ! mountpoint -q /mnt/bv; then mount \"$BENCH_DEVICE\" /mnt/bv; fi'"
_ssh "sudo chown opc:opc /mnt/bv"
_ssh "sudo dnf install -y fio jq >/dev/null"

RESULT_JSON=$(run_remote_profile "$FIO_RUNTIME_SEC")
_state_set '.artifacts.result_json' "$RESULT_JSON"
echo "  [INFO] Results saved: $RESULT_JSON"

ANALYSIS_MD="$PROGRESS_DIR/fio-analysis-mixed8k-${RUN_LEVEL}.md"
jq -r '
  .jobs[0] as $j |
  [
    "# Sprint 3 — Mixed 8k fio Analysis (" + $run_level + ")",
    "",
    "## Context",
    "",
    "- Runtime: `" + $runtime + " seconds`",
    "- Region: `" + $region + "`",
    "- Compute shape: `VM.Standard.E5.Flex`",
    "- Block volume VPUs/GB: `120`",
    "",
    "## Measured Results",
    "",
    "- Read: " + (($j.read.iops|round|tostring)) + " IOPS, " + (($j.read.bw/1024|round|tostring)) + " MB/s, mean latency " + ((($j.read.lat_ns.mean/1000000)|round|tostring)) + " ms",
    "- Write: " + (($j.write.iops|round|tostring)) + " IOPS, " + (($j.write.bw/1024|round|tostring)) + " MB/s, mean latency " + ((($j.write.lat_ns.mean/1000000)|round|tostring)) + " ms",
    "- Read mix: `70%`, block size: `8k`, numjobs: `4`, iodepth: `32`",
    "",
    "## Interpretation",
    "",
    "This Sprint 3 run validates the mixed 8k fio profile file on the Sprint 2 UHP topology. Compare this artifact with Sprint 2 to determine how the database-oriented mixed workload shifts throughput and latency relative to the earlier benchmark."
  ] | .[]
' --arg run_level "$RUN_LEVEL" --arg runtime "$FIO_RUNTIME_SEC" --arg region "$OCI_REGION" "$RESULT_JSON" > "$ANALYSIS_MD"
_state_set '.artifacts.analysis_md' "$ANALYSIS_MD"
echo "  [INFO] Analysis saved: $ANALYSIS_MD"

rm -f "$TMPKEY"

echo ""
echo "  [INFO] Tearing down compute and block volume ..."
"$SCAFFOLD_DIR/do/teardown.sh"
echo "  [INFO] Teardown complete"

print_summary
