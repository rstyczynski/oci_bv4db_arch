#!/usr/bin/env bash
# setup_infra.sh — provision persistent infrastructure for oci_bv4db_arch
#
# Creates (idempotent): compartment, VCN, subnet, IGW, route table, security
# list, OCI Vault, KMS key, SSH key pair, and SSH private key secret.
#
# State file: progress/sprint_1/state-bv4db.json  (NAME_PREFIX=bv4db)
# SSH public key: progress/sprint_1/bv4db-key.pub
#
# Usage:
#   OCI_REGION=eu-frankfurt-1 ./setup_infra.sh

set -euo pipefail
set -E
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCAFFOLD_DIR="$REPO_DIR/oci_scaffold"
PROGRESS_DIR="$REPO_DIR/progress/sprint_1"

export PATH="$SCAFFOLD_DIR/do:$SCAFFOLD_DIR/resource:$PATH"
export NAME_PREFIX="bv4db"
export OCI_REGION="${OCI_REGION:-}"

_on_err() {
  local ec=$? line=${BASH_LINENO[0]:-?} cmd=${BASH_COMMAND:-?}
  echo "  [FAIL] setup_infra.sh failed (exit $ec) at line $line: $cmd" >&2
}
trap _on_err ERR

mkdir -p "$PROGRESS_DIR"

# Run all scaffold commands from the progress dir so state file lands there
cd "$PROGRESS_DIR"

source "$SCAFFOLD_DIR/do/oci_scaffold.sh"

# ── region ────────────────────────────────────────────────────────────────
[ -n "$OCI_REGION" ] && _state_set '.inputs.oci_region' "$OCI_REGION"
_state_set '.inputs.name_prefix' "$NAME_PREFIX"

# ── compartment ───────────────────────────────────────────────────────────
_state_set '.inputs.compartment_path' '/oci_bv4db_arch'
ensure-compartment.sh
_state_set '.inputs.oci_compartment' "$(_state_get '.compartment.ocid')"

# ── network ───────────────────────────────────────────────────────────────
_state_set '.inputs.subnet_prohibit_public_ip' 'false'
_state_set '.inputs.sl_ingress_cidr'           '0.0.0.0/0'
_state_set '.inputs.sl_ingress_protocol'       '6'
_state_set '.inputs.sl_ingress_port'           '22'

ensure-vcn.sh
ensure-sl.sh
ensure-igw.sh
ensure-rt.sh
ensure-subnet.sh

# ── SSH key pair ──────────────────────────────────────────────────────────
PUBKEY_FILE="$PROGRESS_DIR/bv4db-key.pub"

if [ ! -f "$PUBKEY_FILE" ] && [ -z "$(_state_get '.secret.ocid')" ]; then
  ssh-keygen -t rsa -b 4096 -N "" -f /tmp/bv4db-key -C "bv4db" -q
  PRIVATE_KEY=$(cat /tmp/bv4db-key)
  cp /tmp/bv4db-key.pub "$PUBKEY_FILE"
  rm -f /tmp/bv4db-key /tmp/bv4db-key.pub
  echo "  [INFO] SSH key pair generated"

  # ── vault + KMS key + secret ─────────────────────────────────────────
  _state_set '.inputs.vault_type'          'DEFAULT'
  _state_set '.inputs.key_algorithm'       'AES'
  _state_set '.inputs.key_protection_mode' 'SOFTWARE'
  ensure-vault.sh
  ensure-key.sh

  _state_set '.inputs.secret_name'  'bv4db-ssh-key'
  _state_set '.inputs.secret_value' "$PRIVATE_KEY"
  ensure-secret.sh

  # remove private key from state after secret is stored
  _state_set '.inputs.secret_value' ''
  echo "  [INFO] SSH private key stored in vault secret"
else
  echo "  [INFO] SSH key and vault already provisioned — skipping"
  ensure-vault.sh
  ensure-key.sh
  ensure-secret.sh
fi

print_summary

echo ""
echo "  State : $STATE_FILE"
echo "  Pubkey: $PUBKEY_FILE"
echo "  SSH   : retrieve private key from vault secret $(_state_get '.secret.name')"
