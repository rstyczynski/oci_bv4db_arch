# Sprint 26 - Design

## BV4DB-60. Vanilla Oracle-documented Terraform UHP attachment probe

Status: Accepted

### Requirement Summary

Run a fresh, vanilla Terraform validation of Oracle's documented UHP iSCSI multipath behavior. The probe must include only documented prerequisites: UHP volume, capable compute shape, enabled Block Volume Management plugin, network access to Oracle services, IAM prerequisites, and an explicit persistent device path on the attachment.

### Feasibility Analysis

Oracle documents that UHP volume attachments must be multipath-enabled for optimal performance and that the Block Volume service attempts to enable multipath during attachment when prerequisites are satisfied. Oracle also documents that the Block Volume Management plugin checks instance metadata for multipath-enabled UHP attachments, installs multipath configuration only when needed, and performs iSCSI login commands from matching metadata.

Terraform can model the compute instance, plugin desired state, UHP volume, persistent device path, and native iSCSI attachment. Terraform cannot set `is_multipath` directly in the provider resource, so the test result must be based on live attachment metadata and guest evidence.

Official references:

- <https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/configuringmultipathattachments.htm>
- <https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/enablingblockvolumemanagementplugin.htm>
- <https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/multipathcheck.htm>
- <https://docs.oracle.com/en-us/iaas/Content/Block/References/consistentdevicepaths.htm>

### Design Overview

- Add `terraform/sprint26-vanilla-uhp-attachment/`.
- Use a native `oci_core_volume_attachment` only.
- Keep `device = var.device_path`.
- Do not use raw API helpers.
- Do not set `is_agent_auto_iscsi_login_enabled`.
- Do not run guest `iscsiadm`, `mpathconf`, `multipath.conf` writes, or filesystem/LVM commands.
- Integration test creates a temporary working copy, applies live OCI infrastructure, waits for attachment metadata, captures guest evidence when possible, and destroys resources by default.

### Testing Strategy

- **Test:** integration
- **Mode:** YOLO

The new-code integration gate runs a live OCI apply from clean temporary state. Positive result requires OCI `is_multipath=true`, non-empty `multipath_devices`, and guest evidence of agent-managed multipath. Negative result is accepted only if the test archives exact OCI and guest evidence explaining why vanilla behavior did not produce multipath.

## Test Specification

Sprint Test Configuration:

- Test: integration
- Mode: YOLO

### Integration Tests

#### IT-1: Vanilla Terraform contract is clean

- **Preconditions:** repository checkout.
- **Steps:** inspect the Sprint 26 module.
- **Expected Outcome:** module contains UHP volume, Block Volume Management plugin, native attachment with persistent device path, and no helper or guest setup commands.
- **Verification:** `tests/integration/test_sprint26_vanilla_uhp_attachment.sh`.
- **Target file:** `tests/integration/test_sprint26_vanilla_uhp_attachment.sh`

#### IT-2: Live vanilla OCI run records outcome

- **Preconditions:** OCI CLI/Terraform configured, Sprint 1 state exists, quota available.
- **Steps:** apply the module from a clean temp state, refresh attachment metadata, inspect OCI and guest evidence, and destroy by default.
- **Expected Outcome:** test records either `RESULT=PASS` with multipath evidence or `RESULT=NEGATIVE` with exact failing metadata.
- **Verification:** timestamped A3 log and evidence file under `progress/sprint_26/`.
- **Target file:** `tests/integration/test_sprint26_vanilla_uhp_attachment.sh`

### Traceability

| Backlog Item | Smoke | Unit Tests | Integration Tests |
| ------------ | ----- | ---------- | ----------------- |
| BV4DB-60 | n/a | n/a | IT-1, IT-2 |
