# Sprint 29 - Design

## BV4DB-71. Operator runbook for single-path to multipath conversion

Status: Accepted

### Requirement Summary

Deliver an operator runbook that safely converts an existing single-path OCI block-volume attachment to an OCI Agent-managed multipath attachment on a new compute instance. The volume attachment already has its persistent device path set. The runbook must preserve existing data, state the OCI prerequisites, provide verification and recovery guidance, and use Sprint 24 as the baseline for the multipath target state.

### Feasibility Analysis

Oracle documents that a UHP iSCSI attachment must be multipath-enabled, and that the Block Volume Management plugin installs the multipath stack, creates its configuration, and performs iSCSI logins after the required instance, network, IAM, and attachment prerequisites are met. Sprint 24 captured the expected plugin-created mapper and paths; Sprint 27 captured the required clean detach-update-reattach transition and checksum preservation. A documentation-only implementation is therefore feasible without changing the plugin-owned guest configuration.

The conversion cannot be performed in place merely by increasing VPUs on an attached single-path volume. The runbook must treat the storage release and OCI detach/reattach as a planned outage, and must fail closed if the attachment does not report `is-multipath=true` or the guest does not show the plugin-created mapper and active paths.

### Design Overview

Create one operator-facing runbook in the Sprint 29 artifacts. It will use Sprint 24 as the target-state reference and Sprint 27 as the data-preservation reference.

#### Goals

- Convert an existing OCI block-volume attachment from single-path to OCI Agent-managed multipath.
- Keep the existing persistent attachment device path.
- Preserve the existing data on the block volume.
- Restore a minimal mounted filesystem after the transition and prove a test file is unchanged.
- Validate or reject the hypothesis that Terraform/OCI automatically performs the detach–reattach required for the UHP multipath transition.
- Give the operator a minimal, repeatable Terraform procedure and clear success/failure evidence.

#### Terraform Configuration Requirements

- Use Terraform as the only mechanism that changes OCI configuration.
- Create the compute instance from scratch with Terraform-provided cloud-init user data.
- Update the desired volume performance to Ultra High Performance in Terraform.
- Update the desired compute shape configuration to at least 16 OCPUs in Terraform.

Terraform/provider lifecycle reconciliation is hypothesized to perform the required attachment transition. The operator does not issue separate Terraform stop, detach, attach, or start operations unless the live validation rejects that hypothesis.

#### Detach–Reattach Hypothesis

Sprint 29 must validate whether applying the Terraform UHP and compute-capacity change causes the OCI provider/service to detach and reattach the block volume automatically with the existing persistent device path.

- **Confirmed:** The final runbook keeps the Terraform-only lifecycle procedure and records evidence that the provider/service completed the required transition.
- **Rejected:** The final runbook explicitly requires a manual detach and reattach as a prerequisite for the Terraform transition, records why declarative reconciliation was insufficient, and retains the same data-preservation and validation gates.

Until the live validation establishes the outcome, the runbook must not claim that automatic detach–reattach is guaranteed.

The runbook must not use OCI CLI or Console to change the volume, shape, attachment, or compute lifecycle configuration.

Terraform code must not contain `local-exec`, `remote-exec`, or any other provisioner. The new instance's first-boot mount/test setup is delivered declaratively through the OCI instance `user_data` metadata for cloud-init, not through a Terraform provisioner.

#### Transition Sequence

The operator will use Terraform to execute the following sequence:

1. Create and attach a non-UHP, single-path block volume with its persistent device path.
2. Create the compute instance from scratch with Terraform cloud-init, the Block Volume Management plugin enabled, and the minimal mount/test configuration.
3. Start the compute instance through Terraform and wait for the initial single-path filesystem mount.
4. Create a minimal test file on the mounted filesystem and record its SHA-256 checksum.
5. Shut down the Linux instance cleanly, allowing the operating system to release the mounted filesystem.
6. Apply the Terraform configuration that changes the volume to UHP and the compute shape to at least 16 OCPUs.
7. Observe whether the OCI Terraform provider and OCI service perform the required attachment lifecycle reconciliation using the unchanged persistent device path; record whether the detach–reattach hypothesis is confirmed or rejected.
8. Wait for the reconciled compute instance to start.
9. Verify OCI control-plane multipath activation first, then verify OCI Agent guest setup, multipath mapper, and filesystem mount.
10. Read the test file from the mounted filesystem and confirm its SHA-256 checksum is unchanged.

#### Minimal Filesystem and Data Test Requirements

- Use Terraform-provided cloud-init on the new compute instance to create an `/etc/fstab` entry for the existing persistent device path.
- Install a boot-time mount action that waits for OCI Agent to remap that persistent path to `/dev/mapper/mpath*`, then mounts the existing filesystem through it.
- Cloud-init must not manually configure iSCSI or multipath; it configures only the mount behavior after the OCI Agent-owned setup is ready.
- Before the transition, create one small test file on that filesystem and record its SHA-256 checksum.
- After Terraform reattaches the volume and starts the instance, confirm the filesystem is mounted at the expected mount point, the test file exists, and its SHA-256 checksum is unchanged.
- Treat a missing mount, missing test file, or checksum mismatch as a failed transition; do not restore the workload.

#### Primary Multipath-Activation Validation

The runbook will make OCI control-plane validation the first acceptance layer. After Terraform has completed the reattachment, the operator must confirm that the attachment is multipath-enabled before relying on any guest operating-system result. OCI CLI and Console are verification-only interfaces in this procedure.

- **OCI Console:** Open the block volume, select **Attached instances**, and confirm that the attachment's **Multipath** column reports **Yes**.
- **OCI CLI:** Retrieve the specific volume attachment and confirm that `data.is-multipath` is `true`.
- If either control-plane check does not confirm multipath, stop the procedure and correct the Terraform configuration or required prerequisites before starting the workload.

#### Secondary Linux Validation

After the compute instance starts and OCI control-plane multipath is confirmed, the runbook will use Linux checks only as secondary evidence that the OCI Agent has completed the guest-side work.

- Confirm the OCI Agent Block Volume Management plugin is running.
- Confirm the existing persistent device path resolves to a `/dev/mapper/mpath*` device.
- Confirm `multipath -ll` shows the mapper with multiple active paths.
- Confirm the minimal filesystem is mounted through the multipath-backed device.
- Confirm the test file exists at the expected mount point and its recorded SHA-256 checksum matches before restoring writes.

#### Automatic OCI Agent Responsibilities

- Discover the UHP multipath attachment after the instance starts.
- Create the required iSCSI sessions.
- Configure and activate dm-multipath.
- Remap the existing persistent device path to the multipath-backed mapper device.

Operators must not substitute manual iSCSI login, `mpathconf`, or custom multipath-policy writes for this agent-managed path.

#### Data-Preservation Requirements

- Treat the transition as an attachment and Linux-device-presentation change; it does not reformat or recreate the block volume.
- Confirm a clean, safe detach before continuing; do not force-detach production data.
- Validate the mounted filesystem, test-file presence, and recorded SHA-256 checksum only after the OCI Agent has established the multipath-backed device.
- Create the fstab entry only on the new compute instance; do not alter the existing block volume's filesystem or data.

### Error Handling

- If a prerequisite fails, stop before detach and correct the Terraform UHP/shape configuration, plugin, IAM, or service-network prerequisite.
- If the volume is not safely released, stop before Terraform detaches it; do not force a production detach.
- If OCI does not report `is-multipath=true`, or guest validation does not show a mapper and multiple active paths, do not restore the workload.
- If data validation fails after reattachment, keep the storage read-only and follow the documented recovery/escalation path.

### Testing Strategy

#### Recommended Sprint Parameters

- **Test:** integration — a static integration test will verify the completed operator runbook contains the required safety, OCI Agent, validation, and recovery sections.
- **Regression:** integration — the project’s available regression suite is integration-only.

#### Unit Test Targets

| Component | Functions to Test | Key Inputs & Edge Cases | Isolation |
| --- | --- | --- | --- |
| None | Documentation-only deliverable | Not applicable | Not applicable |

#### Integration Test Scenarios

| Scenario | Infrastructure Dependencies | Expected Outcome | Est. Runtime |
| --- | --- | --- | --- |
| Static runbook contract | Repository checkout | Runbook cites the Sprint 24 agent-managed baseline and contains safe transition, validation, and recovery guidance | < 5 sec |

#### Smoke Test Candidates

| Candidate | Why Critical | Expected Runtime |
| --- | --- | --- |
| None | Sprint configuration specifies integration only | Not applicable |

**Success Criteria:** The runbook gives an operator a clear, non-destructive Terraform-only configuration path from a single-path attachment to the Sprint 24 OCI Agent-managed multipath state, restores a minimal mounted filesystem, and proves the test file checksum is unchanged. The static integration test verifies all required sections.

### Documentation Requirements

- Explain the scope boundary: Terraform performs all OCI configuration changes; the plugin configures guest iSCSI and dm-multipath after instance start; OCI CLI and Console are used only to verify state.
- State that the existing persistent device path is retained and that volume data is preserved after a clean detach and successful post-change validation.
- Define the cloud-init-created fstab/mount behavior and minimal test-file checksum procedure.
- Include the control-plane and guest evidence required before restoring writes.
- Put OCI Console/CLI activation confirmation before all Linux-level diagnostic checks.
- Cite Oracle documentation and the relevant Sprint 24 and Sprint 27 artifacts.

### Open Design Questions

None.

## Test Specification

Sprint Test Configuration:

- Test: integration
- Mode: managed

### Integration Tests

#### IT-1: Operator runbook covers the Agent-managed conversion contract

- **Preconditions:** Repository checkout.
- **Steps:** Inspect the Sprint 29 operator runbook for the Sprint 24 baseline, Terraform-only configuration changes, fresh-compute cloud-init fstab/mount configuration, the documented detach–reattach hypothesis outcome, clean release before detach, OCI Console or CLI `is-multipath=true` confirmation before Linux checks, OCI Agent ownership, multiple active paths, mounted filesystem, test-file checksum validation, and recovery guidance.
- **Expected Outcome:** All required safety and target-state markers are present.
- **Verification:** `tests/integration/test_sprint29_multipath_runbook.sh`.
- **Target file:** `tests/integration/test_sprint29_multipath_runbook.sh`.

### Traceability

| Backlog Item | Smoke | Unit Tests | Integration Tests |
| --- | --- | --- | --- |
| BV4DB-71 | Not applicable | Not applicable | IT-1 |

## Design Approval Status

Awaiting Review
