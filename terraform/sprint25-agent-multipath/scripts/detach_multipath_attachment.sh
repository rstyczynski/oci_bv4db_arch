#!/usr/bin/env bash
# Detach the multipath attachment created by create_multipath_attachment.sh.

set -euo pipefail

: "${ATTACHMENT_STATE_FILE:?ATTACHMENT_STATE_FILE is required}"

if [ ! -f "$ATTACHMENT_STATE_FILE" ]; then
  echo "Attachment state file not found; nothing to detach: $ATTACHMENT_STATE_FILE"
  exit 0
fi

attachment_id="$(jq -r '.data.id // empty' "$ATTACHMENT_STATE_FILE")"
if [ -z "$attachment_id" ]; then
  echo "No attachment id in $ATTACHMENT_STATE_FILE; nothing to detach"
  exit 0
fi

oci compute volume-attachment detach \
  --volume-attachment-id "$attachment_id" \
  --force

rm -f "$ATTACHMENT_STATE_FILE"
echo "Detached multipath attachment: $attachment_id"
