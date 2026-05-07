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
