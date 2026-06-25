# Sprint 25 - Native Terraform Agent-Managed Multipath Manual

## Purpose

This manual validates whether Terraform can create the Sprint 24 OCI agent-managed UHP multipath shape without the Sprint 25 raw API helper. The helper-based module remains available at `terraform/sprint25-agent-multipath/`; this manual is only for the native probe in `terraform/sprint25-agent-multipath-native/`.

## Prerequisites

- Run from the repository root.
- Sprint 1 shared infrastructure state exists at `progress/sprint_1/state-bv4db.json`.
- OCI CLI is configured for the tenancy used by Sprint 1.
- Terraform is installed.
- The selected image supports Oracle Cloud Agent and UHP multipath.
- The instance has public IP access or service gateway access to Oracle services.
- Dynamic group and policy allow Oracle Cloud Agent to inspect instances and volume attachments.
- VM shape has at least `16` OCPUs for UHP multipath.

## Step 1 - Prepare Terraform Variables

```bash
cd terraform/sprint25-agent-multipath-native

state="../../progress/sprint_1/state-bv4db.json"
region="${OCI_REGION:-$(jq -r '.inputs.oci_region // empty' "$state")}"
compartment_id="${COMPARTMENT_OCID:-$(jq -r '.compartment.ocid // .inputs.oci_compartment // empty' "$state")}"
subnet_id="${SUBNET_OCID:-$(jq -r '.subnet.ocid // empty' "$state")}"
availability_domain="${AVAILABILITY_DOMAIN:-$(oci iam availability-domain list \
  --compartment-id "$compartment_id" \
  --query 'data[0].name' \
  --raw-output)}"
image_id="${IMAGE_ID:-$(oci compute image list \
  --compartment-id "$compartment_id" \
  --operating-system 'Oracle Linux' \
  --shape VM.Standard.E5.Flex \
  --sort-by TIMECREATED \
  --sort-order DESC \
  --query 'data[0].id' \
  --raw-output)}"

cat > terraform.tfvars <<EOF
region = "$region"
compartment_id = "$compartment_id"
availability_domain = "$availability_domain"
subnet_id = "$subnet_id"
image_id = "$image_id"
ssh_public_key_path = "../../progress/sprint_1/bv4db-key.pub"

name_prefix = "bv4db-tf-agent-native"
compute_shape = "VM.Standard.E5.Flex"
compute_ocpus = 16
compute_memory_gb = 64
volume_size_gbs = 1500
volume_vpus_per_gb = 120
device_path = "/dev/oracleoci/oraclevdb"
EOF

cat terraform.tfvars
```

Expected output includes real OCIDs and one availability domain:

```text
region = "eu-zurich-1"
compartment_id = "ocid1.compartment..."
availability_domain = "..."
subnet_id = "ocid1.subnet..."
image_id = "ocid1.image..."
```

## Step 2 - Plan Native Terraform

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan
```

Expected result:

```text
Plan: 3 to add, 0 to change, 0 to destroy.
```

The plan must include:

```text
oci_core_instance.agent_multipath
oci_core_volume.uhp
oci_core_volume_attachment.uhp_native
```

## Step 3 - Apply Native Terraform

```bash
terraform apply
```

Expected result after confirmation:

```text
Apply complete!
```

## Step 4 - Check OCI Attachment Multipath Outputs

```bash
terraform apply -refresh-only
terraform output is_multipath
terraform output multipath_devices
terraform output volume_attachment_id
terraform output instance_id
```

Pass criteria:

```text
is_multipath = true
multipath_devices = [
  ...
]
```

If `is_multipath` is `false` or `multipath_devices` is empty, the native path did not prove the no-helper hypothesis. Keep using `terraform/sprint25-agent-multipath/` and record the result in Sprint 25 notes.

If Terraform reports `Output "is_multipath" not found`, the state was created before the output existed in this module. Run the `terraform apply -refresh-only` command above, approve the refresh-only operation, and then rerun the `terraform output` commands.

If the output is still missing, read the attachment resource directly from Terraform state:

```bash
terraform state show oci_core_volume_attachment.uhp_native \
  | egrep '^(id|instance_id|volume_id|is_multipath|multipath_devices)[[:space:]]+='

terraform show -json \
  | jq -r '
      .values.root_module.resources[]
      | select(.address == "oci_core_volume_attachment.uhp_native")
      | .values
      | {
          id,
          instance_id,
          volume_id,
          is_multipath,
          multipath_devices
        }
    '
```

The state fallback has the same pass criteria: `is_multipath` must be `true` and `multipath_devices` must be non-empty. If `is_multipath` is `null` or absent after refresh, treat the native path as failed/not proven; waiting alone does not convert a null Terraform state attribute into a passing output.

## Step 5 - SSH To The Instance

```bash
instance_id="$(terraform output -raw instance_id)"
public_ip="$(oci compute instance list-vnics \
  --instance-id "$instance_id" \
  --query 'data[0]."public-ip"' \
  --raw-output)"

ssh -i ../../progress/sprint_1/bv4db-key "opc@$public_ip"
```

Expected result: shell prompt on the native Terraform instance.

## Step 6 - Verify Guest Reality

```bash
sudo systemctl status oracle-cloud-agent --no-pager
sudo tail -100 /var/log/oracle-cloud-agent/plugins/oci-blockautoconfig/oci-blockautoconfig.log
sudo iscsiadm -m session
sudo multipath -ll
sudo multipathd show paths
sudo sed -n '1,220p' /etc/multipath.conf
lsblk -o NAME,TYPE,SIZE,MODEL,WWN,FSTYPE,MOUNTPOINT
```

Expected result:

```text
oracle-cloud-agent service is active
at least two iSCSI sessions are listed
one mpath* mapper is listed
at least two paths are active ready running
/etc/multipath.conf shows the agent-created multipath policy
```

## Step 7 - Optional Mount Check

```bash
sudo mkdir -p /mnt/sprint25-native
device="/dev/oracleoci/oraclevdb"
sudo blkid "$device" || sudo mkfs.xfs -f "$device"
sudo mount "$device" /mnt/sprint25-native
mount | grep ' /mnt/sprint25-native '
```

Expected result:

```text
/mnt/sprint25-native is mounted
```

## Step 8 - Existing LVM Data Preservation Check

Use this step only when migrating existing data volumes that already contain filesystems or LVM metadata. This step is not for a fresh empty Sprint 25 volume.

Before OCI detach/reattach, create a sentinel file and capture the current LVM identity:

```bash
mount_point="/u02/oradata"
sentinel="${mount_point}/.bv4db-persistent-path-sentinel"

sudo test -d "$mount_point"
sudo sh -c "date -u > '$sentinel'"
sudo sha256sum "$sentinel" | tee /tmp/bv4db-sentinel.sha256
sudo lsblk -f | tee /tmp/bv4db-lsblk.before
sudo blkid | tee /tmp/bv4db-blkid.before
sudo pvs -o+pv_uuid,devices | tee /tmp/bv4db-pvs.before
sudo vgs | tee /tmp/bv4db-vgs.before
sudo lvs -a -o+devices | tee /tmp/bv4db-lvs.before
```

After OCI detach/reattach with `/dev/oracleoci/oraclevd*` device paths, rediscover and reactivate existing LVM metadata:

```bash
sudo pvscan
sudo vgscan
sudo vgchange -ay
sudo lsblk -f | tee /tmp/bv4db-lsblk.after
sudo blkid | tee /tmp/bv4db-blkid.after
sudo pvs -o+pv_uuid,devices | tee /tmp/bv4db-pvs.after
sudo vgs | tee /tmp/bv4db-vgs.after
sudo lvs -a -o+devices | tee /tmp/bv4db-lvs.after
sudo mount -a
sha256sum -c /tmp/bv4db-sentinel.sha256
```

Pass criteria:

```text
PV UUIDs from /tmp/bv4db-pvs.before are present after reattach
VGs and LVs activate without recreation
sha256sum reports OK for .bv4db-persistent-path-sentinel
```

Do not run these commands on existing data volumes unless the intent is destructive reinitialization:

```text
pvcreate
vgcreate
lvcreate
mkfs
```

The migration goal is to reattach the same OCI volumes with persistent paths and reactivate existing LVM metadata, not to recreate logical volumes.

## Step 9 - Capture Evidence

```bash
cd ../..
ts="$(date -u '+%Y%m%d_%H%M%S')"
evidence="progress/sprint_25/native_terraform_multipath_evidence_${ts}.txt"

{
  echo "=== terraform outputs ==="
  terraform -chdir=terraform/sprint25-agent-multipath-native output
  echo
  echo "=== operator conclusion ==="
  echo "RESULT=MANUAL_REVIEW"
} | tee "$evidence"
```

Replace `RESULT=MANUAL_REVIEW` with `RESULT=PASS` only after Step 4 and Step 6 both satisfy the pass criteria.

## Step 10 - Destroy Native Terraform Resources

```bash
cd terraform/sprint25-agent-multipath-native
terraform destroy
```

Expected result:

```text
Destroy complete!
```

## Summary Decision

Use the native module only if live evidence proves:

- Terraform native attachment output has `is_multipath=true`.
- Terraform native attachment output has non-empty `multipath_devices`.
- Guest evidence shows agent-created iSCSI sessions.
- Guest evidence shows an `mpath*` mapper with active ready running paths.

If any condition fails, the helper module remains the validated Sprint 25 solution.
