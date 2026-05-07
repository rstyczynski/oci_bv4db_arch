#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$REPO_ROOT/progress/sprint_24"

need() {
  local v="$1"
  if [ -z "${!v:-}" ]; then
    echo "Missing required env var: $v" >&2
    exit 2
  fi
}

need COMPARTMENT_ID
need INSTANCE_ID
need VOLUME_ATTACHMENT_ID
need MOUNTPOINT

mkdir -p "$OUT_DIR"

echo "Writing live evidence bundle to: $OUT_DIR"

oci instance-agent plugin list \
  --compartment-id "$COMPARTMENT_ID" \
  --instanceagent-id "$INSTANCE_ID" \
  --all \
  --query "data[?name=='Block Volume Management']" \
  > "$OUT_DIR/live_instance_agent_plugins.json"

oci compute volume-attachment get \
  --volume-attachment-id "$VOLUME_ATTACHMENT_ID" \
  > "$OUT_DIR/live_volume_attachment.json"

ssh "${SSH_TARGET:-opc@${PUBLIC_IP:-}}" "sudo iscsiadm -m session" \
  > "$OUT_DIR/live_iscsiadm_session.txt"

ssh "${SSH_TARGET:-opc@${PUBLIC_IP:-}}" "sudo multipath -ll" \
  > "$OUT_DIR/live_multipath_ll.txt"

ssh "${SSH_TARGET:-opc@${PUBLIC_IP:-}}" "findmnt -no SOURCE,TARGET '$MOUNTPOINT'" \
  > "$OUT_DIR/live_findmnt.txt"

echo "OK: wrote:"
ls -1 "$OUT_DIR"/live_*.{json,txt} 2>/dev/null || true

