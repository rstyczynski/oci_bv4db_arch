# Sprint 24 - Design

Status: Proposed

## Overview

Sprint 24 validates an OCI-supported multipath approach where the Oracle Cloud Agent **Block Volume Management** plugin is the primary mechanism that configures and maintains multipath-enabled iSCSI attachments. The sprint also defines a single evidence checklist and troubleshooting flow that reconciles “OCI plugin signals” with “guest observable reality”.

Primary references:

- `https://docs.oracle.com/iaas/Content/Block/Tasks/enablingblockvolumemanagementplugin.htm`
- `https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/configuringmultipathattachments.htm`
- `https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/multipathcheck.htm`
- `https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/troubleshootingmultipathattachments.htm`

## BV4DB-56. Validate simplified multipath setup fully managed by OCI Block Volume Management plugin

### Intended Outcome

Provide an execution path that:

- uses OCI-recommended configuration for multipath-enabled iSCSI attachments on a supported image
- relies on the Oracle Cloud Agent Block Volume Management plugin to perform the multipath-related configuration and attachment maintenance
- archives evidence that multipath is actually present and used (sessions, mapper device, mount source)

### Feasibility and Risks

- The plugin operates based on instance metadata and supported images; custom guest-side layouts and permission changes can produce misleading warnings.
- The sprint must treat the plugin UI output as *one signal* and validate against guest evidence.
- Live verification requires OCI access; if unavailable, the sprint will deliver runnable procedures and mark live gates **NOT RUN** with a short reason.

## BV4DB-57. Define and validate evidence checklist for OCI agent-managed multipath

### Evidence Model

Define a checklist that is satisfied only when **all** of the following are true for the target attachment:

- guest iSCSI sessions exist for the attachment
- dm-multipath mapping exists for the attachment (mapper device)
- filesystem is mounted from the mapper device (not a raw single-path device)
- plugin is enabled and its logs do not show repeated failure loops (or if warnings exist, the checklist explains how to reconcile them)

## Testing Strategy

#### Recommended Sprint Parameters

- **Test:** integration — work is primarily end-to-end scripts + documentation + evidence capture procedure.
- **Regression:** integration — reuse the existing integration suite and ensure no test runner regressions.

#### Integration Test Scenarios (Local / Offline)

- Verify Sprint 24 progress artifacts exist (setup/design/implementation/tests/manual).
- Verify Sprint 24 manual contains required sections and cites Oracle documentation references.
- Verify any Sprint 24 scripts exist and parse (bash syntax).

#### Integration Test Scenarios (Live / OCI)

These require OCI credentials and capacity:

- Provision an instance and UHP block volume attachment that is multipath-enabled per Oracle docs.
- Enable Block Volume Management plugin and allow it to configure multipath.
- Collect and archive evidence checklist artifacts and plugin log extracts.

## Test Specification

Sprint Test Configuration:

- Test: integration
- Mode: YOLO

### Integration Tests

#### IT-24-01: Sprint 24 progress artifacts exist

- **Preconditions:** none
- **Expected Outcome:** required Sprint 24 files are present
- **Target file:** `tests/integration/test_sprint24_oci_agent_multipath.sh`

#### IT-24-02: Manual includes oracle references and verification sections

- **Preconditions:** none
- **Expected Outcome:** manual contains required headings and cites Oracle docs used by the sprint
- **Target file:** `tests/integration/test_sprint24_oci_agent_multipath.sh`

#### IT-24-03: Sprint 24 scripts parse without errors (if present)

- **Preconditions:** none
- **Expected Outcome:** `bash -n` succeeds for all Sprint 24 scripts
- **Target file:** `tests/integration/test_sprint24_oci_agent_multipath.sh`

