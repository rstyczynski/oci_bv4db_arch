# Sprint 25 - Design

## BV4DB-58. Minimal Terraform setup for OCI agent-managed UHP multipath

Status: Accepted

### Requirement Summary

Create a small Terraform example that represents the Sprint 24 agent-managed UHP multipath topology for operators who want to compare the validated shell-runner approach with infrastructure-as-code.

### Feasibility Analysis

Terraform supports the compute instance, agent plugin configuration, UHP volume sizing, VNIC, and outputs needed by this sprint. The current OCI provider schema exposes `is_multipath` on `oci_core_volume_attachment` as computed-only, so Terraform cannot directly set the multipath flag through the standard attachment resource. Sprint 25 therefore uses a minimal `terraform_data` local-exec helper that calls the OCI API with `isMultipath: true`, matching the Sprint 24 validated API shape.

### Design Overview

- Add `terraform/sprint25-agent-multipath/`.
- Configure the OCI provider from explicit variables.
- Create one Oracle Linux instance with `Block Volume Management` plugin desired state enabled.
- Create one UHP block volume with `vpus_per_gb = 120` by default.
- Create the multipath attachment through a Terraform-managed helper script using `oci raw-request`.
- Sanitize CHAP fields before writing local attachment JSON evidence.
- Document that guest validation remains the Sprint 24 manual checklist.

### Testing Strategy

#### Recommended Sprint Parameters

- **Test:** integration - validates Terraform syntax, planability, helper contracts, docs, and manifests.
- **Regression:** integration - repository quality gates are integration-script based.

#### Integration Test Scenarios

| Scenario | Infrastructure Dependencies | Expected Outcome | Est. Runtime |
| -------- | --------------------------- | ---------------- | ------------ |
| Static Terraform module validation | Terraform, OCI provider cache/download path | `terraform fmt`, `terraform validate`, and dummy `terraform plan -refresh=false` pass | 1-3 min |
| Helper contract validation | Local repository, `bash`, `jq` text inspection | Helper requests `isMultipath: true` and sanitizes CHAP fields | < 10 sec |
| Documentation validation | Local repository | README documents Sprint 24 relationship and provider limitation | < 10 sec |

### Success Criteria

- Terraform module is small and self-contained.
- `terraform plan -refresh=false` succeeds with documented variables.
- README explains how the module maps to Sprint 24.
- No guest-side custom `iscsiadm --login`, `mpathconf --enable`, or custom `multipath.conf` policy appears in the Terraform module.

## Test Specification

Sprint Test Configuration:

- Test: integration
- Mode: YOLO

### Integration Tests

#### IT-1: Terraform module structure exists

- **Preconditions:** repository checkout.
- **Steps:** inspect `terraform/sprint25-agent-multipath/`.
- **Expected Outcome:** Terraform files, helper scripts, example variables, and README exist.
- **Verification:** `tests/integration/test_sprint25_terraform_agent_multipath.sh`.
- **Target file:** `tests/integration/test_sprint25_terraform_agent_multipath.sh`

#### IT-2: Terraform formatting and validation pass

- **Preconditions:** Terraform CLI available.
- **Steps:** run `terraform fmt -check -recursive`, `terraform init -backend=false -input=false`, and `terraform validate`.
- **Expected Outcome:** all commands pass.
- **Verification:** integration test.
- **Target file:** `tests/integration/test_sprint25_terraform_agent_multipath.sh`

#### IT-3: Terraform structural plan passes

- **Preconditions:** Terraform CLI available.
- **Steps:** run `terraform plan -refresh=false -input=false` with dummy OCIDs and a temporary public key.
- **Expected Outcome:** plan succeeds without contacting OCI resource APIs.
- **Verification:** integration test.
- **Target file:** `tests/integration/test_sprint25_terraform_agent_multipath.sh`

#### IT-4: Agent-managed multipath contract is preserved

- **Preconditions:** repository checkout.
- **Steps:** scan Terraform and helper scripts for plugin enablement, UHP volume settings, `isMultipath: true`, CHAP sanitization, and prohibited guest setup commands.
- **Expected Outcome:** Sprint 24 contract is present and custom guest multipath setup is absent.
- **Verification:** integration test.
- **Target file:** `tests/integration/test_sprint25_terraform_agent_multipath.sh`

### Traceability

| Backlog Item | Smoke | Unit Tests | Integration Tests |
| ------------ | ----- | ---------- | ----------------- |
| BV4DB-58 | n/a | n/a | IT-1, IT-2, IT-3, IT-4 |

## BV4DB-59. Validate Terraform UHP attachment without raw API multipath helper

Status: Accepted

### Requirement Summary

Add a second Sprint 25 Terraform module that uses only native OCI Terraform resources for the attachment path. The module tests whether OCI and the Block Volume Management plugin are sufficient to produce a multipath-enabled UHP attachment when all documented prerequisites are satisfied.

### Feasibility Analysis

Oracle documentation states that the Block Volume service attempts to enable multipath while a UHP volume is being attached when prerequisites are met. It also states that the Block Volume Management plugin discovers multipath-enabled UHP attachments from instance metadata, installs/configures multipath when needed, and performs iSCSI login commands.

The Terraform OCI provider supports `oci_core_volume_attachment` and computed outputs including `is_multipath` and `multipath_devices`. It does not provide an argument to force `is_multipath`, so the native module can only prove success through a live apply and post-apply evidence.

### Design Overview

- Add `terraform/sprint25-agent-multipath-native/`.
- Reuse the same compute, UHP volume, plugin, and variable model as the helper-based module.
- Use native `oci_core_volume_attachment` with `attachment_type = "iscsi"` and a consistent device path.
- Do not set `is_agent_auto_iscsi_login_enabled`; the Block Volume Management plugin must perform login and multipath setup from attachment metadata.
- Expose computed `is_multipath` and `multipath_devices` outputs.
- Do not use `terraform_data`, `oci raw-request`, or guest-side custom setup commands.
- Document the live pass criteria and fallback in both module README and an operator manual: if the native path does not produce `is_multipath=true`, keep the helper module and record the evidence as provider/native-path limitation.

### Testing Strategy

#### Integration Test Scenarios

| Scenario | Infrastructure Dependencies | Expected Outcome | Est. Runtime |
| -------- | --------------------------- | ---------------- | ------------ |
| Native Terraform module validation | Terraform and OCI provider cache/download path | `terraform fmt` and `terraform validate` pass | 1-3 min |
| Native contract validation | Local repository | Native module uses `oci_core_volume_attachment`, exposes computed multipath outputs, and contains no raw API helper | < 10 sec |
| Live native validation | OCI tenancy, Sprint 1 shared infra, Terraform live variables, OCI CLI, SSH | `terraform apply` output reports `is_multipath=true`, `multipath_devices` is non-empty, and guest passes Sprint 24 checklist | 20-40 min |
| Native operator manual validation | Local repository | Manual has copy/paste plan, apply, output, guest check, evidence, and destroy steps | < 10 sec |

### Success Criteria

- Native module is separate from the helper module.
- Live Terraform apply/refresh is executed against OCI for integration validation.
- README explains the no-helper hypothesis and exact pass/fail condition.
- Operator manual gives a complete copy/paste live validation path.
- Existing helper-based module remains available.

## Test Specification Addendum

### Integration Tests

#### IT-5: Native Terraform module structure exists

- **Preconditions:** repository checkout.
- **Steps:** inspect `terraform/sprint25-agent-multipath-native/`.
- **Expected Outcome:** Terraform files, example variables, and README exist.
- **Verification:** `tests/integration/test_sprint25_terraform_agent_multipath.sh`.
- **Target file:** `tests/integration/test_sprint25_terraform_agent_multipath.sh`

#### IT-6: Native Terraform live apply validates OCI multipath outputs

- **Preconditions:** Terraform CLI, OCI CLI, `jq`, Sprint 1 shared infra, and `terraform/sprint25-agent-multipath-native/terraform.tfvars` with real OCI values.
- **Steps:** run `terraform fmt -check -recursive`, `terraform init`, `terraform validate`, `terraform plan`, `terraform apply`, and `terraform apply -refresh-only`; inspect `oci_core_volume_attachment.uhp_native` state.
- **Expected Outcome:** all commands pass, `is_multipath=true`, and `multipath_devices` contains at least two devices.
- **Verification:** integration test.
- **Target file:** `tests/integration/test_sprint25_terraform_agent_multipath.sh`

#### IT-7: Native no-helper contract is preserved

- **Preconditions:** repository checkout.
- **Steps:** scan the native module for `oci_core_volume_attachment`, computed multipath outputs, and prohibited raw API or guest setup patterns.
- **Expected Outcome:** native module uses only OCI Terraform resources for attachment and documents live pass criteria.
- **Verification:** integration test.
- **Target file:** `tests/integration/test_sprint25_terraform_agent_multipath.sh`

### Traceability Addendum

| Backlog Item | Smoke | Unit Tests | Integration Tests |
| ------------ | ----- | ---------- | ----------------- |
| BV4DB-59 | n/a | n/a | IT-5, IT-6, IT-7 |
