#!/usr/bin/env bash
# run_oci_scaffold_sync_smoke.sh — Sprint 6 trivial smoke for merged oci_scaffold ensure-blockvolume.

set -euo pipefail
set -E

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCAFFOLD_DIR="$REPO_DIR/oci_scaffold"
PROGRESS_DIR="$REPO_DIR/progress/sprint_6"
SPRINT1_DIR="$REPO_DIR/progress/sprint_1"
INFRA_STATE="$SPRINT1_DIR/state-bv4db.json"

export PATH="$SCAFFOLD_DIR/do:$SCAFFOLD_DIR/resource:$PATH"
export NAME_PREFIX="bv4db-scaffold-sync"
export OCI_REGION="${OCI_REGION:-}"

_on_err() {
  local ec=$? line=${BASH_LINENO[0]:-?} cmd=${BASH_COMMAND:-?}
  echo "  [FAIL] run_oci_scaffold_sync_smoke.sh failed (exit $ec) at line $line: $cmd" >&2
}
trap _on_err ERR

[ -f "$INFRA_STATE" ] || { echo "  [ERROR] Infra state not found: $INFRA_STATE" >&2; exit 1; }

mkdir -p "$PROGRESS_DIR"
cd "$PROGRESS_DIR"

source "$SCAFFOLD_DIR/do/oci_scaffold.sh"

COMPARTMENT_OCID=$(jq -r '.compartment.ocid' "$INFRA_STATE")
SUBNET_OCID=$(jq -r '.subnet.ocid' "$INFRA_STATE")
PUBKEY_FILE="$SPRINT1_DIR/bv4db-key.pub"

[ -n "$COMPARTMENT_OCID" ] || { echo "  [ERROR] No compartment OCID in Sprint 1 infra state" >&2; exit 1; }
[ -f "$PUBKEY_FILE" ] || { echo "  [ERROR] SSH public key not found: $PUBKEY_FILE" >&2; exit 1; }

[ -n "$OCI_REGION" ] && _state_set '.inputs.oci_region' "$OCI_REGION"
_state_set '.inputs.name_prefix' "$NAME_PREFIX"
_state_set '.inputs.oci_compartment' "$COMPARTMENT_OCID"
_state_set '.subnet.ocid' "$SUBNET_OCID"
_state_set '.inputs.compute_shape' 'VM.Standard.E4.Flex'
_state_set '.inputs.compute_ocpus' '1'
_state_set '.inputs.compute_memory_gb' '8'
_state_set '.inputs.subnet_prohibit_public_ip' 'false'
_state_set '.inputs.compute_ssh_authorized_keys_file' "$PUBKEY_FILE"
_state_set '.inputs.bv_size_gb' '50'
_state_set '.inputs.bv_attach_type' 'iscsi'

echo "  [INFO] Provisioning ephemeral compute for scaffold smoke ..."
ensure-compute.sh

echo "  [INFO] Running ensure-blockvolume.sh from merged oci_scaffold branch ..."
ensure-blockvolume.sh

ATTACH_OCID=$(_state_get '.blockvolume.attachment_ocid')
BV_OCID=$(_state_get '.blockvolume.ocid')
IQN=$(_state_get '.blockvolume.iqn')
IPV4=$(_state_get '.blockvolume.ipv4')
PORT=$(_state_get '.blockvolume.port')

[ -n "$BV_OCID" ] || { echo "  [ERROR] Block volume OCID missing from state" >&2; exit 1; }
[ -n "$ATTACH_OCID" ] || { echo "  [ERROR] Attachment OCID missing from state" >&2; exit 1; }

ATTACH_STATE=$(oci compute volume-attachment get \
  --volume-attachment-id "$ATTACH_OCID" \
  --query 'data."lifecycle-state"' --raw-output)
SUBMODULE_BRANCH=$(git -C "$SCAFFOLD_DIR" symbolic-ref -q --short HEAD || true)
[ -z "${SUBMODULE_BRANCH:-}" ] && SUBMODULE_BRANCH="oci_bv4db_arch"

{
  echo "# Sprint 6 — oci_scaffold Sync Smoke"
  echo ""
  echo "- Submodule branch: \`${SUBMODULE_BRANCH}\`"
  echo "- Submodule commit: \`$(git -C "$SCAFFOLD_DIR" rev-parse --short HEAD)\`"
  echo "- Compute OCID: \`$(_state_get '.compute.ocid')\`"
  echo "- Block volume OCID: \`$BV_OCID\`"
  echo "- Attachment OCID: \`$ATTACH_OCID\`"
  echo "- Attachment state: \`$ATTACH_STATE\`"
  echo "- iSCSI target: \`${IQN} ${IPV4}:${PORT}\`"
} > "$PROGRESS_DIR/scaffold_sync_smoke.md"

echo ""
echo "  [INFO] Tearing down scaffold smoke resources ..."
"$SCAFFOLD_DIR/do/teardown.sh"
echo "  [INFO] Teardown complete"

print_summary
