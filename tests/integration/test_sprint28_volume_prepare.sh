#!/usr/bin/env bash
# Sprint 28 integration test design for BV4DB-63 and BV4DB-70.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PASS=0
FAIL=0

PREP_SCRIPT="$REPO_ROOT/tools/oci_bv_prepare_volume.sh"
DIAG_SCRIPT="$REPO_ROOT/tools/oci_bv_360_diagnostics.sh"
DESIGN_DOC="$REPO_ROOT/progress/sprint_28/sprint_28_design.md"
MANIFEST="$REPO_ROOT/progress/sprint_28/new_tests.manifest"

fail() {
  echo "FAIL: $*" >&2
  FAIL=$((FAIL + 1))
}

pass() {
  echo "PASS: $*"
  PASS=$((PASS + 1))
}

require_file() {
  local path="$1"
  local label="$2"
  if [ -f "$path" ]; then
    pass "$label"
  else
    fail "$label"
  fi
}

require_executable() {
  local path="$1"
  local label="$2"
  if [ -x "$path" ]; then
    pass "$label"
  else
    fail "$label"
  fi
}

require_contains() {
  local path="$1"
  local pattern="$2"
  local label="$3"
  if [ -f "$path" ] && grep -Eq -- "$pattern" "$path"; then
    pass "$label"
  else
    fail "$label"
  fi
}

require_not_contains() {
  local path="$1"
  local pattern="$2"
  local label="$3"
  if [ -f "$path" ] && grep -Eq -- "$pattern" "$path"; then
    fail "$label"
  else
    pass "$label"
  fi
}

require_manifest_entry() {
  local fn="$1"
  require_contains "$MANIFEST" "^integration:test_sprint28_volume_prepare\\.sh:${fn}$" "manifest registers $fn"
}

test_IT1_static_script_contract() {
  echo "=== IT-1: static script contract and destructive guardrails ==="
  require_manifest_entry test_IT1_static_script_contract
  require_file "$PREP_SCRIPT" "preparation script exists"
  require_executable "$PREP_SCRIPT" "preparation script is executable"
  require_file "$DIAG_SCRIPT" "360 diagnostics script exists"
  require_not_contains "$PREP_SCRIPT" '(^|[[:space:]])--mode([[:space:]]|$)' "script does not expose lifecycle mode option"
  require_not_contains "$PREP_SCRIPT" 'init-new|activate-existing|transition-to-mp' "script does not expose operator lifecycle modes"
  require_contains "$PREP_SCRIPT" '(^|[^[:alnum:]_-])--lv([^[:alnum:]_-]|$)|parse_lv' "script supports repeatable LV definitions"
  require_contains "$PREP_SCRIPT" 'allow-initialize-empty' "destructive initialization requires explicit permission"
  require_contains "$PREP_SCRIPT" 'diagnose-only|oci_bv_360_diagnostics' "script supports diagnostics-only execution"
  require_contains "$PREP_SCRIPT" 'plan-only|dry-run' "script supports non-mutating plan execution"
  require_not_contains "$PREP_SCRIPT" 'fdisk|parted|sfdisk|growpart|partprobe' "script does not manage partition tables"
  require_not_contains "$PREP_SCRIPT" 'systemctl stop|systemctl start|cp -a .*\\.ori|RequiresMountsFor' "script does not perform application migration or service orchestration"
}

test_IT2_single_instance_baseline_diagnostics() {
  echo "=== IT-2: single-instance provisioning and baseline diagnostics ==="
  require_manifest_entry test_IT2_single_instance_baseline_diagnostics
  require_file "$DIAG_SCRIPT" "360 diagnostics script exists"
  require_contains "$DESIGN_DOC" 'single compute instance|same instance' "design keeps live tests on one compute instance"
  require_contains "$DIAG_SCRIPT" 'IMDS|169\.254\.169\.254|metadata' "diagnostics include IMDS/MDS reachability"
  require_contains "$DIAG_SCRIPT" 'volumeAttachments|attachment|volume' "diagnostics include OCI volume attachment metadata"
  require_contains "$DIAG_SCRIPT" 'oracle-cloud-agent|oci-blockautoconfig' "diagnostics include Oracle Cloud Agent and block plugin"
  require_contains "$DIAG_SCRIPT" 'iscsiadm' "diagnostics include iSCSI state"
  require_contains "$DIAG_SCRIPT" 'multipath' "diagnostics include multipath state"
  require_contains "$DIAG_SCRIPT" 'pvs|vgs|lvs|vgscan|pvscan' "diagnostics include LVM state"
  require_contains "$DIAG_SCRIPT" 'findmnt|fstab|blkid|lsblk' "diagnostics include filesystem and mount state"
  require_contains "$DIAG_SCRIPT" 'journalctl|dmesg' "diagnostics include kernel or journal state"
  require_contains "$DIAG_SCRIPT" 'service gateway|Oracle Services Network|public IP|network' "diagnostics include network prerequisite evidence"
}

test_IT3_plan_only_fresh_empty_volume() {
  echo "=== IT-3: plan-only fresh empty volume ==="
  require_manifest_entry test_IT3_plan_only_fresh_empty_volume
  require_contains "$PREP_SCRIPT" 'plan-only|dry-run' "plan-only option exists"
  require_contains "$PREP_SCRIPT" 'planned|intended|summary' "plan-only writes planned action summary"
  require_contains "$PREP_SCRIPT" 'pvcreate|vgcreate|lvcreate|mkfs|fstab|mount' "plan covers initialization actions without executing them"
  require_contains "$PREP_SCRIPT" 'diagnose-only|oci_bv_360_diagnostics' "plan collects diagnostics before action selection"
}

test_IT4_empty_volume_guardrail() {
  echo "=== IT-4: empty volume fail-closed guardrail ==="
  require_manifest_entry test_IT4_empty_volume_guardrail
  require_contains "$PREP_SCRIPT" 'allow-initialize-empty' "initialization is explicitly gated"
  require_contains "$PREP_SCRIPT" 'wipefs|pvcreate|vgcreate|mkfs' "script identifies destructive initialization operations"
  require_contains "$PREP_SCRIPT" 'no signatures|empty|fail.*closed|unsupported' "empty volume without permission fails closed"
  require_not_contains "$PREP_SCRIPT" 'pvs .*\\|\\|.*wipefs|pvs .*\\|\\|.*pvcreate' "script does not treat pvs failure as permission to initialize"
}

test_IT5_fresh_single_lv_non_mp_initialization() {
  echo "=== IT-5: fresh single-LV non-MP initialization ==="
  require_manifest_entry test_IT5_fresh_single_lv_non_mp_initialization
  require_contains "$PREP_SCRIPT" 'iscsiadm' "script can connect non-MP iSCSI when required"
  require_contains "$PREP_SCRIPT" 'device-path|/dev/oracleoci|readlink|realpath' "script resolves requested consistent device path"
  require_contains "$PREP_SCRIPT" 'pvcreate' "script creates PV only for approved empty volume"
  require_contains "$PREP_SCRIPT" 'vgcreate' "script creates requested VG"
  require_contains "$PREP_SCRIPT" 'lvcreate' "script creates requested LV"
  require_contains "$PREP_SCRIPT" 'mkfs\\.xfs|mkfs\\.ext4' "script creates requested filesystem"
  require_contains "$PREP_SCRIPT" 'findmnt|mount' "script verifies and mounts requested mount point"
}

test_IT6_existing_single_lv_idempotent_rerun() {
  echo "=== IT-6: existing single-LV idempotent re-run ==="
  require_manifest_entry test_IT6_existing_single_lv_idempotent_rerun
  require_contains "$PREP_SCRIPT" 'pvs|vgs|lvs|blkid' "script detects existing LVM and filesystem metadata"
  require_contains "$PREP_SCRIPT" 'vgchange -ay|vgchange.*-ay' "script activates existing VG"
  require_contains "$PREP_SCRIPT" 'checksum|marker|verify' "script verifies preserved data marker"
  require_not_contains "$PREP_SCRIPT" 'mkfs.*existing|pvcreate.*existing|wipefs.*existing' "script does not reinitialize existing data"
}

test_IT7_multi_lv_non_mp_initialization() {
  echo "=== IT-7: multi-LV non-MP initialization ==="
  require_manifest_entry test_IT7_multi_lv_non_mp_initialization
  require_contains "$PREP_SCRIPT" '(^|[^[:alnum:]_-])--lv([^[:alnum:]_-]|$)|parse_lv' "script parses repeatable --lv specs"
  require_contains "$PREP_SCRIPT" 'lv-name|name=' "LV name is part of the requested layout"
  require_contains "$PREP_SCRIPT" 'size=' "LV size is part of the requested layout"
  require_contains "$PREP_SCRIPT" 'mount=' "LV mount point is part of the requested layout"
  require_contains "$PREP_SCRIPT" 'for .*lv|while .*lv|LV_SPECS|lv_specs' "script reconciles multiple LV specs"
}

test_IT8_multi_lv_idempotent_rerun() {
  echo "=== IT-8: multi-LV idempotent re-run ==="
  require_manifest_entry test_IT8_multi_lv_idempotent_rerun
  require_contains "$PREP_SCRIPT" 'lvs|findmnt|blkid' "script validates each existing LV/filesystem/mount"
  require_contains "$PREP_SCRIPT" 'ensure_lv|reconcile_lv|for .*lv|while .*lv' "script reconciles requested LVs independently"
  require_not_contains "$PREP_SCRIPT" 'sed -i .*fstab.*mount' "script does not broadly rewrite fstab by mount string"
  require_contains "$PREP_SCRIPT" 'managed|OCI_BV_PREPARE|fstab' "script owns only marked fstab entries"
}

test_IT9_single_lv_resize() {
  echo "=== IT-9: single-LV resize and filesystem growth ==="
  require_manifest_entry test_IT9_single_lv_resize
  require_contains "$PREP_SCRIPT" 'pvresize' "script can resize PV after OCI storage growth"
  require_contains "$PREP_SCRIPT" 'lvextend|lvresize' "script can extend requested LV"
  require_contains "$PREP_SCRIPT" 'xfs_growfs|resize2fs' "script grows supported filesystem online or safely"
  require_contains "$PREP_SCRIPT" 'checksum|marker|verify' "resize preserves checksum marker"
}

test_IT10_multi_lv_resize_all_free() {
  echo "=== IT-10: multi-LV resize with all-free policy ==="
  require_manifest_entry test_IT10_multi_lv_resize_all_free
  require_contains "$PREP_SCRIPT" 'grow-policy' "script supports explicit grow policy"
  require_contains "$PREP_SCRIPT" 'all-free|exact|none' "script supports defined growth policy values"
  require_contains "$PREP_SCRIPT" 'lvextend|lvresize' "growth applies to selected LV only"
  require_contains "$PREP_SCRIPT" 'lvs|vgs' "growth decisions inspect VG/LV free space"
}

test_IT11_non_mp_to_mp_lifecycle() {
  echo "=== IT-11: non-MP to MP lifecycle using Sprint 27 TC4 baseline ==="
  require_manifest_entry test_IT11_non_mp_to_mp_lifecycle
  require_contains "$DESIGN_DOC" 'Sprint 27 TC4' "design uses Sprint 27 TC4 as lifecycle baseline"
  require_contains "$PREP_SCRIPT" 'readlink|realpath|/dev/oracleoci' "script validates consistent path mapping"
  require_contains "$PREP_SCRIPT" 'multipath|/dev/mapper' "script accepts agent-managed multipath mapper after reattach"
  require_contains "$PREP_SCRIPT" 'iscsiadm.*logout|logout.*iscsiadm|umount|sync' "clean release procedure is represented"
  require_not_contains "$PREP_SCRIPT" 'transition-to-mp' "no operator transition mode exists"
}

test_IT12_reboot_persistence_and_reconcile() {
  echo "=== IT-12: reboot persistence and post-boot reconcile ==="
  require_manifest_entry test_IT12_reboot_persistence_and_reconcile
  require_contains "$PREP_SCRIPT" '_netdev|nofail|x-systemd.device-timeout' "fstab entries are boot safe"
  require_contains "$PREP_SCRIPT" 'persist-iscsi|node.startup|automatic' "script can persist non-MP iSCSI startup policy"
  require_contains "$PREP_SCRIPT" 'vgchange -ay|findmnt|mount' "script reconciles LVM and mount state after reboot"
  require_contains "$PREP_SCRIPT" 'checksum|marker|verify' "post-reboot checksum verification is represented"
}

test_IT13_open_iscsi_node_database_safe_use() {
  echo "=== IT-13: Open-iSCSI node database safe use ==="
  require_manifest_entry test_IT13_open_iscsi_node_database_safe_use
  require_contains "$PREP_SCRIPT" 'iscsiadm' "script uses iscsiadm for node operations"
  require_contains "$PREP_SCRIPT" '/etc/iscsi/nodes|iscsiadm -m node|node.startup' "script verifies Open-iSCSI node database state"
  require_contains "$PREP_SCRIPT" 'persist-iscsi|automatic|manual' "script exposes persistent iSCSI policy"
  require_not_contains "$PREP_SCRIPT" 'sed -i .*?/etc/iscsi/nodes|rm -rf .*?/etc/iscsi/nodes|cat > .*?/etc/iscsi/nodes' "script does not edit Open-iSCSI node DB files directly"
  require_contains "$DESIGN_DOC" 'Open-iSCSI node database safe use' "design documents safe Open-iSCSI node DB usage"
}

test_IT14_unsupported_partition_table_guardrail() {
  echo "=== IT-14: unsupported partition-table guardrail ==="
  require_manifest_entry test_IT14_unsupported_partition_table_guardrail
  require_contains "$PREP_SCRIPT" 'PTTYPE|parttable|partition|unsupported' "script detects partition-table layouts as unsupported"
  require_not_contains "$PREP_SCRIPT" 'fdisk|parted|sfdisk|growpart|partprobe' "script does not create or resize partition tables"
  require_contains "$PREP_SCRIPT" 'fail.*closed|unsupported|mismatch' "unsupported layout fails closed"
}

test_IT15_mount_point_non_empty_guardrail() {
  echo "=== IT-15: mount-point non-empty guardrail ==="
  require_manifest_entry test_IT15_mount_point_non_empty_guardrail
  require_contains "$PREP_SCRIPT" 'findmnt|mountpoint' "script checks mount-point state"
  require_contains "$PREP_SCRIPT" 'non-empty|empty directory|directory.*empty' "script detects non-empty unmounted mount points"
  require_not_contains "$PREP_SCRIPT" 'mv .*\\.ori|cp -a .*\\.ori|rm -rf .*mount' "script does not move or delete existing mount-point contents"
}

test_IT16_concurrent_run_lock() {
  echo "=== IT-16: concurrent run lock ==="
  require_manifest_entry test_IT16_concurrent_run_lock
  require_contains "$PREP_SCRIPT" 'flock|lockfile|lock_dir|lock-dir' "script uses a local run lock"
  require_contains "$PREP_SCRIPT" 'vg-name|device-path|lock key|lock_key' "lock is scoped to target VG or device"
  require_contains "$PREP_SCRIPT" 'lock.*conflict|already running|busy' "second invocation reports lock conflict"
}

test_IT17_secret_redaction() {
  echo "=== IT-17: secret redaction ==="
  require_manifest_entry test_IT17_secret_redaction
  require_contains "$PREP_SCRIPT" 'chap|secret|password' "script accepts or handles CHAP secret material"
  require_contains "$PREP_SCRIPT" 'redact|mask|sanitize' "script redacts secrets in logs and evidence"
  require_contains "$DIAG_SCRIPT" 'redact|mask|sanitize|chap|secret' "diagnostics redacts sensitive iSCSI material"
}

run_test() {
  local fn="$1"
  if declare -F "$fn" >/dev/null; then
    "$fn"
  else
    fail "unknown test function: $fn"
  fi
}

run_all() {
  test_IT1_static_script_contract
  test_IT2_single_instance_baseline_diagnostics
  test_IT3_plan_only_fresh_empty_volume
  test_IT4_empty_volume_guardrail
  test_IT5_fresh_single_lv_non_mp_initialization
  test_IT6_existing_single_lv_idempotent_rerun
  test_IT7_multi_lv_non_mp_initialization
  test_IT8_multi_lv_idempotent_rerun
  test_IT9_single_lv_resize
  test_IT10_multi_lv_resize_all_free
  test_IT11_non_mp_to_mp_lifecycle
  test_IT12_reboot_persistence_and_reconcile
  test_IT13_open_iscsi_node_database_safe_use
  test_IT14_unsupported_partition_table_guardrail
  test_IT15_mount_point_non_empty_guardrail
  test_IT16_concurrent_run_lock
  test_IT17_secret_redaction
}

echo "=== Sprint 28 idempotent volume preparation integration design ==="

if [ "$#" -gt 0 ]; then
  for selected in "$@"; do
    run_test "$selected"
  done
else
  run_all
fi

if [ "$FAIL" -ne 0 ]; then
  echo "Sprint 28 construction is not implemented yet; failing tests define the required design contract."
fi

echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
