# Sprint 25 - Implementation Notes

## Implementation Overview

**Sprint Status:** failed live integration for BV4DB-59

**Backlog Items:**

- BV4DB-58: implemented
- BV4DB-59: implemented as probe, failed live acceptance

## BV4DB-58. Minimal Terraform setup for OCI agent-managed UHP multipath

Status: implemented, live validation not proven

### Implementation Summary

Added `terraform/sprint25-agent-multipath/` as a standalone Terraform example for the Sprint 24 topology. The module creates a clean compute instance with Oracle Cloud Agent Block Volume Management enabled, creates a UHP block volume, and uses a Terraform-managed OCI API helper to create a multipath-enabled iSCSI attachment.

### Code Artifacts

| Artifact | Purpose | Status |
| -------- | ------- | ------ |
| `terraform/sprint25-agent-multipath/versions.tf` | Terraform and OCI provider constraints | Complete |
| `terraform/sprint25-agent-multipath/variables.tf` | Operator input contract | Complete |
| `terraform/sprint25-agent-multipath/main.tf` | Compute, UHP volume, and attachment orchestration | Complete |
| `terraform/sprint25-agent-multipath/outputs.tf` | Instance, volume, attachment state, and device outputs | Complete |
| `terraform/sprint25-agent-multipath/terraform.tfvars.example` | Copy/edit variable template | Complete |
| `terraform/sprint25-agent-multipath/scripts/create_multipath_attachment.sh` | OCI API helper for `isMultipath: true` attachment | Complete |
| `terraform/sprint25-agent-multipath/scripts/detach_multipath_attachment.sh` | Attachment cleanup helper | Complete |
| `terraform/sprint25-agent-multipath/README.md` | Operator usage and validation notes | Complete |
| `tests/integration/test_sprint25_terraform_agent_multipath.sh` | Sprint 25 integration gate | Complete |

## BV4DB-59. Validate Terraform UHP attachment without raw API multipath helper

Status: implemented

### Implementation Summary

Added `terraform/sprint25-agent-multipath-native/` as a native Terraform-only probe. It keeps the same Sprint 24 topology assumptions but uses `oci_core_volume_attachment` directly and exposes computed `is_multipath` and `multipath_devices` outputs for the live verification.

Live refresh against the existing native state on 2026-05-07 returned `multipath_devices = []`, `is_multipath = null`, and `iscsi_login_state = "UNKNOWN"`. Therefore BV4DB-59 is implemented as a probe, but the no-helper hypothesis is not accepted as working.

### Code Artifacts

| Artifact | Purpose | Status |
| -------- | ------- | ------ |
| `terraform/sprint25-agent-multipath-native/versions.tf` | Terraform and OCI provider constraints | Complete |
| `terraform/sprint25-agent-multipath-native/variables.tf` | Operator input contract for native probe | Complete |
| `terraform/sprint25-agent-multipath-native/main.tf` | Compute, UHP volume, and native attachment resources | Complete |
| `terraform/sprint25-agent-multipath-native/outputs.tf` | Computed native attachment multipath outputs | Complete |
| `terraform/sprint25-agent-multipath-native/terraform.tfvars.example` | Copy/edit variable template | Complete |
| `terraform/sprint25-agent-multipath-native/README.md` | No-helper probe usage and pass criteria | Complete |
| `progress/sprint_25/sprint25_native_manual.md` | Copy/paste operator walkthrough for live native validation | Complete |

### User Documentation

```bash
cd terraform/sprint25-agent-multipath
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
```

After applying with real OCI values, use `progress/sprint_24/sprint24_manual.md` for guest validation.

#### Native No-Helper Probe

```bash
cd terraform/sprint25-agent-multipath-native
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
terraform output is_multipath
terraform output multipath_devices
```

The native path passes only if `is_multipath` is `true`, `multipath_devices` is populated, and the guest passes the Sprint 24 evidence checklist.

Current live result: native Terraform did not prove multipath. Keep using the helper module for validated agent-managed multipath until a later live run proves the native path.

### Known Issues

The available OCI Terraform provider schema does not set multipath directly on `oci_core_volume_attachment`; it reports multipath as computed state. The module therefore requires `oci` CLI and `jq` for the minimal attachment helper. This is documented in the README and in the Terraform comments.

The native module intentionally does not replace the helper module until a live OCI run proves that native Terraform attachment produces `is_multipath=true`.

## YOLO Mode Decisions

### Decision 1: Structural Plan Instead Of Live Apply In Gate

**Context:** Live OCI apply would allocate compute and storage during every repository regression run.
**Decision Made:** The gate runs `terraform plan -refresh=false` with dummy values and leaves live apply to the operator.
**Rationale:** It proves Terraform graph validity without cost or tenancy dependency.
**Risk:** Medium; live OCI behavior remains validated by Sprint 24 runner/manual.
