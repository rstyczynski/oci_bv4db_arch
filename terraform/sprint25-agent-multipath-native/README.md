# Sprint 25 - Native Terraform Agent-Managed UHP Multipath Probe

This directory is the BV4DB-59 follow-up to `terraform/sprint25-agent-multipath/`. It keeps the existing helper-based module intact and adds a native Terraform-only probe that uses `oci_core_volume_attachment` instead of an OCI raw API helper.

Oracle documents two important behaviors that this module tests:

- for UHP volumes, the Block Volume service attempts to enable multipath while the volume is being attached when prerequisites are satisfied;
- the Block Volume Management plugin checks instance metadata for multipath-enabled UHP attachments, installs `device-mapper-multipath` and `/etc/multipath.conf` when needed, and performs iSCSI login commands.

The OCI Terraform provider still exposes `is_multipath` as computed state only. This module therefore cannot force multipath in HCL. A live apply is the test: after apply, the `is_multipath` output must be `true`, `multipath_devices` must be populated, and the guest must pass the Sprint 24 evidence checklist.

## Usage

```bash
cd terraform/sprint25-agent-multipath-native
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

Update `terraform.tfvars` with real OCIDs before planning against OCI. Use Sprint 1 state and the Sprint 24 manual as the source for region, compartment, subnet, image, and key values.

## Validation

```bash
terraform output is_multipath
terraform output multipath_devices
```

Expected result after live apply:

```text
is_multipath = true
multipath_devices = [
  ...
]
```

Then validate the guest with `progress/sprint_24/sprint24_manual.md`. The native path passes only if OCI reports `is-multipath=true` and the guest shows agent-created iSCSI sessions, an `mpath*` mapper, active ready running paths, and a mounted filesystem.

## Relationship To Existing Sprint 25 Module

- `terraform/sprint25-agent-multipath/` is the known-good helper path that explicitly sends `isMultipath: true` through OCI API.
- `terraform/sprint25-agent-multipath-native/` is the no-helper probe. It depends on OCI auto-enabling multipath from prerequisites and records the result through computed Terraform outputs.

## Official References

- <https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/configuringmultipathattachments.htm>
- <https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/enablingblockvolumemanagementplugin.htm>
- <https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/multipathcheck.htm>
