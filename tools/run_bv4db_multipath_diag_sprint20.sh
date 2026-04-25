#!/usr/bin/env bash
# Sprint 20 (BV4DB-50): provision compute + UHP BV, enable multipath, collect diagnostics, teardown.

set -euo pipefail
set -E

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCAFFOLD_DIR="$REPO_DIR/oci_scaffold"
PROGRESS_DIR="${PROGRESS_DIR:-$REPO_DIR/progress/sprint_20}"
SPRINT1_DIR="$REPO_DIR/progress/sprint_1"
INFRA_STATE="$SPRINT1_DIR/state-bv4db.json"

export PATH="$SCAFFOLD_DIR/do:$SCAFFOLD_DIR/resource:$PATH"
if [ -z "${NAME_PREFIX:-}" ]; then
  echo "  [ERROR] NAME_PREFIX is required (example: NAME_PREFIX=bv4db-s20-mpath)" >&2
  exit 1
fi
export OCI_REGION="${OCI_REGION:-}"
export OCI_CLI_REGION="${OCI_CLI_REGION:-${OCI_REGION:-}}"

_on_err() {
  local ec=$? line=${BASH_LINENO[0]:-?} cmd=${BASH_COMMAND:-?}
  echo "  [FAIL] run_bv4db_multipath_diag_sprint20.sh failed (exit $ec) at line $line: $cmd" >&2
  if [ -n "${STATE_FILE:-}" ] && [ -f "${STATE_FILE:-}" ]; then
    echo "  [ERROR] State file: $STATE_FILE" >&2
  fi
}
trap _on_err ERR

[ -f "$INFRA_STATE" ] || { echo "  [ERROR] Infra state not found: $INFRA_STATE — Sprint 1 shared infra is required" >&2; exit 1; }

mkdir -p "$PROGRESS_DIR"
cd "$PROGRESS_DIR"

source "$SCAFFOLD_DIR/do/oci_scaffold.sh"

# Pin state file explicitly so subprocesses don't drift to ./state.json.
export STATE_FILE="${PWD}/state-${NAME_PREFIX}.json"

ssh_opts=(
  -o StrictHostKeyChecking=no
  -o ConnectTimeout=15
  -o BatchMode=yes
  -o ServerAliveInterval=10
  -o ServerAliveCountMax=3
)

COMPARTMENT_OCID=$(jq -r '.compartment.ocid' "$INFRA_STATE")
SUBNET_OCID=$(jq -r '.subnet.ocid' "$INFRA_STATE")
SECRET_OCID=$(jq -r '.secret.ocid' "$INFRA_STATE")
PUBKEY_FILE="$SPRINT1_DIR/bv4db-key.pub"

[ -n "$COMPARTMENT_OCID" ] || { echo "  [ERROR] No compartment OCID in Sprint 1 infra state" >&2; exit 1; }
[ -f "$PUBKEY_FILE" ] || { echo "  [ERROR] SSH public key not found: $PUBKEY_FILE" >&2; exit 1; }

TMPKEY=""

_cleanup() {
  [ -n "${TMPKEY:-}" ] && rm -f "$TMPKEY" || true
}
trap _cleanup EXIT

_ssh() { ssh -i "$TMPKEY" "${ssh_opts[@]}" "opc@${PUBLIC_IP}" "$@"; }

_ssh_retry() {
  # SSH to fresh instances can flap (sshd reload, cloud-init, ephemeral network).
  # Retry only on typical transport-level failures (exit 255).
  local max="${SSH_RETRY_MAX:-8}"
  local sleep_s="${SSH_RETRY_SLEEP_SEC:-5}"
  local attempt=1
  local saved_err_trap=""
  saved_err_trap="$(trap -p ERR || true)"
  trap - ERR
  _restore_err_trap() {
    # shellcheck disable=SC2064
    eval "$saved_err_trap"
  }
  while true; do
    set +e
    _ssh "$@"
    local ec=$?
    set -e

    if [ "$ec" -eq 0 ]; then
      _restore_err_trap
      return 0
    fi

    if [ "$ec" -ne 255 ] || [ "$attempt" -ge "$max" ]; then
      _restore_err_trap
      return "$ec"
    fi

    _step "SSH transport error (exit $ec). Retrying in ${sleep_s}s (attempt ${attempt}/${max})..."
    sleep "$sleep_s"
    sleep_s=$((sleep_s * 2))
    attempt=$((attempt + 1))
  done
}

_step() { echo "  [INFO] $*"; }

retry_light() {
  # Light retry intended for transient OCI waiter timeouts (exit 2).
  local max="${RETRY_MAX:-3}"
  local sleep_s="${RETRY_SLEEP_SEC:-10}"
  local attempt=1

  while true; do
    set +e
    "$@"
    local ec=$?
    set -e

    if [ "$ec" -eq 0 ]; then
      return 0
    fi

    if [ "$ec" -ne 2 ] || [ "$attempt" -ge "$max" ]; then
      return "$ec"
    fi

    _step "Transient failure (exit $ec). Retrying in ${sleep_s}s (attempt ${attempt}/${max})..."
    sleep "$sleep_s"
    sleep_s=$((sleep_s * 2))
    attempt=$((attempt + 1))
  done
}

wait_for_ssh() {
  local timeout="${SSH_WAIT_TIMEOUT_SEC:-300}"
  local elapsed=0
  _step "Waiting for SSH on $PUBLIC_IP (timeout ${timeout}s)..."
  ssh-keygen -R "$PUBLIC_IP" >/dev/null 2>&1 || true
  while ! _ssh true 2>/dev/null; do
    sleep 5
    elapsed=$((elapsed + 5))
    printf "\033[2K\r  [WAIT] SSH %ds" "$elapsed"
    if [ "$elapsed" -ge "$timeout" ]; then
      echo ""
      echo "  [ERROR] SSH did not become available within ${timeout}s" >&2
      return 1
    fi
  done
  echo ""
}

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

  [ -n "$ssh_host" ] || true
  _ssh_retry sudo bash -s -- "$iqn" "$port" "$expected_path" "${targets[@]}" <<'EOF'
set -euo pipefail
IQN="$1"
PORT="$2"
DEVICE_PATH="$3"
shift 3
TARGETS=("$@")

systemctl enable --now iscsid >/dev/null
mpathconf --enable --with_multipathd y >/dev/null
systemctl enable --now multipathd >/dev/null

# Hard verification: if this fails, provisioning must be considered broken.
systemctl is-enabled iscsid >/dev/null
systemctl is-active iscsid >/dev/null
systemctl is-enabled multipathd >/dev/null
systemctl is-active multipathd >/dev/null

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

guest_verify_multipath() {
  local expected_path="$1"
  _step "Verifying guest multipath services + device..."
  # Re-wait for SSH in case guest_configure_multipath triggered a transient sshd/network flap.
  wait_for_ssh
  _ssh_retry sudo bash -s -- "$expected_path" <<'EOF'
set -euo pipefail
EXPECTED_PATH="$1"

systemctl is-enabled iscsid >/dev/null
systemctl is-active iscsid >/dev/null
systemctl is-enabled multipathd >/dev/null
systemctl is-active multipathd >/dev/null

# Expect at least one multipath map and multiple paths when multipath is enabled.
multipath -ll >/tmp/multipath_ll.txt
grep -qE '^mpath' /tmp/multipath_ll.txt

# Ensure the expected device exists.
[ -b "$EXPECTED_PATH" ]

# Stronger check: at least 2 active paths shown for the first map.
path_count="$(grep -E ' active ready running' /tmp/multipath_ll.txt | wc -l | tr -d ' ')"
[ "${path_count:-0}" -ge 2 ]
EOF
}

guest_collect_diagnostics() {
  local out_file="$1"
  wait_for_ssh
  _ssh_retry sudo bash -s -- <<'EOF' >"$out_file"
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
echo "=== lsblk ==="; lsblk -o NAME,TYPE,SIZE,MODEL,WWN,MOUNTPOINT || true; echo
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
  export ATTACHMENT_TYPE="iscsi"

  [ -n "$OCI_REGION" ] && _state_set '.inputs.oci_region' "$OCI_REGION"
  _state_set '.inputs.name_prefix'                      "$NAME_PREFIX"
  _state_set '.inputs.oci_compartment'                  "$COMPARTMENT_OCID"
  _state_set '.subnet.ocid'                             "$SUBNET_OCID"
  _state_set '.inputs.compute_shape'                    "$COMPUTE_SHAPE"
  _state_set '.inputs.compute_ocpus'                    "$COMPUTE_OCPUS"
  _state_set '.inputs.compute_memory_gb'                "$COMPUTE_MEMORY_GB"
  _state_set '.inputs.subnet_prohibit_public_ip'        'false'
  _state_set '.inputs.compute_ssh_authorized_keys_file' "$PUBKEY_FILE"
  _state_set '.inputs.bv_size_gb'                       "$BLOCKVOLUME_SIZE_GB"
  _state_set '.inputs.bv_vpus_per_gb'                   "$BLOCKVOLUME_VPUS_PER_GB"
  _state_set '.inputs.bv_attach_type'                   "$ATTACHMENT_TYPE"
  _state_set '.inputs.bv_is_multipath'                  'true'
  _state_set '.inputs.bv_device_path'                   '/dev/oracleoci/oraclevdb'

  _step "Provisioning/adopting compute (may take a few minutes)..."
  env NAME_PREFIX="$NAME_PREFIX" ensure-compute.sh

  enable_block_volume_plugin "$(_state_get '.compute.ocid')"
  PUBLIC_IP=$(_state_get '.compute.public_ip')

  TMPKEY=$(mktemp)
  chmod 600 "$TMPKEY"
  oci secrets secret-bundle get \
    --secret-id "$SECRET_OCID" \
    --query 'data."secret-bundle-content".content' --raw-output \
    | base64 --decode > "$TMPKEY"

  wait_for_ssh

  _step "Provisioning/adopting block volume and attachment..."
  retry_light env NAME_PREFIX="$NAME_PREFIX" ensure-blockvolume.sh
  local volume_attach_id expected_path
  volume_attach_id=$(_state_get '.blockvolume.attachment_ocid')
  expected_path=$(_state_get '.blockvolume.device_path')
  expected_path="${expected_path:-/dev/oracleoci/oraclevdb}"

  local attachment_json iqn port
  attachment_json=$(oci compute volume-attachment get --volume-attachment-id "$volume_attach_id")
  local is_multipath
  is_multipath=$(echo "$attachment_json" | jq -r '.data."is-multipath" // empty')
  if [ "$is_multipath" != "true" ]; then
    echo "  [ERROR] Attachment is not multipath-enabled: $volume_attach_id (is-multipath=$is_multipath)" >&2
    exit 1
  fi
  iqn=$(echo "$attachment_json" | jq -r '.data.iqn')
  port=$(echo "$attachment_json" | jq -r '.data.port')
  mapfile -t target_ips < <(echo "$attachment_json" | jq -r '([.data.ipv4] + [.data."multipath-devices"[]?.ipv4]) | unique[]')

  guest_configure_multipath "opc@${PUBLIC_IP}" "$iqn" "$port" "$expected_path" "${target_ips[@]}"
  guest_verify_multipath "$expected_path"
  guest_collect_diagnostics "$diag_out"
  cp -f "$STATE_FILE" "$state_out"
  ln -sf "$(basename "$state_out")" "$PROGRESS_DIR/state-bv4db-s20-latest.json"

  if [ "${KEEP_INFRA:-false}" = "true" ]; then
    echo "  [INFO] KEEP_INFRA=true — skipping teardown"
    echo "  [INFO] State: $state_out"
    echo "  [INFO] Public IP: $PUBLIC_IP"
  else
    echo "  [INFO] Teardown ..."
    teardown-blockvolume.sh
    teardown-compute.sh
    rm -f "$STATE_FILE" || true
  fi

  echo "  [DONE] Diagnostics: $diag_out"
}

main "$@"

