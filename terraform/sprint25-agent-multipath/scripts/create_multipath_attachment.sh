#!/usr/bin/env bash
# Create a multipath-enabled iSCSI attachment through the OCI API.

set -euo pipefail

: "${INSTANCE_ID:?INSTANCE_ID is required}"
: "${VOLUME_ID:?VOLUME_ID is required}"
: "${DEVICE_PATH:?DEVICE_PATH is required}"
: "${OCI_REGION:?OCI_REGION is required}"
: "${ATTACHMENT_STATE_FILE:?ATTACHMENT_STATE_FILE is required}"

case "$DEVICE_PATH" in
  /dev/oracleoci/oraclevd[a-z])
    if [ "$DEVICE_PATH" = "/dev/oracleoci/oraclevda" ]; then
      echo "DEVICE_PATH must not target the boot volume path /dev/oracleoci/oraclevda" >&2
      exit 1
    fi
    ;;
  *)
    echo "DEVICE_PATH must be an OCI consistent device path such as /dev/oracleoci/oraclevdb" >&2
    exit 1
    ;;
esac

request_body="$(jq -n \
  --arg instanceId "$INSTANCE_ID" \
  --arg volumeId "$VOLUME_ID" \
  --arg device "$DEVICE_PATH" \
  '{
    type: "iscsi",
    instanceId: $instanceId,
    volumeId: $volumeId,
    device: $device,
    isMultipath: true
  }')"

response="$(oci raw-request \
  --http-method POST \
  --target-uri "https://iaas.${OCI_REGION}.oraclecloud.com/20160918/volumeAttachments" \
  --request-body "$request_body")"

mkdir -p "$(dirname "$ATTACHMENT_STATE_FILE")"
printf '%s\n' "$response" \
  | jq 'del(.data."chap-secret", .data."chap-username")' \
  > "$ATTACHMENT_STATE_FILE"

attachment_id="$(jq -r '.data.id // empty' "$ATTACHMENT_STATE_FILE")"
if [ -z "$attachment_id" ]; then
  echo "Failed to create multipath attachment; response written to $ATTACHMENT_STATE_FILE" >&2
  exit 1
fi

echo "Created multipath attachment: $attachment_id"
