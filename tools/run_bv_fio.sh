#!/usr/bin/env bash
# run_bv_fio.sh — provision ephemeral compute + block volume, run fio, tear down
#
# Reads infra state: progress/sprint_1/state-bv4db.json  (from setup_infra.sh)
# Compute state:     progress/sprint_1/state-bv4db-run.json  (NAME_PREFIX=bv4db-run)
# fio results:       progress/sprint_1/fio-results.json
#
# Usage:
#   OCI_REGION=eu-zurich-1 ./tools/run_bv_fio.sh
#   KEEP_INFRA=true ./tools/run_bv_fio.sh   # skip teardown

set -euo pipefail
set -E
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCAFFOLD_DIR="$REPO_DIR/oci_scaffold"
PROGRESS_DIR="$REPO_DIR/progress/sprint_1"
INFRA_STATE="$PROGRESS_DIR/state-bv4db.json"

export PATH="$SCAFFOLD_DIR/do:$SCAFFOLD_DIR/resource:$PATH"
export NAME_PREFIX="bv4db-run"
export OCI_REGION="${OCI_REGION:-}"
KEEP_INFRA="${KEEP_INFRA:-false}"

_on_err() {
  local ec=$? line=${BASH_LINENO[0]:-?} cmd=${BASH_COMMAND:-?}
  echo "  [FAIL] run_bv_fio.sh failed (exit $ec) at line $line: $cmd" >&2
}
trap _on_err ERR

[ -f "$INFRA_STATE" ] || { echo "  [ERROR] Infra state not found: $INFRA_STATE — run setup_infra.sh first" >&2; exit 1; }

mkdir -p "$PROGRESS_DIR"
cd "$PROGRESS_DIR"

source "$SCAFFOLD_DIR/do/oci_scaffold.sh"

# ── read infra state ───────────────────────────────────────────────────────
COMPARTMENT_OCID=$(jq -r '.compartment.ocid' "$INFRA_STATE")
SUBNET_OCID=$(jq -r '.subnet.ocid'           "$INFRA_STATE")
SECRET_OCID=$(jq -r '.secret.ocid'           "$INFRA_STATE")
PUBKEY_FILE="$PROGRESS_DIR/bv4db-key.pub"

[ -n "$COMPARTMENT_OCID" ] || { echo "  [ERROR] No compartment OCID in infra state" >&2; exit 1; }
[ -f "$PUBKEY_FILE"       ] || { echo "  [ERROR] SSH public key not found: $PUBKEY_FILE" >&2; exit 1; }

# ── seed compute state ────────────────────────────────────────────────────
[ -n "$OCI_REGION" ] && _state_set '.inputs.oci_region' "$OCI_REGION"
_state_set '.inputs.name_prefix'                       "$NAME_PREFIX"
_state_set '.inputs.oci_compartment'                   "$COMPARTMENT_OCID"
_state_set '.subnet.ocid'                              "$SUBNET_OCID"
_state_set '.inputs.compute_shape'                     'VM.Standard.E4.Flex'
_state_set '.inputs.compute_ocpus'                     '2'
_state_set '.inputs.compute_memory_gb'                 '16'
_state_set '.inputs.subnet_prohibit_public_ip'         'false'
_state_set '.inputs.compute_ssh_authorized_keys_file'  "$PUBKEY_FILE"
_state_set '.inputs.bv_size_gb'                        '50'
_state_set '.inputs.bv_attach_type'                    'iscsi'

# ── compute instance ──────────────────────────────────────────────────────
ensure-compute.sh
COMPUTE_OCID=$(_state_get '.compute.ocid')
PUBLIC_IP=$(_state_get '.compute.public_ip')

# ── block volume ──────────────────────────────────────────────────────────
ensure-blockvolume.sh
IQN=$(_state_get '.blockvolume.iqn')
IPV4=$(_state_get '.blockvolume.ipv4')
PORT=$(_state_get '.blockvolume.port')

# ── retrieve SSH private key from vault ──────────────────────────────────
TMPKEY=$(mktemp)
chmod 600 "$TMPKEY"
oci secrets secret-bundle get \
  --secret-id "$SECRET_OCID" \
  --query 'data."secret-bundle-content".content' --raw-output \
  | base64 --decode > "$TMPKEY"

_ssh() { ssh -i "$TMPKEY" -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
              -o BatchMode=yes "opc@${PUBLIC_IP}" "$@"; }

# ── wait for SSH ──────────────────────────────────────────────────────────
echo "  [INFO] Waiting for SSH on $PUBLIC_IP ..."
ssh-keygen -R "$PUBLIC_IP" >/dev/null 2>&1 || true
elapsed=0
while ! _ssh true 2>/dev/null; do
  sleep 5; elapsed=$((elapsed + 5))
  printf "\033[2K\r  [WAIT] SSH %ds" "$elapsed"
done
echo ""

# ── iSCSI login ───────────────────────────────────────────────────────────
echo "  [INFO] Connecting block volume via iSCSI ..."
_ssh "sudo iscsiadm -m node -o new -T '$IQN' -p '$IPV4:$PORT'"
_ssh "sudo iscsiadm -m node -o update -T '$IQN' -n node.startup -v automatic"
_ssh "sudo iscsiadm -m node -T '$IQN' -p '$IPV4:$PORT' -l"
sleep 3

# ── format and mount ──────────────────────────────────────────────────────
echo "  [INFO] Formatting and mounting block volume ..."
_ssh "sudo mkfs.ext4 /dev/sdb"
_ssh "sudo mkdir -p /mnt/bv && sudo mount /dev/sdb /mnt/bv && sudo chown opc:opc /mnt/bv"
echo "  [INFO] Block volume mounted at /mnt/bv"

# ── install fio ───────────────────────────────────────────────────────────
echo "  [INFO] Installing fio ..."
_ssh "sudo dnf install -y fio" > /dev/null

# ── run fio benchmark ─────────────────────────────────────────────────────
echo "  [INFO] Running fio sequential (1M rw) ..."
FIO_SEQ=$(_ssh "sudo fio --name=seq-rw --rw=rw --bs=1M --size=1G \
  --numjobs=1 --ioengine=libaio --direct=1 --group_reporting \
  --output-format=json --filename=/mnt/bv/testfile")

echo "  [INFO] Running fio random (4k randrw, 4 jobs) ..."
FIO_RAND=$(_ssh "sudo fio --name=rand-rw --rw=randrw --bs=4k --size=512M \
  --numjobs=4 --iodepth=32 --ioengine=libaio --direct=1 --group_reporting \
  --output-format=json --filename=/mnt/bv/testfile")

# ── save results ──────────────────────────────────────────────────────────
jq -s '{"sequential": .[0], "random": .[1]}' \
  <(echo "$FIO_SEQ") <(echo "$FIO_RAND") \
  > "$PROGRESS_DIR/fio-results.json"
echo "  [INFO] Results saved: $PROGRESS_DIR/fio-results.json"

# ── print summary ─────────────────────────────────────────────────────────
echo ""
echo "=== fio Results Summary ==="
jq -r '
  (.sequential.jobs[0]) as $s |
  (.random.jobs[0])     as $r |
  "Sequential:  read  \(.[$s."read" ."iops"] // $s.read.iops | round) IOPS  \($s.read.bw // 0 | . / 1024 | round) MB/s  lat \($s.read.lat_ns.mean // 0 | . / 1000000 | round * 100 / 100) ms",
  "             write \(.[$s."write"."iops"] // $s.write.iops | round) IOPS  \($s.write.bw // 0 | . / 1024 | round) MB/s  lat \($s.write.lat_ns.mean // 0 | . / 1000000 | round * 100 / 100) ms",
  "Random:      read  \($r.read.iops | round) IOPS  \($r.read.bw // 0 | . / 1024 | round) MB/s  lat \($r.read.lat_ns.mean // 0 | . / 1000000 | round * 100 / 100) ms",
  "             write \($r.write.iops | round) IOPS  \($r.write.bw // 0 | . / 1024 | round) MB/s  lat \($r.write.lat_ns.mean // 0 | . / 1000000 | round * 100 / 100) ms"
' "$PROGRESS_DIR/fio-results.json" 2>/dev/null || echo "  (parse summary manually from fio-results.json)"

# ── cleanup ───────────────────────────────────────────────────────────────
rm -f "$TMPKEY"

if [ "$KEEP_INFRA" != "true" ]; then
  echo ""
  echo "  [INFO] Tearing down compute and block volume ..."
  "$SCAFFOLD_DIR/do/teardown.sh"
  echo "  [INFO] Teardown complete"
else
  echo ""
  echo "  KEEP_INFRA=true — skipping teardown"
  echo "  SSH: ssh -i <key-from-vault> opc@$PUBLIC_IP"
fi

print_summary
