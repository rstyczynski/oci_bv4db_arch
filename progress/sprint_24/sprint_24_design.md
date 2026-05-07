# Sprint 24 - Design

## BV4DB-56. Validate simplified multipath setup fully managed by OCI Block Volume Management plugin

Status: Accepted

### Requirement Summary

Validate a simplified path where OCI Block Volume Management plugin manages UHP iSCSI multipath attachment setup, instead of custom guest-side iSCSI login or custom `multipath.conf` policy steps.

### Feasibility Analysis

Oracle documents the plugin as required for UHP iSCSI multipath attachments. The plugin checks instance metadata, installs device-mapper multipath when needed, creates `/etc/multipath.conf` only for multipath-enabled attachments, and performs iSCSI login commands for matching attachments.

The OCI attachment must still be created as multipath-enabled and verified through the control plane. Oracle documents the `is-multipath` attachment property and the Console Multipath column as authoritative control-plane indicators, but Sprint 24 must also verify guest reality with sessions, mapper device, and mount.

### Design Overview

- Add `tools/run_bv4db_oci_agent_multipath_sprint24.sh`.
- Reuse existing scaffold provisioning for compute and block volume lifecycle.
- Reuse Sprint 1 shared infrastructure only for compartment, subnet, SSH key material, and region autodiscovery.
- Create or adopt a Sprint 24-specific compute instance from `NAME_PREFIX=bv4db-s24-agent`; do not reuse a previous sprint compute by default.
- Enable `Block Volume Management` on the instance before volume attachment.
- Create a UHP iSCSI attachment with `isMultipath:true` and a consistent device path.
- Do not run custom `iscsiadm --login`, `mpathconf --enable`, or custom `multipath.conf` policy writes.
- Wait for plugin-created iSCSI sessions and dm-multipath mapper.
- Mount the agent-managed device and capture evidence.

### Clean Instance Rationale

`progress/sprint_1/state-bv4db.json` is the shared infrastructure source for region, compartment, subnet, SSH key secret, and public key, but it does not carry a reusable compute or block volume baseline. Sprint 24 intentionally uses a Sprint 24-specific compute instance so the Oracle Cloud Agent Block Volume Management plugin is validated on a clean guest state. Reusing an older sprint instance could leave pre-existing iSCSI sessions, `/etc/multipath.conf`, `multipathd` state, or mounted filesystems that would weaken the plugin-managed validation.

### Testing Strategy

#### Recommended Sprint Parameters

- **Test:** integration - validates scripts, docs, manifest, and runner contract.
- **Regression:** integration - repository only supports integration gates through `tests/run.sh`.

#### Unit Test Targets

| Component | Functions to Test | Key Inputs & Edge Cases | Isolation (Mocks) |
| --------- | ----------------- | ----------------------- | ----------------- |
| None | None | Shell runner is validated through integration syntax and contract checks | None |

#### Integration Test Scenarios

| Scenario | Infrastructure Dependencies | Expected Outcome | Est. Runtime |
| -------- | --------------------------- | ---------------- | ------------ |
| Static Sprint 24 runner validation | Local repository | Runner exists, parses, enables plugin, avoids custom login/config, docs contain checklist | < 10 sec |
| Live OCI agent-managed validation | OCI tenancy, Sprint 1 shared infra, SSH key secret, supported shape/image | Evidence file reports `RESULT=PASS` | 20-40 min |

#### Smoke Test Candidates

| Candidate | Why Critical | Expected Runtime |
| --------- | ------------ | ---------------- |
| None | Sprint configuration requests integration only | n/a |

### Success Criteria

- Runner captures control-plane attachment JSON with `is-multipath=true`.
- Guest evidence shows at least two iSCSI sessions, at least one mapper, at least two active ready paths, and a mounted filesystem.
- Manual checklist maps failures to Oracle-supported troubleshooting paths.

## BV4DB-57. Define and validate evidence checklist for OCI agent-managed multipath

Status: Accepted

### Requirement Summary

Create one operator-facing evidence checklist that prevents false positives where the plugin or control plane reports success but guest reality does not show multipath.

### Design Overview

- Add `progress/sprint_24/sprint24_manual.md`.
- Checklist combines:
  - plugin desired/running state
  - control-plane `is-multipath`
  - plugin log status
  - iSCSI sessions
  - node startup values
  - `multipath -ll`
  - `multipathd show paths`
  - mapper-backed mount
- Troubleshooting covers missing sessions, missing mapper device, plugin warnings, and control-plane/guest contradiction.

### Testing Strategy

Same as `BV4DB-56`; the Sprint 24 integration test verifies that the manual contains the checklist and troubleshooting anchors.

## Test Specification

Sprint Test Configuration:

- Test: integration
- Mode: YOLO

### Integration Tests

#### IT-1: Sprint 24 runner exists and is executable

- **Preconditions:** repository checkout.
- **Steps:** inspect `tools/run_bv4db_oci_agent_multipath_sprint24.sh`.
- **Expected Outcome:** file exists and is executable.
- **Verification:** `tests/integration/test_sprint24_oci_agent_multipath.sh`.
- **Target file:** `tests/integration/test_sprint24_oci_agent_multipath.sh`

#### IT-2: Sprint 24 runner syntax is valid

- **Preconditions:** bash available.
- **Steps:** run `bash -n` on the runner.
- **Expected Outcome:** syntax check passes.
- **Verification:** integration test.
- **Target file:** `tests/integration/test_sprint24_oci_agent_multipath.sh`

#### IT-3: Runner follows agent-managed contract

- **Preconditions:** repository checkout.
- **Steps:** scan runner for plugin enablement, evidence capture, and prohibited custom login/config patterns.
- **Expected Outcome:** plugin path is present and custom guest multipath setup is absent.
- **Verification:** integration test.
- **Target file:** `tests/integration/test_sprint24_oci_agent_multipath.sh`

#### IT-4: Manual contains evidence checklist and troubleshooting

- **Preconditions:** Sprint 24 manual exists.
- **Steps:** scan manual for checklist and failure-mode sections.
- **Expected Outcome:** required operator sections are present.
- **Verification:** integration test.
- **Target file:** `tests/integration/test_sprint24_oci_agent_multipath.sh`

#### IT-5: New tests manifest registers Sprint 24 test

- **Preconditions:** `progress/sprint_24/new_tests.manifest` exists.
- **Steps:** check for `integration:test_sprint24_oci_agent_multipath.sh`.
- **Expected Outcome:** manifest entry exists.
- **Verification:** integration test.
- **Target file:** `tests/integration/test_sprint24_oci_agent_multipath.sh`

### Traceability

| Backlog Item | Smoke | Unit Tests | Integration Tests |
| ------------ | ----- | ---------- | ----------------- |
| BV4DB-56 | n/a | n/a | IT-1, IT-2, IT-3, IT-5 |
| BV4DB-57 | n/a | n/a | IT-4, IT-5 |

## YOLO Mode Decisions

### Decision 1: Keep Plugin-Owned Guest Setup

**Context:** Prior scripts manually logged into iSCSI targets and configured multipath.
**Decision Made:** Sprint 24 runner only waits for agent-created sessions and mapper state.
**Rationale:** The backlog item is specifically about validating the plugin-managed path.
**Alternatives Considered:** Reuse Sprint 20 guest login helper.
**Risk:** Medium; if the plugin prerequisites are missing, the run fails instead of repairing the guest manually.
