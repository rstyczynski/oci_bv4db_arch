#!/usr/bin/env bash
# run_bv_fio_oracle.sh — Sprint 4 Oracle-style multi-volume layout with concurrent fio workloads.

set -euo pipefail
set -E

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCAFFOLD_DIR="$REPO_DIR/oci_scaffold"
PROGRESS_DIR="$REPO_DIR/progress/sprint_4"
SPRINT1_DIR="$REPO_DIR/progress/sprint_1"
INFRA_STATE="$SPRINT1_DIR/state-bv4db.json"
PROFILE_FILE="$PROGRESS_DIR/oracle-layout.fio"

export PATH="$SCAFFOLD_DIR/do:$SCAFFOLD_DIR/resource:$PATH"
export NAME_PREFIX="bv4db-oracle-run"
export OCI_REGION="${OCI_REGION:-}"
export OCI_CLI_REGION="${OCI_CLI_REGION:-${OCI_REGION:-}}"
RUN_LEVEL="${RUN_LEVEL:-smoke}"
FIO_RUNTIME_SEC="${FIO_RUNTIME_SEC:-60}"

_on_err() {
  local ec=$? line=${BASH_LINENO[0]:-?} cmd=${BASH_COMMAND:-?}
  echo "  [FAIL] run_bv_fio_oracle.sh failed (exit $ec) at line $line: $cmd" >&2
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

# Volume configuration: name, device_path, vpu_per_gb, size_gb
declare -A VOLUMES
VOLUMES[data1]="/dev/oracleoci/oraclevdb:120:200"
VOLUMES[data2]="/dev/oracleoci/oraclevdc:120:200"
VOLUMES[redo1]="/dev/oracleoci/oraclevdd:20:50"
VOLUMES[redo2]="/dev/oracleoci/oraclevde:20:50"
VOLUMES[fra]="/dev/oracleoci/oraclevdf:10:100"

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
MAPPER_PATH=$(lsblk -nrpo NAME,TYPE "$RESOLVED_PATH" | awk '$2 == "mpath" { print $1; exit }')
if [ -n "${MAPPER_PATH:-}" ]; then
  echo "$MAPPER_PATH"
else
  echo "$EXPECTED_PATH"
fi
EOF
}

configure_guest_lvm() {
  local data1_dev="$1"
  local data2_dev="$2"
  local redo1_dev="$3"
  local redo2_dev="$4"
  local fra_dev="$5"

  echo "  [INFO] Configuring guest LVM (vg_data, vg_redo, FRA direct mount) ..."
  _ssh_script sudo bash -s -- "$data1_dev" "$data2_dev" "$redo1_dev" "$redo2_dev" "$fra_dev" <<'EOF'
set -euo pipefail
DATA1="$1"
DATA2="$2"
REDO1="$3"
REDO2="$4"
FRA="$5"

# Install LVM if needed
dnf install -y lvm2 >/dev/null 2>&1 || true

# Data volume group — stripe across two UHP volumes
if ! vgs vg_data >/dev/null 2>&1; then
  pvcreate -ff -y "$DATA1" "$DATA2"
  vgcreate vg_data "$DATA1" "$DATA2"
  lvcreate -l 100%FREE -n lv_oradata -i 2 -I 256K vg_data
  mkfs.ext4 -F /dev/vg_data/lv_oradata
fi
mkdir -p /u02/oradata
mountpoint -q /u02/oradata || mount /dev/vg_data/lv_oradata /u02/oradata
chown opc:opc /u02/oradata

# Redo volume group — stripe across two HP volumes
if ! vgs vg_redo >/dev/null 2>&1; then
  pvcreate -ff -y "$REDO1" "$REDO2"
  vgcreate vg_redo "$REDO1" "$REDO2"
  lvcreate -l 100%FREE -n lv_redo -i 2 -I 256K vg_redo
  mkfs.ext4 -F /dev/vg_redo/lv_redo
fi
mkdir -p /u03/redo
mountpoint -q /u03/redo || mount /dev/vg_redo/lv_redo /u03/redo
chown opc:opc /u03/redo

# FRA — direct mount (no striping)
if ! blkid "$FRA" >/dev/null 2>&1; then
  mkfs.ext4 -F "$FRA"
fi
mkdir -p /u04/fra
mountpoint -q /u04/fra || mount "$FRA" /u04/fra
chown opc:opc /u04/fra

echo "LVM configuration complete"
lsblk
df -h /u02/oradata /u03/redo /u04/fra
EOF
}

run_remote_fio_with_iostat() {
  local runtime_sec="$1"
  local remote_profile="/tmp/oracle-layout.fio"
  local remote_json="/tmp/fio-oracle-${RUN_LEVEL}.json"
  local remote_iostat="/tmp/iostat-oracle-${RUN_LEVEL}.json"
  local remote_log="/tmp/fio-oracle-${RUN_LEVEL}.log"
  local exit_file="${remote_json}.exit"
  local pid_file="${remote_json}.pid"
  local remote_runner="/tmp/run-oracle-${RUN_LEVEL}.sh"
  local local_json="$PROGRESS_DIR/fio-results-oracle-${RUN_LEVEL}.json"
  local local_iostat="$PROGRESS_DIR/iostat-oracle-${RUN_LEVEL}.json"
  local max_wait_sec=$((runtime_sec + 300))
  local elapsed=0
  local tmp_profile

  # Adjust runtime in profile
  tmp_profile=$(mktemp)
  awk -v runtime="$runtime_sec" '
    /^runtime=/ { print "runtime=" runtime; next }
    { print }
  ' "$PROFILE_FILE" > "$tmp_profile"
  _scp_to_remote "$tmp_profile" "$remote_profile"
  rm -f "$tmp_profile"
  _ssh "sudo chown opc:opc '$remote_profile'"

  # Create runner script with iostat capture
  _ssh_script bash -s -- \
    "$runtime_sec" "$remote_profile" "$remote_json" "$remote_iostat" "$remote_log" "$exit_file" "$pid_file" "$remote_runner" <<'EOF'
set -euo pipefail
RUNTIME_SEC="$1"
REMOTE_PROFILE="$2"
REMOTE_JSON="$3"
REMOTE_IOSTAT="$4"
REMOTE_LOG="$5"
EXIT_FILE="$6"
PID_FILE="$7"
REMOTE_RUNNER="$8"
rm -f "$REMOTE_JSON" "$REMOTE_IOSTAT" "$REMOTE_LOG" "$EXIT_FILE" "$PID_FILE" "$REMOTE_RUNNER"
cat > "$REMOTE_RUNNER" <<RUNNER
#!/usr/bin/env bash
# Start iostat in background (10s intervals, JSON output)
iostat -xdmz 10 -o JSON > "$REMOTE_IOSTAT" 2>&1 &
IOSTAT_PID=\$!

# Run fio
fio --runtime="$RUNTIME_SEC" --output="$REMOTE_JSON" --output-format=json "$REMOTE_PROFILE" >"$REMOTE_LOG" 2>&1
rc=\$?

# Stop iostat
kill \$IOSTAT_PID 2>/dev/null || true
wait \$IOSTAT_PID 2>/dev/null || true

echo "\$rc" > "$EXIT_FILE"
RUNNER
chmod +x "$REMOTE_RUNNER"
nohup bash "$REMOTE_RUNNER" >/dev/null 2>&1 &
echo $! > "$PID_FILE"
EOF

  echo "  [INFO] Waiting for Oracle fio completion (${runtime_sec}s) ..."
  while ! _ssh "test -f '$exit_file'"; do
    sleep 10
    elapsed=$((elapsed + 10))
    printf "\033[2K\r  [WAIT] oracle-fio %ds" "$elapsed"
    if [ "$elapsed" -ge "$max_wait_sec" ]; then
      echo ""
      echo "  [ERROR] oracle-fio did not finish within ${max_wait_sec} seconds" >&2
      _ssh "tail -n 80 '$remote_log' || true" >&2 || true
      exit 1
    fi
  done
  echo ""

  local exit_code
  exit_code=$(_ssh "cat '$exit_file'")
  if [ "$exit_code" != "0" ]; then
    echo "  [ERROR] oracle-fio failed with exit code $exit_code" >&2
    _ssh "tail -n 80 '$remote_log' || true" >&2 || true
    exit 1
  fi

  _scp_from_remote "$remote_json" "$local_json"
  _scp_from_remote "$remote_iostat" "$local_iostat"
  _ssh "rm -f '$remote_profile' '$remote_json' '$remote_iostat' '$remote_log' '$exit_file' '$pid_file' '$remote_runner'"
  echo "$local_json"
}

# Initialize state
[ -n "$OCI_REGION" ] && _state_set '.inputs.oci_region' "$OCI_REGION"
_state_set '.inputs.name_prefix'                      "$NAME_PREFIX"
_state_set '.inputs.oci_compartment'                  "$COMPARTMENT_OCID"
_state_set '.subnet.ocid'                             "$SUBNET_OCID"
_state_set '.inputs.compute_shape'                    'VM.Standard.E5.Flex'
_state_set '.inputs.compute_ocpus'                    '40'
_state_set '.inputs.compute_memory_gb'                '64'
_state_set '.inputs.subnet_prohibit_public_ip'        'false'
_state_set '.inputs.compute_ssh_authorized_keys_file' "$PUBKEY_FILE"
_state_set '.inputs.run_level'                        "$RUN_LEVEL"
_state_set '.inputs.fio_runtime_sec'                  "$FIO_RUNTIME_SEC"

# Provision compute
echo "  [INFO] Provisioning compute instance ..."
ensure-compute.sh
enable_block_volume_plugin "$(_state_get '.compute.ocid')"
PUBLIC_IP=$(_state_get '.compute.public_ip')
INSTANCE_OCID=$(_state_get '.compute.ocid')

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

# Provision and attach all block volumes
declare -A ATTACH_OCIDS
declare -A MPATH_DEVICES

for vol_name in data1 data2 redo1 redo2 fra; do
  IFS=':' read -r dev_path vpu size_gb <<< "${VOLUMES[$vol_name]}"
  echo "  [INFO] Provisioning block volume: $vol_name ($size_gb GB, $vpu VPU/GB) ..."

  # Create a separate state file for each volume
  vol_state="$PROGRESS_DIR/state-bv-${vol_name}.json"

  # Set volume-specific inputs
  export STATE_FILE="$vol_state"
  _state_set '.inputs.name_prefix' "bv4db-${vol_name}"
  _state_set '.inputs.oci_compartment' "$COMPARTMENT_OCID"
  _state_set '.inputs.bv_size_gb' "$size_gb"
  _state_set '.inputs.bv_vpus_per_gb' "$vpu"
  _state_set '.inputs.bv_attach_type' 'iscsi'
  _state_set '.inputs.bv_device_path' "$dev_path"
  _state_set '.compute.ocid' "$INSTANCE_OCID"

  ensure-blockvolume.sh

  ATTACH_OCIDS[$vol_name]=$(_state_get '.blockvolume.attachment_ocid')

  echo "  [INFO] Preparing iSCSI for $vol_name ..."
  prepare_guest_block_device "${ATTACH_OCIDS[$vol_name]}" "$dev_path"

  MPATH_DEVICES[$vol_name]=$(resolve_mpath_device "$dev_path")
  echo "  [INFO] $vol_name mpath device: ${MPATH_DEVICES[$vol_name]}"
done

# Reset STATE_FILE to main state
export STATE_FILE="$PROGRESS_DIR/state-${NAME_PREFIX}.json"

# Configure LVM
configure_guest_lvm \
  "${MPATH_DEVICES[data1]}" "${MPATH_DEVICES[data2]}" \
  "${MPATH_DEVICES[redo1]}" "${MPATH_DEVICES[redo2]}" \
  "${MPATH_DEVICES[fra]}"

# Install fio
echo "  [INFO] Installing fio and sysstat ..."
_ssh "sudo dnf install -y fio sysstat jq >/dev/null"

# Run fio with iostat capture
RESULT_JSON=$(run_remote_fio_with_iostat "$FIO_RUNTIME_SEC")
_state_set '.artifacts.result_json' "$RESULT_JSON"
echo "  [INFO] Results saved: $RESULT_JSON"

# Generate analysis
ANALYSIS_MD="$PROGRESS_DIR/fio-analysis-oracle-${RUN_LEVEL}.md"
{
  echo "# Sprint 4 — Oracle Layout fio Analysis (${RUN_LEVEL})"
  echo ""
  echo "## Context"
  echo ""
  echo "- Runtime: \`${FIO_RUNTIME_SEC} seconds\`"
  echo "- Region: \`${OCI_REGION}\`"
  echo "- Compute shape: \`VM.Standard.E5.Flex\` (40 OCPUs)"
  echo "- Block volumes: 5 (2x UHP 120 VPU, 2x HP 20 VPU, 1x Balanced 10 VPU)"
  echo ""
  echo "## Measured Results"
  echo ""
  jq -r '
    .jobs[] |
    "### Job: \(.jobname)\n" +
    "- Read: \((.read.iops // 0)|round) IOPS, \(((.read.bw // 0)/1024)|round) MB/s, mean lat \((((.read.lat_ns.mean // 0)/1000000))|round) ms\n" +
    "- Write: \((.write.iops // 0)|round) IOPS, \(((.write.bw // 0)/1024)|round) MB/s, mean lat \((((.write.lat_ns.mean // 0)/1000000))|round) ms\n"
  ' "$RESULT_JSON"
  echo ""
  echo "## Interpretation"
  echo ""
  echo "This Sprint 4 run validates the Oracle-style multi-volume layout with concurrent fio workloads."
  echo "Each storage class (data, redo, FRA) runs its characteristic I/O pattern simultaneously."
} > "$ANALYSIS_MD"
_state_set '.artifacts.analysis_md' "$ANALYSIS_MD"
echo "  [INFO] Analysis saved: $ANALYSIS_MD"

rm -f "$TMPKEY"

# Teardown
echo ""
echo "  [INFO] Tearing down compute and block volumes ..."

# Teardown each volume
for vol_name in data1 data2 redo1 redo2 fra; do
  vol_state="$PROGRESS_DIR/state-bv-${vol_name}.json"
  if [ -f "$vol_state" ]; then
    export STATE_FILE="$vol_state"
    "$SCAFFOLD_DIR/do/teardown.sh" || true
  fi
done

# Teardown compute
export STATE_FILE="$PROGRESS_DIR/state-${NAME_PREFIX}.json"
"$SCAFFOLD_DIR/do/teardown.sh"

echo "  [INFO] Teardown complete"

print_summary
