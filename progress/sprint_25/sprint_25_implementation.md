# Sprint 25 - Implementation Notes

## Implementation Overview

**Sprint Status:** implemented

**Backlog Items:**

- BV4DB-58: implemented

## BV4DB-58. Minimal Terraform setup for OCI agent-managed UHP multipath

Status: implemented

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

### User Documentation

```bash
cd terraform/sprint25-agent-multipath
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
```

After applying with real OCI values, use `progress/sprint_24/sprint24_manual.md` for guest validation.

### Known Issues

The available OCI Terraform provider schema does not set multipath directly on `oci_core_volume_attachment`; it reports multipath as computed state. The module therefore requires `oci` CLI and `jq` for the minimal attachment helper. This is documented in the README and in the Terraform comments.

## YOLO Mode Decisions

### Decision 1: Structural Plan Instead Of Live Apply In Gate

**Context:** Live OCI apply would allocate compute and storage during every repository regression run.
**Decision Made:** The gate runs `terraform plan -refresh=false` with dummy values and leaves live apply to the operator.
**Rationale:** It proves Terraform graph validity without cost or tenancy dependency.
**Risk:** Medium; live OCI behavior remains validated by Sprint 24 runner/manual.
