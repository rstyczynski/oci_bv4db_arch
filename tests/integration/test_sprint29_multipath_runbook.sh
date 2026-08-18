#!/usr/bin/env bash
# Integration test for the Sprint 29 single-path to OCI Agent-managed multipath runbook.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RUNBOOK="$REPO_ROOT/progress/sprint_29/operator_runbook.md"

pass=0
fail=0

check() {
  local pattern="$1"
  local description="$2"
  if grep -qi -- "$pattern" "$RUNBOOK"; then
    echo "  [PASS] $description"
    pass=$((pass + 1))
  else
    echo "  [FAIL] $description"
    fail=$((fail + 1))
  fi
}

check_absent() {
  local pattern="$1"
  local description="$2"
  if grep -qi -- "$pattern" "$RUNBOOK"; then
    echo "  [FAIL] $description"
    fail=$((fail + 1))
  else
    echo "  [PASS] $description"
    pass=$((pass + 1))
  fi
}

echo "=== IT-1: Sprint 29 operator runbook ==="

if [ ! -f "$RUNBOOK" ]; then
  echo "  [FAIL] missing operator runbook: $RUNBOOK"
  exit 1
fi

check 'Sprint 24' 'uses Sprint 24 as the OCI Agent-managed baseline'
check 'Terraform' 'uses Terraform for configuration changes'
check 'operator-controlled Compute `STOP` and `START`' 'uses OCI CLI only for approved lifecycle actions'
check 'provisioner' 'prohibits Terraform provisioners'
check 'Terraform detach' 'uses Terraform for the controlled detach operation'
check 'terraform show -json' 'discovers target attachments from Terraform state'
check 'volume_attachment_resources' 'handles every discovered attachment'
check 'persistent_device_paths' 'discovers every configured persistent device path'
check 'TRACE_PATH' 'retains operator evidence in TRACE_PATH'
check 'mp_switch' 'defaults TRACE_PATH to the dated mp_switch directory'
check_absent 'VOLUME_ATTACHMENT_RESOURCE=' 'does not require a manual attachment resource address'
check_absent 'PERSISTENT_DEVICE_PATH=' 'does not require a single manual persistent path'
check_absent 'Run Command' 'does not require guest-level validation at this stage'
check 'Block Volume Management' 'identifies the OCI Agent plugin'
check 'is_multipath' 'requires OCI control-plane multipath confirmation'
check 'Critical lifecycle requirement' 'records the OCI attach lifecycle prerequisite'
check 'Do not attempt the attachment-create Terraform apply while the' 'fails closed on stopped-instance attachment creation'
check 'OCI Console' 'provides OCI Console activation validation'
check 'OCI CLI' 'provides OCI CLI activation validation'
check 'unmount' 'requires safe storage release before detach'
check 'multipath_devices' 'requires OCI to report the multipath device list'
check 'Do not modify `/etc/fstab`' 'keeps the existing fstab unchanged'
check 'OCI CLI output from step 7' 'uses OCI control-plane evidence for this stage'
check 'recovery' 'includes recovery guidance'

echo "Results: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
