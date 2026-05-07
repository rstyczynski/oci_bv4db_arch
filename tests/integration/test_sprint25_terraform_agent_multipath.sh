#!/usr/bin/env bash
# Integration checks for Sprint 25 minimal Terraform agent-managed multipath setup.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MODULE_DIR="$REPO_ROOT/terraform/sprint25-agent-multipath"

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

echo "=== Sprint 25 Terraform agent-managed multipath integration ==="

require_file "$MODULE_DIR/versions.tf"
require_file "$MODULE_DIR/variables.tf"
require_file "$MODULE_DIR/main.tf"
require_file "$MODULE_DIR/outputs.tf"
require_file "$MODULE_DIR/terraform.tfvars.example"
require_file "$MODULE_DIR/README.md"
require_file "$MODULE_DIR/scripts/create_multipath_attachment.sh"
require_file "$MODULE_DIR/scripts/detach_multipath_attachment.sh"

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

for path in "$MODULE_DIR/main.tf" "$MODULE_DIR/scripts/create_multipath_attachment.sh"; do
  require_not_contains "$path" 'iscsiadm[[:space:]]+--login|mpathconf[[:space:]]+--enable|multipath\.conf' "no custom guest multipath setup in ${path#$REPO_ROOT/}"
done

if command -v terraform >/dev/null 2>&1; then
  run_step "terraform fmt check" terraform -chdir="$MODULE_DIR" fmt -check -recursive
  run_step "terraform init" terraform -chdir="$MODULE_DIR" init -backend=false -input=false
  run_step "terraform validate" terraform -chdir="$MODULE_DIR" validate

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
else
  record_fail "terraform CLI is available"
fi

echo "Results: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
