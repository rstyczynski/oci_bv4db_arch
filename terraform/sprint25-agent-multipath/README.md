# Sprint 25 - Minimal Terraform Agent-Managed UHP Multipath

This directory is a minimal Terraform expression of the Sprint 24 approach. Terraform creates a clean Oracle Linux instance with the Oracle Cloud Agent **Block Volume Management** plugin enabled, creates a UHP block volume, and then invokes the OCI API shape required for a multipath-enabled iSCSI attachment.

The OCI Terraform provider currently exposes `is_multipath` on `oci_core_volume_attachment` as computed-only, so the final attachment is created through a Terraform-managed helper script using `oci raw-request` with `isMultipath: true`. The helper sanitizes CHAP fields before writing local attachment evidence.

## Usage

```bash
cd terraform/sprint25-agent-multipath
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
```

Update `terraform.tfvars` with real OCIDs before planning against OCI. Use `progress/sprint_1/state-bv4db.json` and the Sprint 24 manual as the source for region, compartment, subnet, and key material.

## Validation

```bash
terraform fmt -check
terraform validate
terraform plan -refresh=false
```

The `-refresh=false` plan is a structure check. It proves the configuration is internally plannable without querying OCI for current resource state.

## Relationship To Sprint 24

This Terraform setup intentionally keeps the same operator boundary as Sprint 24:

- clean instance per validation run
- Block Volume Management plugin enabled before attachment
- UHP volume at `120` VPUs/GB
- multipath-enabled iSCSI attachment requested through OCI API
- no custom guest `iscsiadm --login`, `mpathconf --enable`, or hand-written `multipath.conf`

After apply, validate guest reality with the Sprint 24 checklist in `progress/sprint_24/sprint24_manual.md`.
