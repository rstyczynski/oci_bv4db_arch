# Sprint 27 - Design

## BV4DB-61. Multipath behavior after upgrading attached non-UHP volume to UHP

Status: Accepted

### Requirement Summary

Validate whether a volume attached while non-UHP gains multipath configuration after its VPU setting is changed to `100`.

### Feasibility Analysis

Terraform can create the baseline instance, block volume, and native iSCSI attachment. The OCI CLI can update the volume performance level during the integration test, allowing the test to capture before and after evidence without recreating the baseline resource graph.

Oracle documentation states that the Block Volume service attempts to enable multipath when the volume is being attached, and that attachments that do not satisfy prerequisites will not be multipath-enabled. Sprint 27 therefore detaches the initial non-UHP attachment before changing the volume to `100` VPUs/GB, then attaches the now-UHP volume so OCI can evaluate multipath at attachment time.

Official references:

- <https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/configuringmultipathattachments.htm>
- <https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/enablingblockvolumemanagementplugin.htm>
- <https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/connectingtoavolume_topic-Connecting_to_iSCSIAttached_Volumes.htm>
- <https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/connectingtouhpvolumes.htm>

### Design Overview

Add `terraform/sprint27-vpu-upgrade-multipath/` for the initial non-UHP topology. The Sprint 27 test matrix must distinguish OCI attachment lifecycle behavior from Linux guest operational safety:

1. Update an attached non-UHP volume from `20` to `100` VPUs/GB without detach. This is expected to be negative for multipath enablement.
2. Detach the non-UHP attachment, update the detached volume from `20` to `100` VPUs/GB, and reattach with the same persistent device path. This is expected to be positive for multipath enablement.
3. Detach, update, and reattach while a Linux filesystem/workload has not been cleanly released. This is expected to be negative or hazardous, and must use disposable data only.
4. Cleanly stop I/O at Linux level, flush writes, unmount or deactivate the storage stack, log out of the baseline iSCSI session when the baseline attachment was manually connected, detach, update, reattach, verify multipath, rediscover the post-reattach multipath-backed device, remount, and verify data integrity. The current evidence shows that clean unmount alone is not sufficient if the old device path is blindly reused after multipath reattach.

If a negative case behaves differently than expected, the result is still valid when the evidence explains the observed behavior.

### Testing Strategy

- **Test:** integration
- **Mode:** YOLO

## Test Specification

Sprint Test Configuration:

- Test: integration
- Mode: YOLO

### Integration Tests

#### IT-1: Module represents non-UHP baseline

- **Preconditions:** repository checkout.
- **Steps:** inspect the Sprint 27 Terraform module.
- **Expected Outcome:** module creates a non-UHP block volume, native attachment, enabled Block Volume Management plugin, and no guest iSCSI or multipath setup.
- **Verification:** `tests/integration/test_sprint27_vpu_upgrade_multipath.sh`.
- **Target file:** `tests/integration/test_sprint27_vpu_upgrade_multipath.sh`

#### IT-2: Live VPU upgrade records multipath outcome

- **Preconditions:** OCI CLI/Terraform configured, Sprint 1 state exists, quota available.
- **Steps:** apply the module, collect baseline evidence, detach the non-UHP attachment, update volume VPUs to `100`, attach the now-UHP volume using the same persistent device path, collect post-attach evidence, and destroy by default.
- **Expected Outcome:** test records whether multipath appears after the detach-update-attach path or remains absent, with exact OCI and guest evidence.
- **Verification:** timestamped A3 log and evidence file under `progress/sprint_27/`.
- **Target file:** `tests/integration/test_sprint27_vpu_upgrade_multipath.sh`

#### IT-3: In-place VPU update without detach is negative for multipath

- **Preconditions:** OCI CLI/Terraform configured, Sprint 1 state exists, quota available.
- **Steps:** create and attach a `20` VPUs/GB volume, collect baseline evidence, update the still-attached volume to `100` VPUs/GB, poll attachment metadata and guest state without detach or reattach.
- **Expected Outcome:** attachment remains non-multipath or otherwise does not become a valid UHP multipath attachment in place.
- **Verification:** timestamped A3 log and evidence file under `progress/sprint_27/`.
- **Target file:** `tests/integration/test_sprint27_tc1_inplace_negative.sh`

#### IT-4: Detach-update-reattach is positive for multipath

- **Preconditions:** OCI CLI/Terraform configured, Sprint 1 state exists, quota available.
- **Steps:** create and attach a `20` VPUs/GB volume, detach the attachment, update the detached volume to `100` VPUs/GB, reattach with `/dev/oracleoci/oraclevdb`, poll attachment metadata and guest state.
- **Expected Outcome:** attachment reports `is_multipath=true` with multiple multipath devices, and guest evidence shows OCI agent-managed multipath state.
- **Verification:** timestamped A3 log and evidence file under `progress/sprint_27/`.
- **Target file:** `tests/integration/test_sprint27_tc2_detach_positive.sh`

#### IT-5: Detach-update-reattach without Linux release procedure is negative or hazardous

- **Preconditions:** disposable block volume data only; OCI CLI/Terraform configured, Sprint 1 state exists, quota available.
- **Steps:** create a filesystem or simple workload on the `20` VPUs/GB attachment, intentionally skip one or more Linux release steps such as workload stop, `sync`, unmount, or storage-stack deactivation, then attempt detach-update-reattach.
- **Expected Outcome:** test captures the observed failure mode, such as busy-device detach failure, stale device references, filesystem inconsistency, application I/O errors, or checksum/data loss on disposable data.
- **Verification:** timestamped A3 log and evidence file under `progress/sprint_27/`.
- **Target file:** `tests/integration/test_sprint27_tc3_linux_unsafe_negative.sh`

#### IT-6: Detach-update-reattach with Linux release procedure validates post-reattach device handling

- **Preconditions:** disposable block volume data only; OCI CLI/Terraform configured, Sprint 1 state exists, quota available.
- **Steps:** manually connect Linux to the non-UHP iSCSI attachment when auto-connect is not enabled, create a filesystem on the discovered `20` VPUs/GB attachment, write checksum-verifiable data, stop workload I/O, run `sync`, unmount or deactivate the storage stack, log out of iSCSI, detach, update to `100` VPUs/GB, reattach with `/dev/oracleoci/oraclevdb`, verify multipath, rediscover the multipath-backed block device, mount read-only, and verify checksums.
- **Expected Outcome:** test passes only when OCI reports a multipath-enabled UHP attachment and Linux verifies the original checksum through the discovered multipath-backed device. The production procedure must not assume the old baseline device path remains the mountable filesystem path after reattach.
- **Verification:** timestamped A3 log and evidence file under `progress/sprint_27/`.
- **Target file:** `tests/integration/test_sprint27_tc4_linux_clean_device_path.sh`

### Additional Candidate Tests

- Reboot after in-place VPU update without detach, to confirm whether reboot alone changes the attachment state.
- Detach-update-reattach with a changed device path, to validate whether persistent device path continuity matters for operator procedure.
- Reattach to a new instance after VPU update, to separate volume state from instance/agent state.
- Repeat the positive Linux procedure with LVM or ASM-like layering instead of a plain filesystem.

### Traceability

| Backlog Item | Smoke | Unit Tests | Integration Tests |
| ------------ | ----- | ---------- | ----------------- |
| BV4DB-61 | n/a | n/a | IT-1, IT-2, IT-3, IT-4, IT-5, IT-6 |
