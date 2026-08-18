# Sprint 28 - Setup

## Contract

Sprint 28 implements BV4DB-63 and BV4DB-70 in managed mode. The sprint must produce a reusable Linux block-volume preparation script for OCI iSCSI block volumes that is idempotent, data-safe, and compatible with non-multipath volumes, volumes moved from non-multipath to UHP multipath, and resized volumes.

The Sprint 27 TC4 clean Linux procedure is the baseline transition scenario. Sprint 28 must preserve that behavior while replacing ad hoc initialization fragments with a reusable script and a 360-degree diagnostics harness.

## Analysis

BV4DB-63 exists because the current operator fragment mixes first-time initialization with reconnect logic. In particular, a pattern such as `pvs "$DEV" || wipefs/pvcreate` is unsafe during reconnect, path transition, or multipath remapping because a temporary path failure can be mistaken for a new empty volume.

Sprint 27 already proved these baseline facts:

- Non-UHP iSCSI attachments may require manual Linux iSCSI login unless OCI auto-connect was selected.
- After manual login, the OCI consistent path may appear and point to the single-path device, for example `/dev/oracleoci/oraclevdb -> ../sdb`.
- After detach, VPU update to `100`, and UHP reattach, the OCI agent and multipath stack can remap the same consistent path to the multipath mapper, for example `/dev/oracleoci/oraclevdb -> /dev/mapper/mpatha -> /dev/dm-2`.
- Data preservation depends on clean Linux release before detach and rediscovery through the correct post-reattach path.

The new script must implement one automatic ensure workflow:

- Connect non-MP iSCSI if needed.
- Use `iscsiadm` to create or update only the requested Open-iSCSI node record under `/etc/iscsi/nodes/` and preserve unrelated records; do not edit node database files directly.
- Wait for the OCI consistent path and resolve it to either a single-path or multipath device.
- Discover whether the volume is already initialized.
- Activate and mount existing LVM/filesystem metadata without destructive commands.
- Support one PV and one VG per OCI block volume, with one or more LVs and mount points in that VG.
- Initialize a blank volume only when an explicit `--allow-initialize-empty` permission is provided.
- Grow resized storage only after the larger device size is visible and existing metadata is healthy.
- Collect complete evidence on every run, with a diagnostics-only option for no-mutation inspection.

The sprint is managed because the script can destroy production data if the design is wrong. Construction must wait for design approval.

## Compatibility Notes

The implementation should reuse Sprint 27 remote evidence helpers where possible, but it should not embed large inline remote scripts in the main integration test. The evidence harness must keep Terraform and OCI command logs in plain ASCII/no-color mode.

## Open Questions

None at setup time. The design below makes conservative assumptions and requires approval before construction.
