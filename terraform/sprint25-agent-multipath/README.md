# Sprint 25 - Minimal Terraform Agent-Managed UHP Multipath

This directory is a minimal Terraform expression of the Sprint 24 approach. Terraform creates a clean Oracle Linux instance with the Oracle Cloud Agent **Block Volume Management** plugin enabled, creates a UHP block volume, and then invokes the OCI API shape required for a multipath-enabled iSCSI attachment.

The OCI Terraform provider currently exposes `is_multipath` on `oci_core_volume_attachment` as computed-only, so the final attachment is created through a Terraform-managed helper script using `oci raw-request` with `isMultipath: true`. The helper sanitizes CHAP fields before writing local attachment evidence.

The attachment must use an OCI consistent device path such as `/dev/oracleoci/oraclevdb`. Oracle documents that device paths are required for Ultra High Performance volume attachments, and Terraform passes `var.device_path` into the attachment request. Do not build filesystems, mounts, or LVM layouts on transient `/dev/sdX` names.

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

## Existing Data Volumes

For an existing host that already used explicit `iscsiadm` login commands and Linux LVM, reattaching with persistent paths must preserve existing LVM metadata. The safe sequence is to verify data before the change, reattach the same volumes with `/dev/oracleoci/oraclevd*` paths, then rediscover and reactivate the existing LVM stack.

Before detaching, create and checksum a sentinel file on every mounted filesystem that will be affected:

```bash
mount_point="/u02/oradata"
sentinel="${mount_point}/.bv4db-persistent-path-sentinel"
sudo sh -c "date -u > '$sentinel'"
sudo sha256sum "$sentinel" | tee /tmp/bv4db-sentinel.sha256
sudo pvs -o+pv_uuid,devices | tee /tmp/bv4db-pvs.before
sudo vgs | tee /tmp/bv4db-vgs.before
sudo lvs -a -o+devices | tee /tmp/bv4db-lvs.before
sudo blkid | tee /tmp/bv4db-blkid.before
```

After OCI detach/reattach with persistent paths, reactivate existing LVM metadata only:

```bash
sudo pvscan
sudo vgscan
sudo vgchange -ay
sudo pvs -o+pv_uuid,devices | tee /tmp/bv4db-pvs.after
sudo vgs | tee /tmp/bv4db-vgs.after
sudo lvs -a -o+devices | tee /tmp/bv4db-lvs.after
sudo mount -a
sha256sum -c /tmp/bv4db-sentinel.sha256
```

Do not run `pvcreate`, `vgcreate`, `lvcreate`, or `mkfs` on existing data volumes unless the intent is to reinitialize data. The expected operation is LVM rediscovery/reactivation, not LVM recreation.
