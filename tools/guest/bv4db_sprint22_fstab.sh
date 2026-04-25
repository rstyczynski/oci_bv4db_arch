#!/usr/bin/env bash
# Sprint 22 (BV4DB-52): Guest-side fstab management for multipath block volumes.
# This script runs ON THE INSTANCE (not on the operator's laptop).

set -euo pipefail

FSTAB_TAG="# bv4db-sprint22"

usage() {
  cat <<EOF
Usage: $0 <action> [options]

Actions:
  add       --device <path> --mount <mountpoint>   Add/update fstab entry
  disable   --mount <mountpoint>                   Comment out fstab entry (temporary disable)
  enable    --mount <mountpoint>                   Uncomment fstab entry
  remove    --mount <mountpoint>                   Remove fstab entry entirely
  show      [--mount <mountpoint>]                 Show sprint-managed fstab entries
  verify    --mount <mountpoint>                   Verify mount is working

Options:
  --device <path>     Device path (e.g., /dev/oracleoci/oraclevdb)
  --mount <mountpoint> Mount point (e.g., /mnt/sprint22)
  --fstype <type>     Filesystem type (default: xfs)
  --options <opts>    Mount options (default: defaults,_netdev,nofail)

Examples:
  $0 add --device /dev/oracleoci/oraclevdb --mount /mnt/sprint22
  $0 disable --mount /mnt/sprint22
  $0 enable --mount /mnt/sprint22
  $0 remove --mount /mnt/sprint22
  $0 show
  $0 verify --mount /mnt/sprint22
EOF
  exit 1
}

# Parse arguments
ACTION=""
DEVICE=""
MOUNT=""
FSTYPE="xfs"
OPTIONS="defaults,_netdev,nofail"

while [[ $# -gt 0 ]]; do
  case "$1" in
    add|disable|enable|remove|show|verify)
      ACTION="$1"
      shift
      ;;
    --device)
      DEVICE="$2"
      shift 2
      ;;
    --mount)
      MOUNT="$2"
      shift 2
      ;;
    --fstype)
      FSTYPE="$2"
      shift 2
      ;;
    --options)
      OPTIONS="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      ;;
  esac
done

[ -n "$ACTION" ] || usage

fstab_add() {
  local device="$1"
  local mount="$2"
  local fstype="$3"
  local options="$4"
  local tag="$FSTAB_TAG"

  [ -n "$device" ] || { echo "Error: --device required for add" >&2; exit 1; }
  [ -n "$mount" ] || { echo "Error: --mount required for add" >&2; exit 1; }

  local entry="${device} ${mount} ${fstype} ${options} 0 2 ${tag}"

  # Remove any existing entry for this mount, then add the new one
  grep -vF "$tag" /etc/fstab > /tmp/fstab.new 2>/dev/null || true
  grep -v "^[^#].*[[:space:]]${mount}[[:space:]]" /tmp/fstab.new > /tmp/fstab.new2 2>/dev/null || cp /tmp/fstab.new /tmp/fstab.new2
  echo "$entry" >> /tmp/fstab.new2
  cp -f /tmp/fstab.new2 /etc/fstab
  rm -f /tmp/fstab.new /tmp/fstab.new2

  echo "Added fstab entry: $entry"

  # Ensure mount point exists
  mkdir -p "$mount" 2>/dev/null || true

  # Validate with mount -a
  if mount -a 2>/dev/null; then
    echo "mount -a: OK"
  else
    echo "Warning: mount -a had issues (non-fatal)" >&2
  fi
}

fstab_disable() {
  local mount="$1"
  local tag="$FSTAB_TAG"

  [ -n "$mount" ] || { echo "Error: --mount required for disable" >&2; exit 1; }

  # Comment out lines that have both the tag AND the mount point
  sed -i "s|^\\([^#].*${mount}[[:space:]].*${tag}\\)\$|# \\1|" /etc/fstab

  echo "Disabled fstab entry for: $mount"
  grep -F "$tag" /etc/fstab || echo "(no matching entries)"

  # Unmount if currently mounted
  if mountpoint -q "$mount" 2>/dev/null; then
    umount "$mount" 2>/dev/null || umount -l "$mount" 2>/dev/null || true
    echo "Unmounted: $mount"
  fi
}

fstab_enable() {
  local mount="$1"
  local tag="$FSTAB_TAG"

  [ -n "$mount" ] || { echo "Error: --mount required for enable" >&2; exit 1; }

  # Uncomment lines that have both the tag AND the mount point
  sed -i "s|^# \\(.*${mount}[[:space:]].*${tag}\\)\$|\\1|" /etc/fstab

  echo "Enabled fstab entry for: $mount"
  grep -F "$tag" /etc/fstab || echo "(no matching entries)"

  # Mount
  if mount -a 2>/dev/null; then
    echo "mount -a: OK"
  else
    echo "Warning: mount -a had issues" >&2
  fi
}

fstab_remove() {
  local mount="$1"
  local tag="$FSTAB_TAG"

  [ -n "$mount" ] || { echo "Error: --mount required for remove" >&2; exit 1; }

  # Unmount first if mounted
  if mountpoint -q "$mount" 2>/dev/null; then
    umount "$mount" 2>/dev/null || umount -l "$mount" 2>/dev/null || true
    echo "Unmounted: $mount"
  fi

  # Remove lines with the tag for this mount
  grep -v "${mount}[[:space:]].*${tag}" /etc/fstab > /tmp/fstab.new 2>/dev/null || true
  cp -f /tmp/fstab.new /etc/fstab
  rm -f /tmp/fstab.new

  echo "Removed fstab entry for: $mount"
}

fstab_show() {
  local mount="${1:-}"
  local tag="$FSTAB_TAG"

  echo "=== Sprint 22 managed fstab entries ==="
  if [ -n "$mount" ]; then
    grep -n "${mount}[[:space:]].*${tag}" /etc/fstab || echo "(no entry for $mount)"
  else
    grep -n "$tag" /etc/fstab || echo "(no sprint 22 entries)"
  fi
}

fstab_verify() {
  local mount="$1"

  [ -n "$mount" ] || { echo "Error: --mount required for verify" >&2; exit 1; }

  echo "=== Verifying mount: $mount ==="

  # Check fstab entry
  echo "fstab entry:"
  grep -n "${mount}[[:space:]]" /etc/fstab || echo "(not in fstab)"

  # Check if mounted
  echo ""
  echo "mount status:"
  if mountpoint -q "$mount" 2>/dev/null; then
    echo "MOUNTED"
    mount | grep -F " $mount " || true
    df -h "$mount" || true
  else
    echo "NOT MOUNTED"
  fi

  # Check device
  echo ""
  echo "device check:"
  local dev
  dev="$(grep "^[^#].*${mount}[[:space:]]" /etc/fstab | awk '{print $1}' | head -n1 || true)"
  if [ -n "$dev" ] && [ -b "$dev" ]; then
    echo "device exists: $dev"
    ls -la "$dev" || true
  elif [ -n "$dev" ]; then
    echo "device NOT found: $dev"
  else
    echo "(no device in fstab for this mount)"
  fi
}

# Execute action
case "$ACTION" in
  add)
    fstab_add "$DEVICE" "$MOUNT" "$FSTYPE" "$OPTIONS"
    ;;
  disable)
    fstab_disable "$MOUNT"
    ;;
  enable)
    fstab_enable "$MOUNT"
    ;;
  remove)
    fstab_remove "$MOUNT"
    ;;
  show)
    fstab_show "$MOUNT"
    ;;
  verify)
    fstab_verify "$MOUNT"
    ;;
  *)
    usage
    ;;
esac
