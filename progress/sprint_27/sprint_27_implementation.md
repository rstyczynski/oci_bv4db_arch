# Sprint 27 - Implementation Notes

## Implementation Overview

**Sprint Status:** tested

**Backlog Items:**

- BV4DB-61: implemented
- BV4DB-62: implemented

## BV4DB-61. Multipath behavior after upgrading attached non-UHP volume to UHP

Added `terraform/sprint27-vpu-upgrade-multipath/` to create the baseline non-UHP attachment using native Terraform resources.

Added `tests/integration/test_sprint27_vpu_upgrade_multipath.sh` to run the live lifecycle probe, detach the initial non-UHP attachment, update the detached volume to `100` VPUs/GB, attach the now-UHP volume, and archive before/after OCI and guest evidence.

## BV4DB-62. Linux-level clean procedure for non-UHP to UHP reattach operation

Covered by the Sprint 27 TC3 and TC4 scenarios. TC3 captures the unsafe Linux procedure against disposable data, while TC4 performs the clean procedure: manual iSCSI login for the non-UHP baseline, consistent-path wait, filesystem creation, checksum write, sync, unmount, iSCSI logout, OCI detach, VPU update, UHP reattach, passive wait for the OCI agent and multipath stack, consistent-path validation, read-only mount, and checksum verification.

The operator guidance is documented in `progress/sprint_27/linux_level_operations.md`.

Oracle references used by the implementation:

- <https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/configuringmultipathattachments.htm>
- <https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/enablingblockvolumemanagementplugin.htm>

## YOLO Decisions

### Decision 1: Negative Result Can Pass If Evidence Is Complete

**Context:** The backlog item asks whether multipath appears after the VPU update.
**Decision Made:** The integration script exits successfully when it records a conclusive positive or negative lifecycle result with evidence.
**Rationale:** The sprint's purpose is discovery of provider/agent behavior, not forcing multipath success.
**Risk:** Medium; downstream readers must distinguish a successful probe from positive multipath behavior.

### Decision 2: Detach Before VPU Update

**Context:** Oracle documents multipath enablement as attachment-time behavior.
**Decision Made:** The Sprint 27 flow detaches the original non-UHP attachment before changing VPUs to `100`, then attaches the now-UHP volume with the same persistent device path.
**Rationale:** This aligns the test with Oracle's documented attachment-time multipath behavior.
**Risk:** Medium; the attachment OCID changes, so evidence must preserve both pre-detach and post-attach metadata.
