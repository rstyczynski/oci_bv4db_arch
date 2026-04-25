#!/usr/bin/env bash
# Sprint 20 (BV4DB-51): A/B load test with multipath vs single-path (fio preferred, dd fallback).

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
  echo "  [FAIL] run_bv4db_fio_multipath_ab_sprint20.sh failed (exit $ec) at line $line: $cmd" >&2
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

ssh_opts=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o GlobalKnownHostsFile=/dev/null -o ConnectTimeout=15 -o BatchMode=yes)
scp_opts=(-B -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o GlobalKnownHostsFile=/dev/null -o ConnectTimeout=15 -o BatchMode=yes)

COMPARTMENT_OCID=$(jq -r '.compartment.ocid' "$INFRA_STATE")
SUBNET_OCID=$(jq -r '.subnet.ocid' "$INFRA_STATE")
SECRET_OCID=$(jq -r '.secret.ocid' "$INFRA_STATE")
PUBKEY_FILE="$SPRINT1_DIR/bv4db-key.pub"

TMPKEY=""
PUBLIC_IP=""

_cleanup() {
  [ -n "${TMPKEY:-}" ] && rm -f "$TMPKEY" || true
}
trap _cleanup EXIT

_ssh() {
  local had_errexit=0
  [[ "$-" == *e* ]] && had_errexit=1
  set +e
  ssh -i "$TMPKEY" "${ssh_opts[@]}" "opc@${PUBLIC_IP}" "$@"
  local ec=$?
  if [ "$had_errexit" -eq 1 ]; then
    set -e
  else
    set +e
  fi
  if [ "$ec" -ne 0 ]; then
    echo "  [ERROR] ssh failed (exit $ec): $*" >&2
  fi
  return "$ec"
}
_scp() { scp -i "$TMPKEY" "${scp_opts[@]}" "opc@${PUBLIC_IP}:$1" "$2"; }
_scp_to() { scp -i "$TMPKEY" "${scp_opts[@]}" "$1" "opc@${PUBLIC_IP}:$2"; }

_step() { echo "  [INFO] $*"; }

GUEST_LOAD_LOCAL="$REPO_DIR/tools/guest/bv4db_sprint20_load.sh"
GUEST_LOAD_REMOTE="/tmp/bv4db_sprint20_load.sh"

ensure_guest_load_script() {
  [ -f "$GUEST_LOAD_LOCAL" ] || { echo "  [ERROR] Missing guest load script: $GUEST_LOAD_LOCAL" >&2; exit 1; }
  # Always copy to keep the guest script in sync with local repo version.
  _step "Copying guest load script to instance..."
  _scp_to "$GUEST_LOAD_LOCAL" "$GUEST_LOAD_REMOTE"
  _ssh sudo chmod 0755 "$GUEST_LOAD_REMOTE" >/dev/null
}

ensure_guest_fstab_script() {
  # Optional: copy a sprint-specific fstab helper script to the guest for operators.
  # Sprint 22 manual expects /tmp/bv4db_sprint22_fstab.sh, Sprint 23 expects /tmp/bv4db_sprint23_fstab.sh.
  if [ "${USE_FSTAB:-false}" != "true" ]; then
    return 0
  fi
  if [ -z "${GUEST_FSTAB_LOCAL:-}" ] || [ -z "${GUEST_FSTAB_REMOTE:-}" ]; then
    return 0
  fi
  [ -f "$GUEST_FSTAB_LOCAL" ] || { echo "  [ERROR] Missing guest fstab script: $GUEST_FSTAB_LOCAL" >&2; exit 1; }
  _step "Copying guest fstab helper to instance..."
  _scp_to "$GUEST_FSTAB_LOCAL" "$GUEST_FSTAB_REMOTE"
  _ssh sudo chmod 0755 "$GUEST_FSTAB_REMOTE" >/dev/null
}

guest_run_load() {
  local mode="$1"     # auto|fio|dd
  local mnt="$2"
  local out_json="$3"
  local out_txt="${4:-}"

  local fio_profile="${FIO_PROFILE:-randrw_4k}"         # randrw_4k|read_1m_bw
  local fio_runtime_sec="${FIO_RUNTIME_SEC:-120}"
  local fio_size_gb="${FIO_SIZE_GB:-16}"
  local fio_numjobs="${FIO_NUMJOBS:-4}"
  local fio_iodepth="${FIO_IODEPTH:-32}"

  ensure_guest_load_script
  ensure_guest_fstab_script
  if [ -n "${out_txt:-}" ]; then
    _ssh sudo "$GUEST_LOAD_REMOTE" \
      --mode "$mode" \
      --mnt "$mnt" \
      --out-json "$out_json" \
      --out-txt "$out_txt" \
      --fio-profile "$fio_profile" \
      --fio-runtime-sec "$fio_runtime_sec" \
      --fio-size-gb "$fio_size_gb" \
      --fio-numjobs "$fio_numjobs" \
      --fio-iodepth "$fio_iodepth"
  else
    _ssh sudo "$GUEST_LOAD_REMOTE" \
      --mode "$mode" \
      --mnt "$mnt" \
      --out-json "$out_json" \
      --fio-profile "$fio_profile" \
      --fio-runtime-sec "$fio_runtime_sec" \
      --fio-size-gb "$fio_size_gb" \
      --fio-numjobs "$fio_numjobs" \
      --fio-iodepth "$fio_iodepth"
  fi
}

ensure_guest_fio() {
  # Installs fio on the guest if missing (best effort).
  # Can be disabled with INSTALL_FIO=false.
  if [ "${INSTALL_FIO:-true}" != "true" ]; then
    return 0
  fi
  _ssh sudo bash -s -- <<'EOF'
set -euo pipefail
if command -v fio >/dev/null 2>&1; then
  exit 0
fi
if command -v dnf >/dev/null 2>&1; then
  dnf -y install fio >/dev/null
elif command -v yum >/dev/null 2>&1; then
  yum -y install fio >/dev/null
else
  echo "No dnf/yum found to install fio" >&2
  exit 1
fi
command -v fio >/dev/null 2>&1
EOF
}

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

guest_login_targets() {
  local mode="$2"   # multipath|single
  local iqn="$3"
  local port="$4"
  local expected_path="$5"
  shift 5
  local -a targets=("$@")

  _ssh sudo bash -s -- "$mode" "$iqn" "$port" "$expected_path" "${targets[@]}" <<'EOF'
set -euo pipefail
MODE="$1"
IQN="$2"
PORT="$3"
DEVICE_PATH="$4"
shift 4
TARGETS=("$@")

discover_portals() {
  # Use iSCSI SendTargets discovery from the first known portal to learn all portals for the IQN.
  # NOTE: Only use discovery to AUGMENT the OCI-provided targets, not replace them.
  # OCI control-plane targets are authoritative when available.
  local seed="${TARGETS[0]:-}"
  [ -n "${seed:-}" ] || return 0

  # If OCI already provided multiple targets, trust them and skip discovery
  if [ "${#TARGETS[@]}" -ge 2 ]; then
    return 0
  fi

  # Example output:
  #   169.254.2.6:3260,1 iqn....
  mapfile -t found < <(iscsiadm -m discovery -t st -p "${seed}:${PORT}" 2>/dev/null \
    | awk -v iqn="$IQN" '$0 ~ iqn {print $1}' \
    | cut -d',' -f1 \
    | cut -d':' -f1 \
    | sort -u)
  if [ "${#found[@]}" -ge 1 ]; then
    TARGETS=("${found[@]}")
  fi
}

if [ "$MODE" = "multipath" ]; then
  # Start from a clean iSCSI+multipath state; otherwise we may end up mounted on a raw sdX
  # and multipath will never create the /dev/mapper map.
  iscsiadm -m node -T "$IQN" --logout >/dev/null 2>&1 || true
  iscsiadm -m node -o delete -T "$IQN" >/dev/null 2>&1 || true
  multipath -F >/dev/null 2>&1 || true
fi

systemctl enable --now iscsid >/dev/null
systemctl is-enabled iscsid >/dev/null
systemctl is-active iscsid >/dev/null

if [ "$MODE" = "multipath" ]; then
  mpathconf --enable --with_multipathd y >/dev/null
  modprobe dm_multipath >/dev/null 2>&1 || modprobe dm-multipath >/dev/null 2>&1 || true
  systemctl enable --now multipathd >/dev/null
  systemctl restart multipathd >/dev/null 2>&1 || true
  systemctl is-enabled multipathd >/dev/null
  systemctl is-active multipathd >/dev/null
else
  systemctl disable --now multipathd >/dev/null 2>&1 || true
fi

discover_portals

if [ "$MODE" = "single" ]; then
  # "Single-path" must ensure we only have ONE active iSCSI session for this IQN.
  # Previous multipath runs may have left multiple sessions logged in.
  # Best-effort: logout and delete all existing nodes for IQN before logging in one target.
  iscsiadm -m node -T "$IQN" --logout >/dev/null 2>&1 || true
  iscsiadm -m node -o delete -T "$IQN" >/dev/null 2>&1 || true
  iscsiadm -m session 2>/dev/null | grep -F " $IQN " >/dev/null 2>&1 && {
    # Some stacks keep stale sessions; try a broader logout sweep.
    iscsiadm -m node --logout >/dev/null 2>&1 || true
  }
  # Flush any existing multipath maps now that we are unmounted.
  multipath -F >/dev/null 2>&1 || true
  TARGETS=("${TARGETS[0]}")
fi

for host in "${TARGETS[@]}"; do
  iscsiadm -m node -o new -T "$IQN" -p "${host}:${PORT}" >/dev/null 2>&1 || true
  iscsiadm -m node -T "$IQN" -p "${host}:${PORT}" --op update -n node.startup -v automatic >/dev/null
  iscsiadm -m node -T "$IQN" -p "${host}:${PORT}" --login >/dev/null 2>&1 || true
done

udevadm settle

if [ "$MODE" = "multipath" ]; then
  # Force (re)creation of the multipath map after logins (can be slow after previous cleanup).
  multipath -r >/dev/null 2>&1 || true
  multipath >/dev/null 2>&1 || true
fi

if [ "$MODE" = "single" ]; then
  sess_count="$(iscsiadm -m session 2>/dev/null | grep -F " $IQN " | wc -l | tr -d ' ')"
  [ "${sess_count:-0}" -eq 1 ] || { echo "Expected exactly 1 iSCSI session for single-path, got: ${sess_count:-0}" >&2; iscsiadm -m session || true; exit 1; }

  # OCI iSCSI LUN number can vary. If the caller passed a by-path that doesn't exist,
  # auto-discover the actual device under /dev/disk/by-path for the logged-in target.
  if [ ! -b "$DEVICE_PATH" ]; then
    cand="$(ls -1 "/dev/disk/by-path/ip-${TARGETS[0]}:${PORT}-iscsi-${IQN}-lun-"* 2>/dev/null | head -n 1 || true)"
    if [ -n "${cand:-}" ]; then
      DEVICE_PATH="$cand"
    fi
  fi
fi

for _ in $(seq 1 24); do
  # In multipath mode, PREFER the mapper device over the raw oraclevdb symlink.
  # The oraclevdb symlink points to one of the path devices (e.g., sdb) which is
  # busy being used by device-mapper and cannot be formatted directly.
  if [ "$MODE" = "multipath" ]; then
    # Map name can be either "mpathX" (user_friendly_names=yes) or the WWID (when user_friendly_names=no).
    map_name="$(multipath -ll 2>/dev/null | awk 'NF{print $1; exit}' || true)"
    if [ -n "${map_name:-}" ] && [ -b "/dev/mapper/${map_name}" ]; then
      echo "/dev/mapper/${map_name}"
      exit 0
    fi
  fi

  # For single-path mode (or if multipath map isn't ready yet), use the expected device path
  if [ -b "$DEVICE_PATH" ]; then
    # In multipath mode, don't use oraclevdb - it's a member device
    if [ "$MODE" = "multipath" ] && [ "$DEVICE_PATH" = "/dev/oracleoci/oraclevdb" ]; then
      : # skip, wait for mapper device
    else
      echo "$DEVICE_PATH"
      exit 0
    fi
  fi
  sleep 5
done

echo "Expected device path not present after iSCSI login: $DEVICE_PATH" >&2
iscsiadm -m session >&2 || true
multipath -ll >&2 || true
ls -la /dev/mapper >&2 || true
ls -la /dev/oracleoci >&2 || true
exit 1
EOF
}

guest_verify_multipath() {
  local expected_path="$1"
  _step "Verifying guest multipath services + device..."
  set +e
  trap - ERR
  set +E
  _ssh sudo bash -s -- "$expected_path" <<'EOF'
set -u
EXPECTED_PATH="${1:-}"
fail=0

check() {
  local label="$1"; shift
  if "$@"; then
    return 0
  fi
  echo "[VERIFY][FAIL] $label" >&2
  fail=1
  return 0
}

check "iscsid enabled" systemctl is-enabled iscsid >/dev/null 2>&1
check "iscsid active" systemctl is-active iscsid >/dev/null 2>&1
check "multipathd enabled" systemctl is-enabled multipathd >/dev/null 2>&1
check "multipathd active" systemctl is-active multipathd >/dev/null 2>&1

multipath -ll >/tmp/multipath_ll.txt 2>/dev/null || true
map_name="$(awk 'NF{print $1; exit}' /tmp/multipath_ll.txt 2>/dev/null || true)"
check "multipath map present" test -n "${map_name:-}"

# If caller provided a non-existent expected path (e.g. /dev/mapper/mpatha with user_friendly_names=no),
# fall back to the actual map name from multipath output.
if [ -n "${map_name:-}" ] && [ ! -b "${EXPECTED_PATH:-}" ] && [ -b "/dev/mapper/${map_name}" ]; then
  EXPECTED_PATH="/dev/mapper/${map_name}"
fi
check "expected device path exists" test -b "$EXPECTED_PATH"

path_count="$(grep -E ' active ready running' /tmp/multipath_ll.txt | wc -l | tr -d ' ')"
if [ "${path_count:-0}" -lt 2 ]; then
  echo "[VERIFY][FAIL] expected >=2 active paths, got ${path_count:-0}" >&2
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  echo "=== systemctl iscsid ===" >&2; systemctl status iscsid --no-pager >&2 || true
  echo "=== systemctl multipathd ===" >&2; systemctl status multipathd --no-pager >&2 || true
  echo "=== multipath -ll ===" >&2; cat /tmp/multipath_ll.txt >&2 || true
  echo "=== expected path ===" >&2; ls -la "$EXPECTED_PATH" >&2 || true
  exit 1
fi
EOF
  ec=$?
  set -E
  trap _on_err ERR
  set -e

  if [ "$ec" -eq 0 ]; then
    return 0
  fi

  echo "  [ERROR] guest_verify_multipath failed (exit $ec); collecting diagnostics..." >&2
  set +e
  trap - ERR
  set +E
  _ssh sudo bash -s -- "$expected_path" <<'EOF' >&2 || true
set -u
EXPECTED_PATH="${1:-}"
echo "expected_path=$EXPECTED_PATH"
echo "=== systemctl iscsid ==="; systemctl status iscsid --no-pager || true; echo
echo "=== systemctl multipathd ==="; systemctl status multipathd --no-pager || true; echo
echo "=== multipath -ll ==="; multipath -ll || true; echo
echo "=== /dev/oracleoci ==="; ls -la /dev/oracleoci || true; echo
echo "=== expected path ==="; ls -la "$EXPECTED_PATH" || true; echo
EOF
  set -E
  trap _on_err ERR
  set -e
  return 1
}

guest_prepare_fs() {
  local dev="$2"
  local mnt="$3"
  _ssh sudo bash -s -- "$dev" "$mnt" <<'EOF'
set -euo pipefail
DEV="$1"
MNT="$2"
mkdir -p "$MNT" >/dev/null 2>&1 || true
# If the mountpoint directory is in a bad state (I/O error), recover by unmounting and recreating.
if ! ls -ld "$MNT" >/dev/null 2>&1; then
  # Try to unmount by mountpoint and by device (mountpoint checks can fail when FS is in I/O error state).
  umount -l "$MNT" >/dev/null 2>&1 || umount "$MNT" >/dev/null 2>&1 || true
  grep -F " $MNT " /proc/mounts >/dev/null 2>&1 && umount -l "$MNT" >/dev/null 2>&1 || true
  grep -F "$DEV $MNT " /proc/mounts >/dev/null 2>&1 && umount -l "$DEV" >/dev/null 2>&1 || umount "$DEV" >/dev/null 2>&1 || true
  # If the filesystem got into I/O error state (common after changing paths while mounted),
  # attempt an XFS repair before recreating and remounting.
  if grep -F " $MNT " /proc/mounts >/dev/null 2>&1; then
    echo "Mountpoint still mounted and inaccessible: $MNT" >&2
    mount | grep -F " $MNT " >&2 || true
    exit 1
  fi
  if command -v xfs_repair >/dev/null 2>&1; then
    xfs_repair -L "$DEV" >/dev/null 2>&1 || true
  fi
  rm -rf "$MNT" >/dev/null 2>&1 || true
  mkdir -p "$MNT" >/dev/null 2>&1 || true
  if ! test -d "$MNT"; then
    echo "Failed to (re)create mountpoint directory: $MNT" >&2
    ls -la /mnt >&2 || true
    ls -la "$MNT" >&2 || true
    exit 1
  fi
fi
if ! blkid "$DEV" >/dev/null 2>&1; then
  mkfs.xfs -f "$DEV" >/dev/null
fi
if ! mountpoint -q "$MNT" 2>/dev/null; then
  mount "$DEV" "$MNT" >/dev/null 2>&1 || {
    echo "Failed to mount $DEV on $MNT" >&2
    mount | grep -F " $MNT " >&2 || true
    lsblk -o NAME,TYPE,SIZE,MODEL,WWN,MOUNTPOINT >&2 || true
    exit 1
  }
fi
findmnt -n -o SOURCE,FSTYPE,TARGET --target "$MNT" >&2 || true
chmod 777 "$MNT"
EOF
}

guest_assert_mounted_block_device() {
  local label="$2"
  local mnt="$3"
  local mode="$4"          # multipath|single
  _step "Asserting mountpoint device ($label)..."
  _ssh sudo bash -s -- "$label" "$mnt" "$mode" <<'EOF'
set -euo pipefail
LABEL="$1"
MNT="$2"
MODE="$3"

if ! mountpoint -q "$MNT"; then
  echo "[ERROR] $LABEL: mountpoint is not mounted: $MNT" >&2
  mount | grep -F " $MNT " >&2 || true
  exit 1
fi

src="$(findmnt -n -o SOURCE --target "$MNT" 2>/dev/null || true)"
fst="$(findmnt -n -o FSTYPE --target "$MNT" 2>/dev/null || true)"
echo "[INFO] $LABEL: mounted source=$src fstype=$fst" >&2

if [ "$MODE" = "multipath" ]; then
  # Must be a mapper multipath device, not the boot/root disk.
  echo "$src" | grep -Eq '^/dev/mapper/|^/dev/dm-' || {
    echo "[ERROR] $LABEL: expected multipath mapper device mounted on $MNT, got: $src" >&2
    lsblk -o NAME,TYPE,SIZE,MODEL,WWN,MOUNTPOINT >&2 || true
    exit 1
  }
else
  # Single-path should NOT be a mapper multipath device.
  echo "$src" | grep -Eq '^/dev/mapper/|^/dev/dm-' && {
    echo "[ERROR] $LABEL: expected single-path raw device mounted on $MNT, got mapper: $src" >&2
    lsblk -o NAME,TYPE,SIZE,MODEL,WWN,MOUNTPOINT >&2 || true
    exit 1
  }
fi
exit 0
EOF
}

guest_unmount_fs() {
  local mnt="$2"
  _ssh sudo bash -s -- "$mnt" <<'EOF'
set -euo pipefail
MNT="$1"
if ! mountpoint -q "$MNT" 2>/dev/null; then
  exit 0
fi

set +e
umount "$MNT" >/dev/null 2>&1
ec=$?
if [ "$ec" -ne 0 ]; then
  # Best-effort: kill processes using the mountpoint, then retry.
  if command -v fuser >/dev/null 2>&1; then
    fuser -km "$MNT" >/dev/null 2>&1
    sleep 2
  fi
  umount "$MNT" >/dev/null 2>&1
  ec=$?
fi

if [ "$ec" -ne 0 ]; then
  # Last resort: lazy unmount so we can proceed with iSCSI/multipath reconfiguration.
  umount -l "$MNT" >/dev/null 2>&1
fi
set -e
EOF
}

guest_collect_diag() {
  local out_file="$2"
  _step "Collecting guest diagnostics..."
  set +e
  _ssh sudo bash -s -- <<'EOF' >"$out_file"
set -u
echo "=== date ==="; date -u; echo
echo "=== /etc/fstab (sprint + mount entries) ==="; grep -nE '(bv4db-sprint|/mnt/sprint)' /etc/fstab || true; echo
echo "=== iscsiadm -m session ==="; iscsiadm -m session || true; echo
echo "=== systemctl status multipathd ==="; systemctl status multipathd --no-pager || true; echo
echo "=== multipath -ll ==="; multipath -ll || true; echo
echo "=== multipathd show paths ==="; multipathd show paths || true; echo
echo "=== multipathd show maps ==="; multipathd show maps || true; echo
echo "=== lsblk ==="; lsblk -o NAME,TYPE,SIZE,MODEL,WWN,MOUNTPOINT || true; echo
EOF
  ec=$?
  set -e
  if [ "$ec" -ne 0 ]; then
    echo "  [WARN] Failed to collect diagnostics (ssh exit $ec); continuing." >&2
  fi
}

guest_collect_config() {
  local label="$2"
  local mnt="$3"
  local out_file="$4"
  _step "Collecting guest config snapshot ($label)..."
  set +e
  _ssh sudo bash -s -- "$label" "$mnt" <<'EOF' >"$out_file"
set -u
LABEL="${1:-}"
MNT="${2:-}"
echo "=== label ==="; echo "$LABEL"; echo
echo "=== date ==="; date -u; echo
echo "=== findmnt (mountpoint) ==="; findmnt -n -o SOURCE,FSTYPE,TARGET --target "$MNT" 2>/dev/null || true; echo
echo "=== mount | grep mountpoint ==="; mount | grep -F " $MNT " || true; echo
echo "=== /etc/fstab (mountpoint + tags) ==="; grep -nE "($MNT|bv4db-sprint)" /etc/fstab || true; echo
echo "=== /etc/multipath.conf ==="; test -f /etc/multipath.conf && sed -n '1,200p' /etc/multipath.conf || echo "(missing)"; echo
echo "=== multipath effective config (multipath -t) ==="; multipath -t 2>/dev/null || true; echo
echo "=== ORACLE BlockVolume section (from multipath -t) ==="; multipath -t 2>/dev/null | sed -n '/device {/,/}/p' | grep -A20 -B5 -E 'ORACLE|BlockVolume' || true; echo
echo "=== dmsetup status (mpatha) ==="; dmsetup status mpatha 2>/dev/null || dmsetup status 2>/dev/null | head -n 50 || true; echo
echo "=== multipathd show config (subset) ==="; multipathd show config 2>/dev/null | egrep -n 'path_selector|path_grouping_policy|rr_min_io|rr_min_io_rq|rr_weight|prio|failback|no_path_retry|fast_io_fail_tmo|dev_loss_tmo' || true; echo
echo "=== iscsiadm -m session ==="; iscsiadm -m session || true; echo
echo "=== multipath -ll ==="; multipath -ll || true; echo
echo "=== ls -la /dev/oracleoci ==="; ls -la /dev/oracleoci || true; echo
echo "=== ls -la /dev/mapper ==="; ls -la /dev/mapper || true; echo
echo "=== lsblk ==="; lsblk -o NAME,TYPE,SIZE,MODEL,WWN,MOUNTPOINT || true; echo
EOF
  ec=$?
  set -e
  if [ "$ec" -ne 0 ]; then
    echo "  [WARN] Failed to collect config snapshot (ssh exit $ec); continuing." >&2
  fi
}

guest_capture_iostat_during_fio() {
  local label="$2"        # multipath|singlepath
  local mnt="$3"
  local out_remote="$4"
  local fio_mode="$5"     # fio|dd|auto
  local mapper_name="${6:-mpatha}"  # only relevant for multipath
  local duration_sec="${7:-0}"

  if [ "${IOSTAT_ENABLE:-true}" != "true" ]; then
    return 0
  fi
  if [ "$fio_mode" != "fio" ]; then
    return 0
  fi

  _step "Capturing iostat during fio ($label)..."
  set +e
  _ssh sudo bash -s -- "$label" "$mnt" "$out_remote" "$mapper_name" "$duration_sec" <<'EOF'
set -euo pipefail
LABEL="$1"
MNT="$2"
OUT="$3"
MPATH="$4"
DUR_SEC="${5:-0}"

dm=""
if [ -e "/dev/mapper/${MPATH}" ]; then
  dm="$(readlink -f "/dev/mapper/${MPATH}" 2>/dev/null | xargs -I{} basename {} || true)"
fi

paths=()
if command -v multipath >/dev/null 2>&1; then
  mapfile -t paths < <(multipath -ll "$MPATH" 2>/dev/null | awk '/active ready running/ {print $4}' | sort -u)
fi

devs=()
[ -n "${dm:-}" ] && devs+=("$dm")
if [ "${#paths[@]}" -gt 0 ]; then
  devs+=("${paths[@]}")
fi

{
  echo "=== label ==="
  echo "$LABEL"
  echo
  echo "=== date ==="
  date -u
  echo
  echo "=== devices ==="
  printf '%s\n' "${devs[@]:-}" || true
  echo
  echo "=== iostat -x 1 (captured) ==="
} >"$OUT"

if command -v iostat >/dev/null 2>&1 && [ "${#devs[@]}" -gt 0 ]; then
  # Capture for a bounded duration so iostat cannot run forever if fio hangs.
  # Default: 0 → 900s.
  if [ "${DUR_SEC:-0}" -le 0 ] 2>/dev/null; then
    DUR_SEC=900
  fi
  # Add a small buffer on top of duration for safe tail capture.
  DUR_SEC=$((DUR_SEC + 30))

  # Run iostat in the background so this SSH session returns immediately and fio can start.
  if command -v timeout >/dev/null 2>&1; then
    timeout "${DUR_SEC}s" iostat -x 1 "${devs[@]}" >>"$OUT" 2>&1 &
    echo $! >"${OUT}.pid"
  else
    iostat -x 1 "${devs[@]}" >>"$OUT" 2>&1 &
    echo $! >"${OUT}.pid"
  fi
else
  echo "(iostat not available or no devices detected)" >>"$OUT"
fi
EOF
  set -e
}

guest_stop_iostat_capture() {
  local out_remote="$2"
  set +e
  _ssh sudo bash -s -- "$out_remote" <<'EOF' >/dev/null
set -euo pipefail
OUT="$1"
pid_file="${OUT}.pid"
if [ -f "$pid_file" ]; then
  pid="$(cat "$pid_file" 2>/dev/null || true)"
  if [ -n "${pid:-}" ]; then
    kill "$pid" >/dev/null 2>&1 || true
  fi
  rm -f "$pid_file" || true
fi
EOF
  set -e
}

guest_configure_multipath_round_robin() {
  # Sprint 23: force an explicit rr policy via /etc/multipath.conf.
  # This is best-effort and only applies when MULTIPATH_LB_ENABLE=true.
  if [ "${MULTIPATH_LB_ENABLE:-false}" != "true" ]; then
    return 0
  fi
  _step "Configuring dm-multipath load balancing (round-robin)..."
  set +e
  _ssh sudo bash -s -- <<'EOF' >/dev/null
set -euo pipefail

ts="$(date -u '+%Y%m%d_%H%M%S')"
if [ -f /etc/multipath.conf ]; then
  cp -f /etc/multipath.conf "/etc/multipath.conf.bv4db.bak.${ts}"
fi

cat >/etc/multipath.conf <<'CONF'
defaults {
    user_friendly_names no
    find_multipaths yes
}

blacklist_exceptions {
    property "(SCSI_IDENT_|ID_WWN)"
}

blacklist {
}

devices {
    device {
        vendor "ORACLE"
        product "BlockVolume"

        path_grouping_policy multibus
        path_selector "round-robin 0"
        rr_weight uniform
        rr_min_io 1
        rr_min_io_rq 1

        path_checker tur
        failback immediate
        no_path_retry queue

        fast_io_fail_tmo 5
        dev_loss_tmo infinity
    }
}
CONF

systemctl enable --now multipathd >/dev/null 2>&1 || true
systemctl restart multipathd >/dev/null 2>&1 || true
multipathd reconfigure >/dev/null 2>&1 || true
multipath -r >/dev/null 2>&1 || true
EOF
  ec=$?
  set -e
  if [ "$ec" -ne 0 ]; then
    echo "  [WARN] Failed to configure round-robin multipath (ssh exit $ec); continuing." >&2
  fi
}

guest_run_fio() {
  local mnt="$2"
  local out_json="$3"
  local out_txt="${4:-}"
  guest_run_load "fio" "$mnt" "$out_json" "$out_txt"
}

guest_run_dd_fallback() {
  local mnt="$2"
  local out_json="$3"
  local out_txt="$4"
  guest_run_load "dd" "$mnt" "$out_json" "$out_txt"
}

guest_assert_remote_file() {
  local path="$1"
  local label="$2"
  if ! _ssh sudo test -s "$path"; then
    echo "  [ERROR] Expected remote artifact missing: $label ($path)" >&2
    _ssh sudo ls -l "$path" 2>/dev/null || true
    _ssh sudo bash -lc "ls -la /tmp | tail -n 50" 2>/dev/null || true
    return 1
  fi
}

extract_total_bw_mbps() {
  python3 - <<'PY' "$1"
import json, sys
p=sys.argv[1]
d=json.load(open(p,"r"))
if d.get("generator") == "dd":
  print(f"{float(d.get('total_mbps',0.0)):.2f}")
  raise SystemExit(0)
jobs=d.get("jobs") or []
rbw=sum(j.get("read",{}).get("bw",0) for j in jobs)   # KiB/s
wbw=sum(j.get("write",{}).get("bw",0) for j in jobs)
print(f"{(rbw+wbw)/1024:.2f}")
PY
}

extract_test_window() {
  # Prints: "<start_iso> <end_iso>" if present, otherwise nothing.
  python3 - <<'PY' "$1"
import json, sys
p=sys.argv[1]
d=json.load(open(p,"r"))
meta=d.get("bv4db") or {}
start=meta.get("start_time_utc") or ""
end=meta.get("end_time_utc") or ""
if start and end:
  print(start, end)
PY
}

generate_oci_metrics_report() {
  local label="$1"          # multipath|singlepath
  local result_json="$2"    # local file path
  if [ "${METRICS_ENABLE:-false}" != "true" ]; then
    return 0
  fi
  if [ ! -f "$result_json" ]; then
    echo "  [WARN] Metrics skipped ($label): result JSON missing: $result_json" >&2
    return 0
  fi

  local window
  window="$(extract_test_window "$result_json" || true)"
  if [ -z "${window:-}" ]; then
    echo "  [WARN] Metrics skipped ($label): no bv4db.start_time_utc/end_time_utc in $result_json" >&2
    return 0
  fi
  local start_time end_time
  start_time="$(echo "$window" | awk '{print $1}')"
  end_time="$(echo "$window" | awk '{print $2}')"

  # Metrics ingestion can lag. Pad the query window to improve report density.
  local pad_before="${METRICS_PAD_BEFORE_SEC:-120}"
  local pad_after="${METRICS_PAD_AFTER_SEC:-300}"
  local delay_sec="${METRICS_DELAY_SEC:-180}"

  if [ "$delay_sec" -gt 0 ] 2>/dev/null; then
    _step "Waiting ${delay_sec}s for OCI Monitoring ingestion ($label)..."
    sleep "$delay_sec"
  fi

  read -r start_time end_time < <(python3 - <<'PY' "$start_time" "$end_time" "$pad_before" "$pad_after"
import sys
from datetime import datetime, timedelta, timezone

start_s, end_s, before_s, after_s = sys.argv[1:5]
before = int(before_s)
after = int(after_s)

def parse_iso(s: str) -> datetime:
    # Handles both ...Z and ...+00:00
    s = s.strip()
    if s.endswith("Z"):
        return datetime.fromisoformat(s.replace("Z", "+00:00"))
    return datetime.fromisoformat(s)

start = parse_iso(start_s).astimezone(timezone.utc) - timedelta(seconds=before)
end = parse_iso(end_s).astimezone(timezone.utc) + timedelta(seconds=after)
print(start.strftime("%Y-%m-%dT%H:%M:%SZ"), end.strftime("%Y-%m-%dT%H:%M:%SZ"))
PY
)

  local ts; ts="$(date -u '+%Y%m%d_%H%M%S')"
  local def_file="${METRICS_DEF_FILE:-$PROGRESS_DIR/metrics-definition.json}"
  local report_md="$PROGRESS_DIR/oci-metrics-${label}_${ts}.md"
  local report_html="$PROGRESS_DIR/oci-metrics-${label}_${ts}.html"
  local raw_json="$PROGRESS_DIR/oci-metrics-${label}_${ts}.raw.json"

  if [ ! -f "$def_file" ]; then
    echo "  [WARN] Metrics skipped ($label): METRICS_DEF_FILE not found: $def_file" >&2
    return 0
  fi

  _step "Generating OCI metrics report ($label) for window $start_time → $end_time ..."
  METRICS_DEF_FILE="$def_file" \
  REPORT_FILE="$report_md" \
  HTML_REPORT_FILE="$report_html" \
  RAW_FILE="$raw_json" \
  METRICS_START_TIME="$start_time" \
  METRICS_END_TIME="$end_time" \
  METRICS_RESOLUTION="${METRICS_RESOLUTION:-1m}" \
    "$REPO_DIR/oci_scaffold/resource/operate-metrics.sh" >/dev/null

  echo "  [INFO] Metrics report ($label): $report_md"
}

main() {
  echo ""
  echo "=== Sprint 20: A/B multipath vs single-path ==="
  echo ""

  local ts; ts="$(date -u '+%Y%m%d_%H%M%S')"
  local state_json="$PROGRESS_DIR/state-bv4db-s20-mpath-ab_${ts}.json"
  local diag_mpath="$PROGRESS_DIR/diag_multipath_${ts}.txt"
  local diag_single="$PROGRESS_DIR/diag_singlepath_${ts}.txt"
  local cfg_mpath_pre="$PROGRESS_DIR/cfg_multipath_pre_${ts}.txt"
  local cfg_mpath_post="$PROGRESS_DIR/cfg_multipath_post_${ts}.txt"
  local cfg_single_pre="$PROGRESS_DIR/cfg_singlepath_pre_${ts}.txt"
  local cfg_single_post="$PROGRESS_DIR/cfg_singlepath_post_${ts}.txt"
  local result_mpath="$PROGRESS_DIR/fio_multipath_${ts}.json"
  local result_single="$PROGRESS_DIR/fio_singlepath_${ts}.json"
  local dd_mpath_txt="$PROGRESS_DIR/dd_multipath_${ts}.txt"
  local dd_single_txt="$PROGRESS_DIR/dd_singlepath_${ts}.txt"
  local iostat_mpath_txt="$PROGRESS_DIR/iostat_multipath_${ts}.txt"
  local iostat_single_txt="$PROGRESS_DIR/iostat_singlepath_${ts}.txt"
  local summary_md="$PROGRESS_DIR/fio_compare_${ts}.md"

  export COMPUTE_SHAPE="${COMPUTE_SHAPE:-VM.Standard.E5.Flex}"
  export COMPUTE_OCPUS="${COMPUTE_OCPUS:-16}"
  export COMPUTE_MEMORY_GB="${COMPUTE_MEMORY_GB:-64}"
  export BLOCKVOLUME_SIZE_GB="${BLOCKVOLUME_SIZE_GB:-1500}"
  export BLOCKVOLUME_VPUS_PER_GB="${BLOCKVOLUME_VPUS_PER_GB:-120}"
  export ATTACHMENT_TYPE="${ATTACHMENT_TYPE:-iscsi}"

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
  if [ "${is_multipath:-}" != "true" ]; then
    echo "  [WARN] Attachment multipath fields are not 'true' yet (is-multipath=${is_multipath:-empty}). Proceeding; ensure-blockvolume will retry/detach if needed." >&2
  fi
  iqn=$(echo "$attachment_json" | jq -r '.data.iqn')
  port=$(echo "$attachment_json" | jq -r '.data.port')
  mapfile -t target_ips < <(echo "$attachment_json" | jq -r '([.data.ipv4] + [.data."multipath-devices"[]?.ipv4]) | unique[]')

  local mnt="${SPRINT_MNT:-/mnt/sprint20}"
  local generator="${LOAD_GENERATOR:-auto}"  # auto|fio|dd
  local single_dev="/dev/disk/by-path/ip-${target_ips[0]}:${port}-iscsi-${iqn}-lun-1"

  echo "  [A] multipath mode"
  # Ensure we aren't mounted from a previous run (single-path may have mounted raw sdX).
  guest_unmount_fs "opc@${PUBLIC_IP}" "$mnt"
  mpath_dev="$(guest_login_targets "opc@${PUBLIC_IP}" "multipath" "$iqn" "$port" "$expected_path" "${target_ips[@]}")"
  mpath_dev="${mpath_dev:-$expected_path}"
  guest_configure_multipath_round_robin "opc@${PUBLIC_IP}" || true
  # Verify multipath best-effort; do not abort the whole run on transient verify issues.
  set +e
  trap - ERR
  set +E
  guest_verify_multipath "$mpath_dev"
  ec=$?
  set -E
  trap _on_err ERR
  set -e
  if [ "$ec" -ne 0 ]; then
    echo "  [WARN] Multipath verification failed; continuing to load test anyway." >&2
  fi
  guest_collect_diag "opc@${PUBLIC_IP}" "$diag_mpath"
  guest_prepare_fs "opc@${PUBLIC_IP}" "$mpath_dev" "$mnt"
  # If fstab is enabled, make systemd mount units consistent with the device we intend to use
  # BEFORE asserting or running load (otherwise systemd may unmount/remount to a different source).
  if [ "${USE_FSTAB:-false}" = "true" ]; then
    _ssh sudo bash -s -- "$mpath_dev" "$mnt" "${FSTAB_TAG:-bv4db-sprint20}" <<'EOF' || true
set -euo pipefail
DEV="$1"
MNT="$2"
TAG="# ${3:-bv4db-sprint20}"
grep -vF "$TAG" /etc/fstab > /tmp/fstab.new || true
grep -v "^[^#].*[[:space:]]${MNT}[[:space:]]" /tmp/fstab.new > /tmp/fstab.new2 2>/dev/null || cp /tmp/fstab.new /tmp/fstab.new2
echo "${DEV} ${MNT} xfs defaults,_netdev,nofail 0 2 ${TAG}" >> /tmp/fstab.new2
cp -f /tmp/fstab.new2 /etc/fstab
systemctl daemon-reload >/dev/null 2>&1 || true
mount -a >/dev/null 2>&1 || true
EOF
  fi
  guest_assert_mounted_block_device "opc@${PUBLIC_IP}" "multipath" "$mnt" "multipath"
  guest_collect_config "opc@${PUBLIC_IP}" "multipath_pre" "$mnt" "$cfg_mpath_pre"
  if [ "$generator" = "dd" ]; then
    guest_run_dd_fallback "opc@${PUBLIC_IP}" "$mnt" "/tmp/dd_multipath.json" "/tmp/dd_multipath.txt"
    guest_assert_remote_file "/tmp/dd_multipath.json" "dd multipath json"
    guest_assert_remote_file "/tmp/dd_multipath.txt" "dd multipath txt"
    _scp "/tmp/dd_multipath.json" "$result_mpath"
    _scp "/tmp/dd_multipath.txt" "$dd_mpath_txt"
    generator="dd"
  else
    _step "Ensuring fio is installed on the guest..."
    set +e
    ensure_guest_fio >/dev/null 2>&1
    set -e
    set +e
    # fio may be absent; don't trigger ERR trap for this optional path.
    trap - ERR
    set +E
    guest_capture_iostat_during_fio "opc@${PUBLIC_IP}" "multipath" "$mnt" "/tmp/iostat_multipath_${ts}.txt" "fio" "mpatha" "${FIO_RUNTIME_SEC:-120}"
    guest_run_fio "opc@${PUBLIC_IP}" "$mnt" "/tmp/fio_multipath.json" "/tmp/fio_multipath_${ts}.txt"
    ec=$?
    guest_stop_iostat_capture "opc@${PUBLIC_IP}" "/tmp/iostat_multipath_${ts}.txt"
    set -E
    trap _on_err ERR
    set -e
    if [ "$ec" -eq 0 ] && _ssh test -s /tmp/fio_multipath.json; then
      _scp "/tmp/fio_multipath.json" "$result_mpath"
      _scp "/tmp/fio_multipath_${ts}.txt" "$PROGRESS_DIR/fio_multipath_${ts}.txt" 2>/dev/null || true
      _scp "/tmp/iostat_multipath_${ts}.txt" "$iostat_mpath_txt" 2>/dev/null || true
      generator="fio"
    else
      guest_run_dd_fallback "opc@${PUBLIC_IP}" "$mnt" "/tmp/dd_multipath.json" "/tmp/dd_multipath.txt"
      guest_assert_remote_file "/tmp/dd_multipath.json" "dd multipath json"
      guest_assert_remote_file "/tmp/dd_multipath.txt" "dd multipath txt"
      _scp "/tmp/dd_multipath.json" "$result_mpath"
      _scp "/tmp/dd_multipath.txt" "$dd_mpath_txt"
      generator="dd"
    fi
  fi
  guest_collect_config "opc@${PUBLIC_IP}" "multipath_post" "$mnt" "$cfg_mpath_post"

  generate_oci_metrics_report "multipath" "$result_mpath" || true

  echo "  [B] single-path mode"
  # Important: unmount before logging out iSCSI sessions / stopping multipathd
  guest_unmount_fs "opc@${PUBLIC_IP}" "$mnt"
  single_dev="$(guest_login_targets "opc@${PUBLIC_IP}" "single" "$iqn" "$port" "$single_dev" "${target_ips[@]}")"
  [ -n "${single_dev:-}" ] || { echo "  [ERROR] Failed to resolve single-path device path" >&2; exit 1; }
  guest_collect_diag "opc@${PUBLIC_IP}" "$diag_single"
  guest_prepare_fs "opc@${PUBLIC_IP}" "$single_dev" "$mnt"
  if [ "${USE_FSTAB:-false}" = "true" ]; then
    _ssh sudo bash -s -- "$single_dev" "$mnt" "${FSTAB_TAG:-bv4db-sprint20}" <<'EOF' || true
set -euo pipefail
DEV="$1"
MNT="$2"
TAG="# ${3:-bv4db-sprint20}"
grep -vF "$TAG" /etc/fstab > /tmp/fstab.new || true
grep -v "^[^#].*[[:space:]]${MNT}[[:space:]]" /tmp/fstab.new > /tmp/fstab.new2 2>/dev/null || cp /tmp/fstab.new /tmp/fstab.new2
echo "${DEV} ${MNT} xfs defaults,_netdev,nofail 0 2 ${TAG}" >> /tmp/fstab.new2
cp -f /tmp/fstab.new2 /etc/fstab
systemctl daemon-reload >/dev/null 2>&1 || true
mount -a >/dev/null 2>&1 || true
EOF
  fi
  guest_assert_mounted_block_device "opc@${PUBLIC_IP}" "singlepath" "$mnt" "single"
  guest_collect_config "opc@${PUBLIC_IP}" "singlepath_pre" "$mnt" "$cfg_single_pre"
  if [ "$generator" = "fio" ] && [ "${LOAD_GENERATOR:-auto}" != "dd" ]; then
    _step "Ensuring fio is installed on the guest..."
    set +e
    ensure_guest_fio >/dev/null 2>&1
    set -e
    set +e
    trap - ERR
    set +E
    guest_capture_iostat_during_fio "opc@${PUBLIC_IP}" "singlepath" "$mnt" "/tmp/iostat_singlepath_${ts}.txt" "fio" "mpatha" "${FIO_RUNTIME_SEC:-120}"
    guest_run_fio "opc@${PUBLIC_IP}" "$mnt" "/tmp/fio_singlepath.json" "/tmp/fio_singlepath_${ts}.txt"
    ec=$?
    guest_stop_iostat_capture "opc@${PUBLIC_IP}" "/tmp/iostat_singlepath_${ts}.txt"
    set -E
    trap _on_err ERR
    set -e
    if [ "$ec" -eq 0 ] && _ssh test -s /tmp/fio_singlepath.json; then
      _scp "/tmp/fio_singlepath.json" "$result_single"
      _scp "/tmp/fio_singlepath_${ts}.txt" "$PROGRESS_DIR/fio_singlepath_${ts}.txt" 2>/dev/null || true
      _scp "/tmp/iostat_singlepath_${ts}.txt" "$iostat_single_txt" 2>/dev/null || true
    else
      generator="dd"
      guest_run_dd_fallback "opc@${PUBLIC_IP}" "$mnt" "/tmp/dd_singlepath.json" "/tmp/dd_singlepath.txt"
      guest_assert_remote_file "/tmp/dd_singlepath.json" "dd singlepath json"
      guest_assert_remote_file "/tmp/dd_singlepath.txt" "dd singlepath txt"
      _scp "/tmp/dd_singlepath.json" "$result_single"
      _scp "/tmp/dd_singlepath.txt" "$dd_single_txt"
    fi
  else
    guest_run_dd_fallback "opc@${PUBLIC_IP}" "$mnt" "/tmp/dd_singlepath.json" "/tmp/dd_singlepath.txt"
    guest_assert_remote_file "/tmp/dd_singlepath.json" "dd singlepath json"
    guest_assert_remote_file "/tmp/dd_singlepath.txt" "dd singlepath txt"
    _scp "/tmp/dd_singlepath.json" "$result_single"
    _scp "/tmp/dd_singlepath.txt" "$dd_single_txt"
  fi
  guest_collect_config "opc@${PUBLIC_IP}" "singlepath_post" "$mnt" "$cfg_single_post"

  generate_oci_metrics_report "singlepath" "$result_single" || true

  local bw_mpath bw_single
  bw_mpath="$(extract_total_bw_mbps "$result_mpath")"
  bw_single="$(extract_total_bw_mbps "$result_single")"

  local fio_profile="${FIO_PROFILE:-randrw_4k}"
  local fio_desc=""
  if [ "$fio_profile" = "read_1m_bw" ]; then
    fio_desc="read, bs=1M, numjobs=${FIO_NUMJOBS:-4}, iodepth=${FIO_IODEPTH:-32}, runtime=${FIO_RUNTIME_SEC:-120}s"
  else
    fio_desc="randrw 70/30, bs=4k, numjobs=${FIO_NUMJOBS:-4}, iodepth=${FIO_IODEPTH:-32}, runtime=${FIO_RUNTIME_SEC:-120}s"
  fi

  local diag_mpath_base diag_single_base result_mpath_base result_single_base
  diag_mpath_base="$(basename "$diag_mpath")"
  diag_single_base="$(basename "$diag_single")"
  result_mpath_base="$(basename "$result_mpath")"
  result_single_base="$(basename "$result_single")"

  cat >"$summary_md" <<SUMMARY_EOF
# Sprint 20 — A/B (multipath vs single-path)

## Inputs

* shape: $COMPUTE_SHAPE ($COMPUTE_OCPUS OCPUs, $COMPUTE_MEMORY_GB GB)
* block volume: UHP ($BLOCKVOLUME_SIZE_GB GB, $BLOCKVOLUME_VPUS_PER_GB VPU/GB)
* generator: $generator
* fio (if used): $fio_desc (profile=${fio_profile})
* dd (if used): jobs=${DD_JOBS:-4}, size_gb=${DD_SIZE_GB:-16} per job, bs=${DD_BS:-16M}

## Results (Total BW)

* multipath: ${bw_mpath} MB/s
* single-path: ${bw_single} MB/s

## Artifacts

* diagnostics multipath: ${diag_mpath_base}
* diagnostics single-path: ${diag_single_base}
* result multipath: ${result_mpath_base}
* result single-path: ${result_single_base}
SUMMARY_EOF

  cp -f "$STATE_FILE" "$state_json"
  ln -sf "$(basename "$state_json")" "$PROGRESS_DIR/state-bv4db-s20-latest.json"

  if [ "${KEEP_INFRA:-false}" = "true" ]; then
    echo "  [INFO] KEEP_INFRA=true — skipping teardown"
    echo "  [INFO] State: $state_json"
    echo "  [INFO] Public IP: $PUBLIC_IP"
  else
    echo "  [INFO] Teardown ..."
    teardown-blockvolume.sh
    teardown-compute.sh
    rm -f "$STATE_FILE" || true
  fi

  echo "  [DONE] Summary: $summary_md"
}

main "$@"

