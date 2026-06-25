#!/usr/bin/env bash
# Live integration test for Sprint 26 vanilla Oracle-documented UHP attachment.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MODULE_DIR="$REPO_ROOT/terraform/sprint26-vanilla-uhp-attachment"
PROGRESS_DIR="$REPO_ROOT/progress/sprint_26"
STATE_FILE="$REPO_ROOT/progress/sprint_1/state-bv4db.json"

PASS=0
FAIL=0
TMPDIR=""
WORKDIR=""
EVIDENCE=""

pass() { echo "PASS: $*"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $*" >&2; FAIL=$((FAIL + 1)); }

require_file() {
  local path="$1"
  if [ -f "$path" ]; then
    pass "file exists: ${path#$REPO_ROOT/}"
  else
    fail "missing file: ${path#$REPO_ROOT/}"
  fi
}

require_contains() {
  local path="$1"
  local pattern="$2"
  local label="$3"
  if grep -Eq "$pattern" "$path"; then
    pass "$label"
  else
    fail "$label"
  fi
}

require_not_contains() {
  local path="$1"
  local pattern="$2"
  local label="$3"
  if grep -Eq "$pattern" "$path"; then
    fail "$label"
  else
    pass "$label"
  fi
}

require_tree_not_contains() {
  local path="$1"
  local pattern="$2"
  local label="$3"
  if find "$path" -type f \
      ! -path '*/.terraform/*' \
      ! -name '.terraform.lock.hcl' \
      \( -name '*.tf' -o -name '*.sh' \) \
      -exec grep -Eq "$pattern" {} +; then
    fail "$label"
  else
    pass "$label"
  fi
}

cleanup() {
  if [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && [ "${SPRINT26_KEEP_INFRA:-false}" != "true" ]; then
    terraform -chdir="$WORKDIR" destroy -auto-approve -input=false >/dev/null 2>&1 || true
  fi
  if [ -n "${TMPDIR:-}" ] && [ -d "$TMPDIR" ]; then
    rm -rf "$TMPDIR"
  fi
}
trap cleanup EXIT

json_value() {
  jq -r "$1 // empty" "$STATE_FILE"
}

discover_context() {
  REGION="${OCI_REGION:-$(json_value '.inputs.oci_region')}"
  COMPARTMENT_ID="${COMPARTMENT_OCID:-$(json_value '.compartment.ocid')}"
  SUBNET_ID="${SUBNET_OCID:-$(json_value '.subnet.ocid')}"

  [ -n "$REGION" ] || { echo "missing region" >&2; return 1; }
  [ -n "$COMPARTMENT_ID" ] || { echo "missing compartment" >&2; return 1; }
  [ -n "$SUBNET_ID" ] || { echo "missing subnet" >&2; return 1; }

  AVAILABILITY_DOMAIN="${AVAILABILITY_DOMAIN:-$(oci iam availability-domain list \
    --compartment-id "$COMPARTMENT_ID" \
    --query 'data[0].name' \
    --raw-output)}"
  IMAGE_ID="${IMAGE_ID:-$(oci compute image list \
    --compartment-id "$COMPARTMENT_ID" \
    --operating-system 'Oracle Linux' \
    --shape VM.Standard.E5.Flex \
    --sort-by TIMECREATED \
    --sort-order DESC \
    --query 'data[0].id' \
    --raw-output)}"

  [ -n "$AVAILABILITY_DOMAIN" ] || { echo "missing availability domain" >&2; return 1; }
  [ -n "$IMAGE_ID" ] || { echo "missing image id" >&2; return 1; }
}

attachment_json() {
  terraform -chdir="$WORKDIR" show -json \
    | jq -e '.values.root_module.resources[]
      | select(.address == "oci_core_volume_attachment.uhp")
      | .values'
}

write_evidence_header() {
  local ts
  ts="$(date -u '+%Y%m%d_%H%M%S')"
  EVIDENCE="$PROGRESS_DIR/vanilla_uhp_attachment_evidence_${ts}.txt"
  {
    echo "=== Sprint 26 vanilla UHP attachment evidence ==="
    echo "timestamp_utc=$ts"
    echo "workdir=$WORKDIR"
    echo "region=$REGION"
    echo "compartment_id=$COMPARTMENT_ID"
    echo "subnet_id=$SUBNET_ID"
    echo "availability_domain=$AVAILABILITY_DOMAIN"
    echo "image_id=$IMAGE_ID"
    echo
  } > "$EVIDENCE"
}

append_guest_evidence() {
  local public_ip key_path
  public_ip="$(terraform -chdir="$WORKDIR" output -raw instance_public_ip 2>/dev/null || true)"
  key_path="$TMPDIR/sprint26.key"

  {
    echo "=== guest evidence ==="
    echo "public_ip=$public_ip"
  } >> "$EVIDENCE"

  if [ -z "$public_ip" ]; then
    echo "guest_status=SKIPPED_NO_PUBLIC_IP" >> "$EVIDENCE"
    return 1
  fi

  for _ in $(seq 1 30); do
    if ssh -i "$key_path" \
      -o BatchMode=yes \
      -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null \
      -o ConnectTimeout=10 \
      "opc@$public_ip" 'true' >/dev/null 2>&1; then
      break
    fi
    sleep 10
  done

  ssh -i "$key_path" \
    -o BatchMode=yes \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o ConnectTimeout=20 \
    "opc@$public_ip" 'bash -s' >> "$EVIDENCE" 2>&1 <<'REMOTE'
set -o pipefail
echo "--- oracle-cloud-agent ---"
systemctl is-active oracle-cloud-agent || true
systemctl is-enabled oracle-cloud-agent || true
rpm -q oracle-cloud-agent device-mapper-multipath || true
echo "--- block plugin log tail ---"
sudo tail -160 /var/log/oracle-cloud-agent/plugins/oci-blockautoconfig/oci-blockautoconfig.log 2>&1 || true
echo "--- iscsi sessions ---"
sudo iscsiadm -m session 2>&1 || true
echo "--- multipath -ll ---"
sudo multipath -ll 2>&1 || true
echo "--- multipathd paths ---"
sudo multipathd show paths 2>&1 || true
echo "--- multipath.conf ---"
sudo sed -n '1,220p' /etc/multipath.conf 2>&1 || true
echo "--- lsblk ---"
lsblk -o NAME,TYPE,SIZE,MODEL,WWN,FSTYPE,MOUNTPOINT 2>&1 || true
REMOTE
}

live_probe() {
  command -v terraform >/dev/null 2>&1 || { fail "terraform CLI is available"; return 1; }
  command -v oci >/dev/null 2>&1 || { fail "oci CLI is available"; return 1; }
  command -v jq >/dev/null 2>&1 || { fail "jq is available"; return 1; }
  command -v ssh-keygen >/dev/null 2>&1 || { fail "ssh-keygen is available"; return 1; }

  discover_context

  TMPDIR="$(mktemp -d)"
  WORKDIR="$TMPDIR/module"
  cp -R "$MODULE_DIR" "$WORKDIR"
  ssh-keygen -q -t rsa -b 3072 -N "" -f "$TMPDIR/sprint26.key"

  cat > "$WORKDIR/terraform.tfvars" <<EOF
region = "$REGION"
compartment_id = "$COMPARTMENT_ID"
availability_domain = "$AVAILABILITY_DOMAIN"
subnet_id = "$SUBNET_ID"
image_id = "$IMAGE_ID"
ssh_public_key_path = "$TMPDIR/sprint26.key.pub"

name_prefix = "bv4db-s26-vanilla"
compute_shape = "VM.Standard.E5.Flex"
compute_ocpus = 16
compute_memory_gb = 64
assign_public_ip = true
volume_size_gbs = 1500
volume_vpus_per_gb = 120
device_path = "/dev/oracleoci/oraclevdb"
EOF

  write_evidence_header

  terraform -chdir="$WORKDIR" init -input=false
  terraform -chdir="$WORKDIR" validate
  terraform -chdir="$WORKDIR" apply -auto-approve -input=false

  local is_multipath multipath_count iscsi_state attachment_id result
  result="NEGATIVE"
  for _ in $(seq 1 30); do
    terraform -chdir="$WORKDIR" apply -refresh-only -auto-approve -input=false >/dev/null
    is_multipath="$(attachment_json | jq -r '.is_multipath // "null"')"
    multipath_count="$(attachment_json | jq -r '(.multipath_devices // []) | length')"
    iscsi_state="$(attachment_json | jq -r '.iscsi_login_state // "null"')"
    echo "poll is_multipath=$is_multipath multipath_devices=$multipath_count iscsi_login_state=$iscsi_state"
    if [ "$is_multipath" = "true" ] && [ "$multipath_count" -ge 2 ]; then
      result="PASS"
      break
    fi
    sleep 20
  done

  attachment_id="$(terraform -chdir="$WORKDIR" output -raw volume_attachment_id)"

  {
    echo "=== terraform outputs ==="
    terraform -chdir="$WORKDIR" output
    echo
    echo "=== attachment state json ==="
    attachment_json
    echo
    echo "=== OCI attachment get ==="
    oci compute volume-attachment get --volume-attachment-id "$attachment_id"
    echo
  } >> "$EVIDENCE" 2>&1

  append_guest_evidence || true

  if [ "$result" = "PASS" ]; then
    if grep -q '^mpath' "$EVIDENCE" && grep -q 'active.*ready.*running' "$EVIDENCE"; then
      echo "RESULT=PASS" >> "$EVIDENCE"
    else
      result="NEGATIVE"
      echo "RESULT=NEGATIVE" >> "$EVIDENCE"
      echo "negative_reason=OCI_MULTIPATH_TRUE_BUT_GUEST_EVIDENCE_INCOMPLETE" >> "$EVIDENCE"
    fi
  else
    echo "RESULT=NEGATIVE" >> "$EVIDENCE"
    echo "negative_reason=ATTACHMENT_NOT_MULTIPATH_ENABLED" >> "$EVIDENCE"
  fi

  echo "Evidence: $EVIDENCE"
  pass "live vanilla probe recorded RESULT=$result"
}

echo "=== Sprint 26 vanilla Oracle-documented UHP attachment integration ==="

require_file "$MODULE_DIR/versions.tf"
require_file "$MODULE_DIR/variables.tf"
require_file "$MODULE_DIR/main.tf"
require_file "$MODULE_DIR/outputs.tf"
require_file "$MODULE_DIR/README.md"
require_contains "$MODULE_DIR/main.tf" 'Block Volume Management' "module enables Block Volume Management plugin"
require_contains "$MODULE_DIR/main.tf" 'resource[[:space:]]+"oci_core_volume_attachment"[[:space:]]+"uhp"' "module uses native Terraform attachment"
require_contains "$MODULE_DIR/main.tf" 'device[[:space:]]+=' "module sets persistent device path"
require_contains "$MODULE_DIR/variables.tf" '/dev/oracleoci/oraclevd\[b-z\]' "module validates persistent device path"
require_not_contains "$MODULE_DIR/main.tf" 'raw-request|terraform_data|isMultipath|is_agent_auto_iscsi_login_enabled|iscsiadm|mpathconf|multipath\.conf' "module has no helper, auto-login flag, or guest setup"
require_tree_not_contains "$MODULE_DIR" 'is_agent_auto_iscsi_login_enabled|iscsiadm[[:space:]]+--login|mpathconf[[:space:]]+--enable' "module tree has no bypass/setup commands"

if [ "$FAIL" -eq 0 ]; then
  live_probe || fail "live vanilla probe failed to execute"
fi

echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
