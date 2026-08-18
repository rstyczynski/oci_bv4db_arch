# OCI Block Volume Single-Path to Multipath Operator Runbook

## Purpose and boundaries

Use this procedure for each target system that must move from an existing
Terraform-managed single-path iSCSI Block Volume to OCI Agent-managed
multipath. The same Block Volume and its data are retained. Sprint 24 is the
validated OCI Agent-managed multipath baseline for this procedure.

- Terraform is the only mechanism that changes Compute, Block Volume, and
  volume-attachment configuration.
- OCI CLI is used only for the operator-controlled Compute `STOP` and `START`
  actions and OCI verification.
- Do not manually log in to iSCSI, run `mpathconf`, or write custom
  dm-multipath policy.
- Do not use Terraform provisioners.

## Preconditions

- The target filesystem is mounted through its persistent device path using
  `/etc/fstab`, created during initial compute provisioning.
- The Compute instance uses a UHP-capable flexible shape, has at least 16
  OCPUs, and has the **Block Volume Management** plugin enabled.

## Required operator inputs

Set these values for the target system.

```bash
export TERRAFORM_DIR="/path/to/target-system/terraform"
export OCI_PROFILE="<OCI-profile-name>"
```

## Preparation

```bash
set -euo pipefail
export TF_CLI_ARGS="-no-color ${TF_CLI_ARGS:-}"
cd "$TERRAFORM_DIR"
oci_profile="${OCI_PROFILE:?Set OCI_PROFILE for the target tenancy}"
TRACE_PATH="${TRACE_PATH:-${HOME}/$(date +%F)/mp_switch}"
mkdir -p "$TRACE_PATH"
instance_id="$(terraform output -raw instance_id)"
declare -a volume_attachment_resources persistent_device_paths
while IFS=$'\t' read -r attachment_resource persistent_device_path; do
  volume_attachment_resources+=("$attachment_resource")
  persistent_device_paths+=("$persistent_device_path")
done < <(
  terraform show -json |
    jq -r '.. | objects |
      select(.address? and .type? == "oci_core_volume_attachment" and
             .values.attachment_type == "iscsi" and
             .values.is_multipath != true) |
      [.address, .values.device] | @tsv' |
    sort -u
)
((${#volume_attachment_resources[@]} > 0)) || {
  echo "No single-path iSCSI attachments were discovered in Terraform state." >&2
  exit 1
}
for index in "${!volume_attachment_resources[@]}"; do
  printf '%s\t%s\n' "${volume_attachment_resources[$index]}" \
    "${persistent_device_paths[$index]}"
done | tee "$TRACE_PATH/01-discovered-single-path-attachments.tsv"
```

`TRACE_PATH` is the operator evidence directory. If it is not supplied, it
defaults to `~/YYYY-MM-DD/mp_switch`. Retain its reviewed plans and command
output with the change record.

## Procedure

1. Record the pre-transition attachment inventory in
   `01-discovered-single-path-attachments.tsv`. Stop if no single-path iSCSI
   attachment is discovered.
2. Stop the instance cleanly. This lets Linux unmount the filesystem before
   its attachment is removed.

```bash
oci compute instance action \
  --profile "$oci_profile" \
  --instance-id "$instance_id" \
  --action STOP \
  --wait-for-state STOPPED \
  | tee "$TRACE_PATH/02-stop.log"
```

3. In Terraform, set `compute_ocpus = 16` or higher and
   `volume_vpus_per_gb = 100`, then apply the reviewed hardware plan. The plan
   must not replace the Block Volume.

```bash
terraform plan -input=false -out="$TRACE_PATH/uhp.tfplan" \
  | tee "$TRACE_PATH/03-uhp-plan.log"
terraform apply -input=false "$TRACE_PATH/uhp.tfplan" \
  | tee "$TRACE_PATH/03-uhp-apply.log"
```

4. While the instance remains stopped, detach each discovered single-path iSCSI
   attachment with Terraform. The discovery uses Terraform state, so no
   attachment resource address is supplied manually. For each plan, confirm
   that it destroys only the displayed attachment; it must not destroy or
   replace Compute or any Block Volume.

```bash
for index in "${!volume_attachment_resources[@]}"; do
  attachment_resource="${volume_attachment_resources[$index]}"
  plan_file="$TRACE_PATH/04-detach-${index}.tfplan"
  terraform plan -destroy -input=false \
    -target="$attachment_resource" \
    -out="$plan_file" \
    | tee "$TRACE_PATH/04-detach-${index}-plan.log"
  terraform apply -input=false "$plan_file" \
    | tee "$TRACE_PATH/04-detach-${index}-apply.log"
done
```

5. Start the instance and require `RUNNING`.

```bash
oci compute instance action \
  --profile "$oci_profile" \
  --instance-id "$instance_id" \
  --action START \
  --wait-for-state RUNNING \
  | tee "$TRACE_PATH/05-start.log"
```

6. Recreate the discovered attachments with Terraform. Review the plan: it
   must add every address in
   `01-discovered-single-path-attachments.tsv` and must not change Compute or
   any Block Volume.

```bash
terraform plan -input=false -out="$TRACE_PATH/attach.tfplan" \
  | tee "$TRACE_PATH/06-attach-plan.log"
terraform apply -input=false "$TRACE_PATH/attach.tfplan" \
  | tee "$TRACE_PATH/06-attach-apply.log"
```

7. Verify OCI control-plane multipath before accepting the transition. Use OCI
   CLI as shown below, or confirm **Multipath: Yes** in the OCI Console.
   The attachment must be `ATTACHED`, `is_multipath` must be `true`, and the
   `multipath_devices` list must be non-empty.

```bash
attachment_id="$(terraform output -raw attachment_id)"
oci compute volume-attachment get \
  --profile "$oci_profile" \
  --volume-attachment-id "$attachment_id" \
  --query 'data.{state:"lifecycle-state",is_multipath:"is-multipath",multipath_devices:"multipath-devices",device:device}' \
  --output json | tee "$TRACE_PATH/07-oci-multipath.json"
```

8. Retain the OCI CLI output from step 7 as the acceptance evidence for this
   stage. It must show every replacement attachment as `ATTACHED` with
   `is_multipath=true` and a non-empty `multipath_devices` list.

Do not modify `/etc/fstab` during this transition. OCI Agent owns iSCSI
session setup, dm-multipath configuration, and the target of the configured
persistent device path. No guest iSCSI or multipath configuration is required.

## Critical lifecycle requirement

OCI iSCSI attachment creation requires the target Compute instance to be
`RUNNING`. Do not attempt the attachment-create Terraform apply while the
instance is stopped. The safe production sequence is:

`clean stop -> Terraform detach -> OCI CLI start -> Terraform attach -> OCI validation`

## Recovery boundaries

- Stop immediately if a Terraform plan includes a Compute or Block Volume
  replacement.
- Stop if OCI does not report `is_multipath=true` and a non-empty device list.
- Do not resume workload writes until OCI acceptance evidence is retained and
  passes.
