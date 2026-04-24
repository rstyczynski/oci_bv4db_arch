#!/usr/bin/env bash
# Sprint 20 (BV4DB-50): provision compute + UHP BV, enable multipath, collect diagnostics, teardown.

set -euo pipefail
set -E

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCAFFOLD_DIR="$REPO_DIR/oci_scaffold"
PROGRESS_DIR="$REPO_DIR/progress/sprint_20"
SPRINT1_DIR="$REPO_DIR/progress/sprint_1"
INFRA_STATE="$SPRINT1_DIR/state-bv4db.json"

export PATH="$SCAFFOLD_DIR/do:$SCAFFOLD_DIR/resource:$PATH"
export NAME_PREFIX="${NAME_PREFIX:-bv4db-s20-mpath-diag}"
export OCI_REGION="${OCI_REGION:-}"
export OCI_CLI_REGION="${OCI_CLI_REGION:-${OCI_REGION:-}}"

_on_err() {
  local ec=$? line=${BASH_LINENO[0]:-?} cmd=${BASH_COMMAND:-?}
  echo "  [FAIL] run_bv4db_multipath_diag_sprint20.sh failed (exit $ec) at line $line: $cmd" >&2
}
trap _on_err ERR

[ -f "$INFRA_STATE" ] || { echo "  [ERROR] Infra state not found: $INFRA_STATE — Sprint 1 shared infra is required" >&2; exit 1; }

mkdir -p "$PROGRESS_DIR"
cd "$PROGRESS_DIR"

source "$SCAFFOLD_DIR/do/oci_scaffold.sh"

ssh_opts=(-n -o StrictHostKeyChecking=no -o ConnectTimeout=15 -o BatchMode=yes)

COMPARTMENT_OCID=$(jq -r '.compartment.ocid' "$INFRA_STATE")
SUBNET_OCID=$(jq -r '.subnet.ocid' "$INFRA_STATE")
PUBKEY_FILE="$SPRINT1_DIR/bv4db-key.pub"

[ -n "$COMPARTMENT_OCID" ] || { echo "  [ERROR] No compartment OCID in Sprint 1 infra state" >&2; exit 1; }
[ -f "$PUBKEY_FILE" ] || { echo "  [ERROR] SSH public key not found: $PUBKEY_FILE" >&2; exit 1; }

_ssh() { ssh "${ssh_opts[@]}" "$@"; }

enable_block_volume_plugin() {
  local instance_id="$1"
  oci compute instance update \
    --instance-id "$instance_id" \
    --agent-config '{"areAllPluginsDisabled":false,"isManagementDisabled":false,"isMonitoringDisabled":false,"pluginsConfig":[{"name":"Block Volume Management","desiredState":"ENABLED"}]}' \
    --force >/dev/null
}

guest_configure_multipath() {
  local ssh_host="$1"
  local iqn="$2"
  local port="$3"
  local expected_path="$4"
  shift 4
  local -a targets=("$@")

  _ssh "$ssh_host" sudo bash -s -- "$iqn" "$port" "$expected_path" "${targets[@]}" <<'EOF'
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

guest_collect_diagnostics() {
  local ssh_host="$1"
  local out_file="$2"
  _ssh "$ssh_host" sudo bash -s -- <<'EOF' >"$out_file"
set -euo pipefail
echo "=== date ==="; date -u; echo
echo "=== uname ==="; uname -a || true; echo
echo "=== systemctl status iscsid ==="; systemctl status iscsid --no-pager || true; echo
echo "=== systemctl status multipathd ==="; systemctl status multipathd --no-pager || true; echo
echo "=== iscsiadm -m session ==="; iscsiadm -m session || true; echo
echo "=== iscsiadm -m node ==="; iscsiadm -m node || true; echo
echo "=== multipath -ll ==="; multipath -ll || true; echo
echo "=== multipathd show paths ==="; multipathd show paths || true; echo
echo "=== multipathd show maps ==="; multipathd show maps || true; echo
echo "=== lsblk ==="; lsblk -o NAME,TYPE,SIZE,MODEL,WWN,MOUNTPOINTS || true; echo
echo "=== dmsetup ls --tree ==="; dmsetup ls --tree || true; echo
echo "=== /dev/oracleoci ==="; ls -la /dev/oracleoci || true; echo
echo "=== udevadm info (oracleoci block device) ==="
DEV="$(readlink -f /dev/oracleoci/oraclevdb 2>/dev/null || true)"
if [ -n "${DEV:-}" ] && [ -b "$DEV" ]; then
  udevadm info --query=all --name "$DEV" || true
fi
EOF
}

main() {
  echo ""
  echo "=== Sprint 20: multipath diagnostics sandbox ==="
  echo ""

  local ts; ts="$(date -u '+%Y%m%d_%H%M%S')"
  local diag_out="$PROGRESS_DIR/multipath_diagnostics_${ts}.txt"
  local state_out="$PROGRESS_DIR/state-bv4db-s20-mpath-diag_${ts}.json"

  export COMPUTE_SHAPE="${COMPUTE_SHAPE:-VM.Standard.E5.Flex}"
  export COMPUTE_OCPUS="${COMPUTE_OCPUS:-16}"
  export COMPUTE_MEMORY_GB="${COMPUTE_MEMORY_GB:-64}"

  export BLOCKVOLUME_SIZE_GB="${BLOCKVOLUME_SIZE_GB:-1500}"
  export BLOCKVOLUME_VPUS_PER_GB="${BLOCKVOLUME_VPUS_PER_GB:-120}"
  export ATTACHMENT_TYPE="${ATTACHMENT_TYPE:-iscsi}"

  ensure_compute.sh --compartment-ocid "$COMPARTMENT_OCID" --subnet-ocid "$SUBNET_OCID" --ssh-pubkey-file "$PUBKEY_FILE" --shape "$COMPUTE_SHAPE" --ocpus "$COMPUTE_OCPUS" --memory-gb "$COMPUTE_MEMORY_GB"
  ensure_blockvolume.sh --compartment-ocid "$COMPARTMENT_OCID" --size-gb "$BLOCKVOLUME_SIZE_GB" --vpus-per-gb "$BLOCKVOLUME_VPUS_PER_GB"
  ensure_blockvolume_attachment.sh --attachment-type "$ATTACHMENT_TYPE"

  local instance_id volume_attach_id public_ip
  instance_id=$(jq -r '.compute.ocid' state.json)
  volume_attach_id=$(jq -r '.blockvolume_attachment.ocid' state.json)
  public_ip=$(jq -r '.compute.public_ip' state.json)

  enable_block_volume_plugin "$instance_id"

  local attachment_json iqn port
  attachment_json=$(oci compute volume-attachment get --volume-attachment-id "$volume_attach_id")
  iqn=$(echo "$attachment_json" | jq -r '.data.iqn')
  port=$(echo "$attachment_json" | jq -r '.data.port')
  mapfile -t target_ips < <(echo "$attachment_json" | jq -r '([.data.ipv4] + [.data."multipath-devices"[]?.ipv4]) | unique[]')

  local ssh_host="opc@${public_ip}"
  local expected_path="/dev/oracleoci/oraclevdb"

  guest_configure_multipath "$ssh_host" "$iqn" "$port" "$expected_path" "${target_ips[@]}"
  guest_collect_diagnostics "$ssh_host" "$diag_out"
  cp -f state.json "$state_out"

  echo "  [INFO] Teardown ..."
  teardown_compute.sh || true
  teardown_blockvolume_attachment.sh || true
  teardown_blockvolume.sh || true

  echo "  [DONE] Diagnostics: $diag_out"
}

main "$@"

