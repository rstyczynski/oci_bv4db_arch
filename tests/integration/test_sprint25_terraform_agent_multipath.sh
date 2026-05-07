#!/usr/bin/env bash
# Integration checks for Sprint 25 minimal Terraform agent-managed multipath setup.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MODULE_DIR="$REPO_ROOT/terraform/sprint25-agent-multipath"
NATIVE_MODULE_DIR="$REPO_ROOT/terraform/sprint25-agent-multipath-native"

pass=0
fail=0

record_pass() {
  echo "PASS: $1"
  pass=$((pass + 1))
}

record_fail() {
  echo "FAIL: $1" >&2
  fail=$((fail + 1))
}

require_file() {
  local path="$1"
  if [ -f "$path" ]; then
    record_pass "file exists: ${path#$REPO_ROOT/}"
  else
    record_fail "missing file: ${path#$REPO_ROOT/}"
  fi
}

require_contains() {
  local path="$1"
  local pattern="$2"
  local label="$3"
  if grep -Eq "$pattern" "$path"; then
    record_pass "$label"
  else
    record_fail "$label"
  fi
}

require_not_contains() {
  local path="$1"
  local pattern="$2"
  local label="$3"
  if grep -Eq "$pattern" "$path"; then
    record_fail "$label"
  else
    record_pass "$label"
  fi
}

run_step() {
  local label="$1"
  shift
  if "$@"; then
    record_pass "$label"
  else
    record_fail "$label"
  fi
}

terraform_output_json() {
  terraform -chdir="$NATIVE_MODULE_DIR" show -json
}

native_attachment_json() {
  terraform_output_json \
    | jq -e '.values.root_module.resources[]
      | select(.address == "oci_core_volume_attachment.uhp_native")
      | .values'
}

native_ssh_key_path() {
  awk -F= '
    $1 ~ /^[[:space:]]*ssh_public_key_path[[:space:]]*$/ {
      value=$2
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      gsub(/^"|"$/, "", value)
      print value
      exit
    }
  ' "$NATIVE_MODULE_DIR/terraform.tfvars"
}

native_guest_check() {
  local instance_id public_ip key_path
  instance_id="$(terraform -chdir="$NATIVE_MODULE_DIR" output -raw instance_id)"
  public_ip="$(oci compute instance list-vnics \
    --instance-id "$instance_id" \
    --query 'data[0]."public-ip"' \
    --raw-output)"
  key_path="$(native_ssh_key_path)"
  case "$key_path" in
    /*) ;;
    *) key_path="$NATIVE_MODULE_DIR/$key_path" ;;
  esac

  ssh -i "$key_path" \
    -o BatchMode=yes \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o ConnectTimeout=20 \
    "opc@$public_ip" 'bash -s' <<'REMOTE'
set -euo pipefail
sudo systemctl is-active oracle-cloud-agent >/dev/null
sudo test -f /etc/multipath.conf
sessions="$(sudo iscsiadm -m session 2>/dev/null | wc -l | awk "{print \$1}")"
[ "$sessions" -ge 2 ]
sudo multipath -ll | grep -q '^mpath'
paths="$(sudo multipathd show paths | awk '/active[[:space:]]+ready[[:space:]]+running/ { count++ } END { print count + 0 }')"
[ "$paths" -ge 2 ]
REMOTE
}

native_live_validation() {
  [ -f "$NATIVE_MODULE_DIR/terraform.tfvars" ] || {
    echo "missing live variables: terraform/sprint25-agent-multipath-native/terraform.tfvars" >&2
    return 1
  }
  command -v oci >/dev/null 2>&1 || {
    echo "oci CLI is required for live integration validation" >&2
    return 1
  }
  command -v jq >/dev/null 2>&1 || {
    echo "jq is required for live integration validation" >&2
    return 1
  }

  terraform -chdir="$NATIVE_MODULE_DIR" init -input=false
  terraform -chdir="$NATIVE_MODULE_DIR" validate
  terraform -chdir="$NATIVE_MODULE_DIR" plan -input=false
  terraform -chdir="$NATIVE_MODULE_DIR" apply -auto-approve -input=false
  terraform -chdir="$NATIVE_MODULE_DIR" apply -refresh-only -auto-approve -input=false

  local attachment_json is_multipath multipath_count iscsi_state
  attachment_json="$(native_attachment_json)"
  is_multipath="$(jq -r '.is_multipath // "null"' <<<"$attachment_json")"
  multipath_count="$(jq -r '(.multipath_devices // []) | length' <<<"$attachment_json")"
  iscsi_state="$(jq -r '.iscsi_login_state // "null"' <<<"$attachment_json")"

  echo "native live is_multipath=$is_multipath"
  echo "native live multipath_devices=$multipath_count"
  echo "native live iscsi_login_state=$iscsi_state"

  [ "$is_multipath" = "true" ] || return 1
  [ "$multipath_count" -ge 2 ] || return 1
  native_guest_check
}

echo "=== Sprint 25 Terraform agent-managed multipath integration ==="

require_file "$MODULE_DIR/versions.tf"
require_file "$MODULE_DIR/variables.tf"
require_file "$MODULE_DIR/main.tf"
require_file "$MODULE_DIR/outputs.tf"
require_file "$MODULE_DIR/terraform.tfvars.example"
require_file "$MODULE_DIR/README.md"
require_file "$MODULE_DIR/scripts/create_multipath_attachment.sh"
require_file "$MODULE_DIR/scripts/detach_multipath_attachment.sh"
require_file "$NATIVE_MODULE_DIR/versions.tf"
require_file "$NATIVE_MODULE_DIR/variables.tf"
require_file "$NATIVE_MODULE_DIR/main.tf"
require_file "$NATIVE_MODULE_DIR/outputs.tf"
require_file "$NATIVE_MODULE_DIR/terraform.tfvars.example"
require_file "$NATIVE_MODULE_DIR/README.md"
require_file "$REPO_ROOT/progress/sprint_25/sprint25_native_manual.md"

if [ -x "$MODULE_DIR/scripts/create_multipath_attachment.sh" ] \
  && [ -x "$MODULE_DIR/scripts/detach_multipath_attachment.sh" ]; then
  record_pass "helper scripts are executable"
else
  record_fail "helper scripts are executable"
fi

require_contains "$MODULE_DIR/main.tf" 'Block Volume Management' "instance enables Block Volume Management plugin"
require_contains "$MODULE_DIR/main.tf" 'vpus_per_gb' "UHP volume performance is Terraform-configured"
require_contains "$MODULE_DIR/main.tf" 'resource[[:space:]]+"terraform_data"[[:space:]]+"multipath_attachment"' "Terraform owns multipath attachment helper lifecycle"
require_contains "$MODULE_DIR/scripts/create_multipath_attachment.sh" 'isMultipath:[[:space:]]+true' "attachment helper requests isMultipath true"
require_contains "$MODULE_DIR/scripts/create_multipath_attachment.sh" 'del\(\.data\."chap-secret", \.data\."chap-username"\)' "attachment helper sanitizes CHAP fields"
require_contains "$MODULE_DIR/README.md" 'computed-only' "README documents OCI provider multipath limitation"
require_contains "$MODULE_DIR/README.md" 'Sprint 24' "README links Terraform example to Sprint 24 validation"
require_contains "$NATIVE_MODULE_DIR/main.tf" 'resource[[:space:]]+"oci_core_volume_attachment"[[:space:]]+"uhp_native"' "native module uses OCI Terraform volume attachment"
require_contains "$NATIVE_MODULE_DIR/main.tf" 'is_agent_auto_iscsi_login_enabled' "native module enables agent auto iSCSI login option"
require_contains "$NATIVE_MODULE_DIR/outputs.tf" 'is_multipath' "native module exposes computed is_multipath output"
require_contains "$NATIVE_MODULE_DIR/README.md" 'no-helper probe' "native README explains no-helper purpose"
require_contains "$NATIVE_MODULE_DIR/README.md" 'is_multipath.*true|is-multipath=true' "native README defines live multipath pass condition"
require_contains "$REPO_ROOT/progress/sprint_25/sprint25_native_manual.md" 'terraform apply' "native manual includes apply step"
require_contains "$REPO_ROOT/progress/sprint_25/sprint25_native_manual.md" 'terraform output is_multipath' "native manual includes multipath output check"
require_contains "$REPO_ROOT/progress/sprint_25/sprint25_native_manual.md" 'terraform apply -refresh-only' "native manual refreshes state outputs before output check"
require_contains "$REPO_ROOT/progress/sprint_25/sprint25_native_manual.md" 'terraform state show oci_core_volume_attachment\.uhp_native' "native manual includes Terraform state fallback"
require_contains "$REPO_ROOT/progress/sprint_25/sprint25_native_manual.md" 'terraform show -json' "native manual includes JSON state fallback"
require_contains "$REPO_ROOT/progress/sprint_25/sprint25_native_manual.md" 'sudo multipath -ll' "native manual includes guest multipath check"
require_contains "$REPO_ROOT/progress/sprint_25/sprint25_native_manual.md" 'sudo sed -n.* /etc/multipath\.conf' "native manual includes multipath.conf check"
require_contains "$REPO_ROOT/progress/sprint_25/sprint25_native_manual.md" 'terraform destroy' "native manual includes destroy step"
require_contains "$REPO_ROOT/progress/sprint_25/sprint25_native_manual.md" 'cat > terraform\.tfvars <<EOF' "native manual writes terraform.tfvars directly"
require_contains "$REPO_ROOT/progress/sprint_25/sprint25_native_manual.md" 'oci iam availability-domain list' "native manual autodiscovers availability domain"
require_contains "$REPO_ROOT/progress/sprint_25/sprint25_native_manual.md" 'oci compute image list' "native manual autodiscovers image"

for path in "$MODULE_DIR/main.tf" "$MODULE_DIR/scripts/create_multipath_attachment.sh"; do
  require_not_contains "$path" 'iscsiadm[[:space:]]+--login|mpathconf[[:space:]]+--enable|multipath\.conf' "no custom guest multipath setup in ${path#$REPO_ROOT/}"
done

require_not_contains "$NATIVE_MODULE_DIR/main.tf" 'raw-request|terraform_data|isMultipath:[[:space:]]+true|iscsiadm[[:space:]]+--login|mpathconf[[:space:]]+--enable' "native module has no raw API helper or guest setup"

if command -v terraform >/dev/null 2>&1; then
  run_step "terraform fmt check" terraform -chdir="$MODULE_DIR" fmt -check -recursive
  run_step "terraform init" terraform -chdir="$MODULE_DIR" init -backend=false -input=false
  run_step "terraform validate" terraform -chdir="$MODULE_DIR" validate
  run_step "native terraform fmt check" terraform -chdir="$NATIVE_MODULE_DIR" fmt -check -recursive
  run_step "native terraform init" terraform -chdir="$NATIVE_MODULE_DIR" init -backend=false -input=false
  run_step "native terraform validate" terraform -chdir="$NATIVE_MODULE_DIR" validate

  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' EXIT
  key_path="$tmpdir/test.pub"
  printf 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC7 sprint25@example\n' > "$key_path"

  run_step "terraform structural plan" terraform -chdir="$MODULE_DIR" plan \
    -refresh=false \
    -input=false \
    -var='region=eu-zurich-1' \
    -var='compartment_id=ocid1.compartment.oc1..aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' \
    -var='availability_domain=example:EU-ZURICH-1-AD-1' \
    -var='subnet_id=ocid1.subnet.oc1.eu-zurich-1.aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' \
    -var='image_id=ocid1.image.oc1.eu-zurich-1.aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' \
    -var="ssh_public_key_path=$key_path"

  run_step "native live Terraform OCI multipath validation" native_live_validation
else
  record_fail "terraform CLI is available"
fi

echo "Results: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
