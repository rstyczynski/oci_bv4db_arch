#!/usr/bin/env bash
# Sprint 24: validate OCI agent-managed UHP iSCSI multipath without custom multipath setup.

set -euo pipefail
set -E

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCAFFOLD_DIR="$REPO_DIR/oci_scaffold"
PROGRESS_DIR="${PROGRESS_DIR:-$REPO_DIR/progress/sprint_24}"
SPRINT1_DIR="$REPO_DIR/progress/sprint_1"
INFRA_STATE="$SPRINT1_DIR/state-bv4db.json"

export PATH="$SCAFFOLD_DIR/do:$SCAFFOLD_DIR/resource:$PATH"
if [ -z "${NAME_PREFIX:-}" ]; then
  export NAME_PREFIX="bv4db-s24-agent"
  echo "  [INFO] NAME_PREFIX not set; using Sprint 24 default: NAME_PREFIX=$NAME_PREFIX" >&2
fi
export OCI_REGION="${OCI_REGION:-}"
export OCI_CLI_REGION="${OCI_CLI_REGION:-${OCI_REGION:-}}"

_on_err() {
  local ec=$? line=${BASH_LINENO[0]:-?} cmd=${BASH_COMMAND:-?}
  echo "  [FAIL] run_bv4db_oci_agent_multipath_sprint24.sh failed (exit $ec) at line $line: $cmd" >&2
  if [ -n "${STATE_FILE:-}" ] && [ -f "${STATE_FILE:-}" ]; then
    echo "  [ERROR] State file: $STATE_FILE" >&2
  fi
}
trap _on_err ERR

[ -f "$INFRA_STATE" ] || { echo "  [ERROR] Infra state not found: $INFRA_STATE" >&2; exit 1; }

mkdir -p "$PROGRESS_DIR"
cd "$PROGRESS_DIR"

source "$SCAFFOLD_DIR/do/oci_scaffold.sh"

export STATE_FILE="${PWD}/state-${NAME_PREFIX}.json"

ssh_opts=(
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
  -o GlobalKnownHostsFile=/dev/null
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
[ -n "$SUBNET_OCID" ] || { echo "  [ERROR] No subnet OCID in Sprint 1 infra state" >&2; exit 1; }
[ -n "$SECRET_OCID" ] || { echo "  [ERROR] No SSH key secret OCID in Sprint 1 infra state" >&2; exit 1; }
[ -f "$PUBKEY_FILE" ] || { echo "  [ERROR] SSH public key not found: $PUBKEY_FILE" >&2; exit 1; }

TMPKEY=""
PUBLIC_IP=""

_cleanup() {
  [ -n "${TMPKEY:-}" ] && rm -f "$TMPKEY" || true
}
trap _cleanup EXIT

_step() { echo "  [INFO] $*"; }
_ssh() { ssh -i "$TMPKEY" "${ssh_opts[@]}" "opc@${PUBLIC_IP}" "$@"; }

detect_oci_region() {
  if [ -n "${OCI_REGION:-}" ]; then
    export OCI_CLI_REGION="${OCI_CLI_REGION:-$OCI_REGION}"
    return 0
  fi

  local state_region
  state_region="$(jq -r '.inputs.oci_region // empty' "$INFRA_STATE" 2>/dev/null || true)"
  if [ -n "${state_region:-}" ]; then
    export OCI_REGION="$state_region"
    export OCI_CLI_REGION="${OCI_CLI_REGION:-$OCI_REGION}"
    return 0
  fi

  local profile="${OCI_CLI_PROFILE:-DEFAULT}"
  local config="${OCI_CLI_CONFIG_FILE:-$HOME/.oci/config}"
  if [ -f "$config" ]; then
    state_region="$(awk -v profile="$profile" '
      $0 == "[" profile "]" { in_profile=1; next }
      /^\[/ { in_profile=0 }
      in_profile && /^[[:space:]]*region[[:space:]]*=/ {
        sub(/^[^=]*=[[:space:]]*/, "", $0)
        print $0
        exit
      }
    ' "$config")"
    if [ -n "${state_region:-}" ]; then
      export OCI_REGION="$state_region"
      export OCI_CLI_REGION="${OCI_CLI_REGION:-$OCI_REGION}"
      return 0
    fi
  fi

  echo "  [ERROR] Unable to autodiscover OCI_REGION from environment, Sprint 1 state, or OCI CLI config" >&2
  return 1
}

_ssh_retry() {
  local max="${SSH_RETRY_MAX:-10}"
  local sleep_s="${SSH_RETRY_SLEEP_SEC:-5}"
  local attempt=1
  while true; do
    set +e
    _ssh "$@"
    local ec=$?
    set -e
    if [ "$ec" -eq 0 ]; then
      return 0
    fi
    if [ "$ec" -ne 255 ] || [ "$attempt" -ge "$max" ]; then
      return "$ec"
    fi
    _step "SSH transport error. Retrying in ${sleep_s}s (${attempt}/${max})..."
    sleep "$sleep_s"
    sleep_s=$((sleep_s * 2))
    attempt=$((attempt + 1))
  done
}

retry_light() {
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
    _step "Transient failure (exit $ec). Retrying in ${sleep_s}s (${attempt}/${max})..."
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
  local agent_json="$PROGRESS_DIR/agentUpdate-${NAME_PREFIX}.json"
  cat >"$agent_json" <<'JSON'
{
  "areAllPluginsDisabled": false,
  "isManagementDisabled": false,
  "isMonitoringDisabled": false,
  "pluginsConfig": [
    { "name": "Block Volume Management", "desiredState": "ENABLED" }
  ]
}
JSON
  oci compute instance update \
    --instance-id "$instance_id" \
    --agent-config "file://${agent_json}" \
    --force >/dev/null
}

fetch_ssh_key() {
  TMPKEY=$(mktemp)
  chmod 600 "$TMPKEY"
  oci secrets secret-bundle get \
    --secret-id "$SECRET_OCID" \
    --query 'data."secret-bundle-content".content' --raw-output \
    | base64 --decode > "$TMPKEY"
}

guest_wait_for_agent_multipath() {
  local expected_path="$1"
  local timeout="${AGENT_MULTIPATH_WAIT_SEC:-600}"
  _step "Waiting for agent-managed iSCSI sessions, mapper device, and mountable path..."
  _ssh_retry sudo bash -s -- "$expected_path" "$timeout" <<'EOF'
set -euo pipefail
EXPECTED_PATH="$1"
TIMEOUT="$2"
elapsed=0

while true; do
  sessions="$( { iscsiadm -m session 2>/dev/null || true; } | wc -l | tr -d ' ')"
  mpath_ll="$(multipath -ll 2>/dev/null || true)"
  mapper="$(echo "$mpath_ll" | awk '/^mpath/{print "/dev/mapper/" $1; exit}')"
  if [ -n "$mapper" ] && [ -b "$mapper" ] && [ "${sessions:-0}" -ge 2 ] && [ -b "$EXPECTED_PATH" ]; then
    exit 0
  fi

  sleep 10
  elapsed=$((elapsed + 10))
  echo "[WAIT] ${elapsed}s sessions=${sessions:-0} mapper=${mapper:-none} expected_path=$EXPECTED_PATH"
  if [ "$elapsed" -ge "$TIMEOUT" ]; then
    echo "Timed out waiting for agent-managed multipath" >&2
    echo "=== iscsiadm -m session ===" >&2
    iscsiadm -m session >&2 || true
    echo "=== multipath -ll ===" >&2
    multipath -ll >&2 || true
    echo "=== oracle-cloud-agent block plugin log tail ===" >&2
    tail -100 /var/log/oracle-cloud-agent/plugins/oci-blockautoconfig/oci-blockautoconfig.log >&2 || true
    exit 1
  fi
done
EOF
}

guest_mount_agent_device() {
  local expected_path="$1"
  local mountpoint="${SPRINT24_MNT:-/mnt/sprint24-agent}"
  _step "Creating filesystem if needed and mounting agent-managed device at $mountpoint..."
  _ssh_retry sudo bash -s -- "$expected_path" "$mountpoint" <<'EOF'
set -euo pipefail
EXPECTED_PATH="$1"
MOUNTPOINT="$2"

DEV="$(readlink -f "$EXPECTED_PATH")"
[ -b "$DEV" ]

if ! blkid "$DEV" >/dev/null 2>&1; then
  mkfs.xfs -f "$DEV" >/dev/null
fi

mkdir -p "$MOUNTPOINT"
mountpoint -q "$MOUNTPOINT" || mount "$DEV" "$MOUNTPOINT"
mountpoint -q "$MOUNTPOINT"
df -h "$MOUNTPOINT"
EOF
}

guest_collect_evidence() {
  local expected_path="$1"
  local mountpoint="${SPRINT24_MNT:-/mnt/sprint24-agent}"
  local out_file="$2"
  _step "Collecting Sprint 24 evidence: $out_file"
  _ssh_retry sudo bash -s -- "$expected_path" "$mountpoint" <<'EOF' >"$out_file"
set -euo pipefail
EXPECTED_PATH="$1"
MOUNTPOINT="$2"

echo "=== sprint24 evidence timestamp ==="; date -u; echo
echo "=== oracle-cloud-agent package ==="; rpm -qa 'oracle-cloud-agent*' 2>/dev/null || yum info oracle-cloud-agent 2>/dev/null || true; echo
echo "=== oracle-cloud-agent service ==="; systemctl status oracle-cloud-agent --no-pager || true; echo
echo "=== block volume plugin config ==="; grep -A6 -B2 'oci-blockautoconfig' /etc/oracle-cloud-agent/agent.yml || true; echo
echo "=== block volume plugin log tail ==="; tail -200 /var/log/oracle-cloud-agent/plugins/oci-blockautoconfig/oci-blockautoconfig.log || true; echo
echo "=== iscsi sessions ==="; iscsiadm -m session || true; echo
echo "=== iscsi node startup values ==="; find /var/lib/iscsi/nodes -type f -name default -print0 2>/dev/null | xargs -0 grep -H 'node.startup' 2>/dev/null || true; echo
echo "=== multipath -ll ==="; multipath -ll || true; echo
echo "=== multipathd show paths ==="; multipathd show paths || true; echo
echo "=== multipathd show maps ==="; multipathd show maps || true; echo
echo "=== multipathd show config subset ==="; multipathd show config 2>/dev/null | egrep -n 'path_selector|path_grouping_policy|rr_min_io|rr_min_io_rq|rr_weight|prio|failback|no_path_retry|fast_io_fail_tmo|dev_loss_tmo' || true; echo
echo "=== /etc/multipath.conf ==="; test -f /etc/multipath.conf && sed -n '1,220p' /etc/multipath.conf || echo "(missing)"; echo
echo "=== expected path ==="; ls -la "$EXPECTED_PATH" || true; readlink -f "$EXPECTED_PATH" || true; echo
echo "=== lsblk ==="; lsblk -o NAME,TYPE,SIZE,MODEL,WWN,FSTYPE,MOUNTPOINT || true; echo
echo "=== dmsetup tree ==="; dmsetup ls --tree || true; echo
echo "=== mount verification ==="; mountpoint -q "$MOUNTPOINT" && echo "MOUNTED $MOUNTPOINT" || echo "NOT MOUNTED $MOUNTPOINT"; mount | grep -F " $MOUNTPOINT " || true; df -h "$MOUNTPOINT" || true; echo
echo "=== checklist ==="
sessions="$(iscsiadm -m session 2>/dev/null | wc -l | tr -d ' ')"
maps="$(multipath -ll 2>/dev/null | awk '/^mpath/{c++} END{print c+0}')"
paths="$(multipath -ll 2>/dev/null | grep -c ' active ready running' || true)"
echo "sessions=$sessions"
echo "maps=$maps"
echo "active_ready_running_paths=$paths"
if [ "${sessions:-0}" -ge 2 ] && [ "${maps:-0}" -ge 1 ] && [ "${paths:-0}" -ge 2 ] && mountpoint -q "$MOUNTPOINT"; then
  echo "RESULT=PASS"
else
  echo "RESULT=FAIL"
fi
EOF
}

main() {
  echo ""
  echo "=== Sprint 24: OCI agent-managed multipath validation ==="
  echo ""

  local ts diag_out state_out attach_out expected_path
  ts="$(date -u '+%Y%m%d_%H%M%S')"
  diag_out="$PROGRESS_DIR/oci_agent_multipath_evidence_${ts}.txt"
  state_out="$PROGRESS_DIR/state-bv4db-s24-agent_${ts}.json"
  attach_out="$PROGRESS_DIR/volume_attachment_${ts}.json"

  detect_oci_region
  _step "Using OCI region: $OCI_REGION"

  export COMPUTE_SHAPE="${COMPUTE_SHAPE:-VM.Standard.E5.Flex}"
  export COMPUTE_OCPUS="${COMPUTE_OCPUS:-16}"
  export COMPUTE_MEMORY_GB="${COMPUTE_MEMORY_GB:-64}"
  export BLOCKVOLUME_SIZE_GB="${BLOCKVOLUME_SIZE_GB:-1500}"
  export BLOCKVOLUME_VPUS_PER_GB="${BLOCKVOLUME_VPUS_PER_GB:-120}"

  _state_set '.inputs.oci_region' "$OCI_REGION"
  _state_set '.inputs.name_prefix' "$NAME_PREFIX"
  _state_set '.inputs.oci_compartment' "$COMPARTMENT_OCID"
  _state_set '.subnet.ocid' "$SUBNET_OCID"
  _state_set '.inputs.compute_shape' "$COMPUTE_SHAPE"
  _state_set '.inputs.compute_ocpus' "$COMPUTE_OCPUS"
  _state_set '.inputs.compute_memory_gb' "$COMPUTE_MEMORY_GB"
  _state_set '.inputs.subnet_prohibit_public_ip' 'false'
  _state_set '.inputs.compute_ssh_authorized_keys_file' "$PUBKEY_FILE"
  _state_set '.inputs.bv_size_gb' "$BLOCKVOLUME_SIZE_GB"
  _state_set '.inputs.bv_vpus_per_gb' "$BLOCKVOLUME_VPUS_PER_GB"
  _state_set '.inputs.bv_attach_type' 'iscsi'
  _state_set '.inputs.bv_is_multipath' 'true'
  _state_set '.inputs.bv_device_path' '/dev/oracleoci/oraclevdb'

  _step "Provisioning/adopting compute..."
  env NAME_PREFIX="$NAME_PREFIX" ensure-compute.sh

  _step "Enabling OCI Block Volume Management plugin before volume attach..."
  enable_block_volume_plugin "$(_state_get '.compute.ocid')"
  PUBLIC_IP=$(_state_get '.compute.public_ip')
  fetch_ssh_key
  wait_for_ssh

  _step "Provisioning/adopting UHP multipath block volume attachment..."
  retry_light env NAME_PREFIX="$NAME_PREFIX" ensure-blockvolume.sh

  local volume_attach_id
  volume_attach_id=$(_state_get '.blockvolume.attachment_ocid')
  expected_path=$(_state_get '.blockvolume.device_path')
  expected_path="${expected_path:-/dev/oracleoci/oraclevdb}"

  oci compute volume-attachment get --volume-attachment-id "$volume_attach_id" \
    | jq 'del(.data."chap-secret", .data."chap-username")' >"$attach_out"
  if [ "$(jq -r '.data."is-multipath" // empty' "$attach_out")" != "true" ]; then
    echo "  [ERROR] OCI control plane does not report is-multipath=true for $volume_attach_id" >&2
    exit 1
  fi

  guest_wait_for_agent_multipath "$expected_path"
  guest_mount_agent_device "$expected_path"
  guest_collect_evidence "$expected_path" "$diag_out"
  grep -q 'RESULT=PASS' "$diag_out"

  cp -f "$STATE_FILE" "$state_out"
  ln -sf "$(basename "$state_out")" "$PROGRESS_DIR/state-bv4db-s24-agent-latest.json"
  ln -sf "$(basename "$diag_out")" "$PROGRESS_DIR/oci_agent_multipath_evidence_latest.txt"
  ln -sf "$(basename "$attach_out")" "$PROGRESS_DIR/volume_attachment_latest.json"

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

  echo "  [DONE] Evidence: $diag_out"
  echo "  [DONE] Attachment JSON: $attach_out"
}

main "$@"
