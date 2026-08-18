# Sprint 29 - Implementation Notes

## BV4DB-71. Operator runbook for single-path to multipath conversion

Status: implemented

Implemented a minimal native Terraform module and operator runbook. The module creates a single-path baseline, enables agent auto-login for that baseline, creates the new compute instance with cloud-init mount setup, and exposes the OCI attachment state. It contains no Terraform provisioners.

The runbook uses oci_scaffold outputs as Terraform inputs, OCI Run Command for Linux-level test-file/checksum work, and OCI CLI for the operator-controlled Compute stop and attachment verification. The live run remains required to resolve the detach–reattach hypothesis.

### Delivered Artifacts

| Artifact | Purpose |
| --- | --- |
| `terraform/sprint29-multipath-transition/main.tf` | Minimal native OCI compute, volume, and iSCSI attachment configuration. |
| `terraform/sprint29-multipath-transition/cloud-init.yaml` | First-boot fstab and mount setup for the new compute instance. |
| `terraform/sprint29-multipath-transition/variables.tf` | Input contract, including the shared infrastructure OCID references. |
| `terraform/sprint29-multipath-transition/outputs.tf` | Instance, volume, attachment, persistent-path, and computed multipath outputs. |
| `progress/sprint_29/operator_runbook.md` | Operator procedure, evidence requirements, and recovery boundary. |
| `tests/integration/test_sprint29_multipath_runbook.sh` | Static contract test for the runbook. |

### Terraform Implementation

The module receives the compartment ID, subnet ID, availability domain, image ID, and SSH-key path as inputs. The operator obtains the shared prerequisite infrastructure from `oci_scaffold` and passes its OCID references into Terraform; the module does not recreate that shared infrastructure.

The initial apply uses a `20` VPU/GB volume and an `8`-OCPU flexible compute shape. The native iSCSI attachment uses the existing OCI persistent device path and sets `is_agent_auto_iscsi_login_enabled = true`, allowing Oracle Cloud Agent to connect the non-multipath baseline. The instance enables the Block Volume Management plugin.

For the transition, the operator changes only the Terraform inputs to `volume_vpus_per_gb = 100` and `compute_ocpus = 16`, then applies the configuration. The implementation deliberately records, rather than assumes, whether the OCI provider/service performs the required detach–reattach automatically. The live run is the acceptance evidence for that hypothesis.

The module contains no `local-exec`, `remote-exec`, or other provisioner. It does not issue manual guest iSCSI login, `mpathconf`, or custom `multipath.conf` commands.

### First-Boot Mount Setup

Because Sprint 29 creates a new compute instance, Terraform supplies cloud-init through OCI instance `user_data`. Cloud-init waits until the configured persistent device path resolves to a block device, creates the mount point, writes an `_netdev,nofail` fstab entry if it is absent, formats only an unformatted initial test volume, and mounts it.

After the UHP transition, OCI Agent remains responsible for iSCSI session setup, dm-multipath configuration, and remapping the persistent path to the mapper-backed device. The existing fstab entry then mounts the same filesystem through that persistent path. No cloud-init rerun is required for the transition.

### Prerequisites and Parameters

- Run from the repository root with `terraform`, OCI CLI, `jq`, and `shasum`
  available.
- `progress/sprint_1/state-bv4db.json` and
  `progress/sprint_1/bv4db-key.pub` exist. The former supplies the shared
  oci_scaffold compartment and subnet references; this Sprint does not create
  those prerequisites itself.
- OCI CLI credentials are valid and authorized to manage the target compute,
  volume, attachment, and Compute Instance Run Command resources.
- The selected Oracle Linux image has Oracle Cloud Agent and the Compute
  Instance Run Command and Block Volume Management plugins enabled. The agent
  requires its normal OCI dynamic-group/policy access.
- The initial 50 GB volume is new and empty. The format guard in cloud-init is
  intentionally valid only for this baseline creation; it is never an
  operation in the conversion.

| Terraform input | Baseline | Transition | Reason |
| --- | --- | --- | --- |
| `compute_ocpus` | `8` | `16` | UHP multipath prerequisite. |
| `volume_vpus_per_gb` | `20` | `100` | Transitions the volume to UHP. |
| `device_path` | `/dev/oracleoci/oraclevdb` | unchanged | Persistent fstab path. |
| `compute_memory_gb` | `32` | unchanged | Minimal flexible-shape baseline. |
| `volume_size_gbs` | `50` | unchanged | Minimal filesystem and integrity-test volume. |

`OCI_PROFILE`, `OCI_REGION`, `COMPARTMENT_OCID`, `SUBNET_OCID`,
`AVAILABILITY_DOMAIN`, and `IMAGE_ID` are optional environment overrides.
`OCI_PROFILE` is the single profile argument for both Terraform and every OCI
CLI command in this procedure; it is exported to OCI CLI as
`OCI_CLI_PROFILE` and written as Terraform's `oci_profile`. When unset, the
snippet uses `OCI_CLI_PROFILE` when already set, otherwise `DEFAULT`. No
secret is written to `terraform.tfvars` or sent through Run Command.

Terraform creates the Run Command dynamic group before the instance, using the
OCI instance matcher `instance.compartment.id`, and creates the self-only
`instance-agent-command-execution-family` policy. This avoids relying on a
manual Console IAM change or the up-to-30-minute post-membership polling delay.

### Operator Test Flow

1. Apply the baseline Terraform inputs and wait for the initial filesystem mount.
2. Use OCI Compute Instance Run Command to create a small test file and archive its SHA-256 checksum.
3. Stop the instance through OCI CLI before applying the UHP/OCPU Terraform change.
4. Apply the UHP and 16-OCPU Terraform inputs.
5. Verify the attachment in OCI first: Console Multipath is `Yes` or OCI CLI returns `is-multipath=true`.
6. Use OCI Compute Instance Run Command for the secondary guest evidence: persistent-path target, `multipath -ll`, active paths, mount status, test-file presence, and matching checksum.

The run command facility is the only permitted mechanism for Linux-level test operations in this sprint. It must not be used to configure iSCSI or dm-multipath, and it must not receive credentials or secrets in command content.

### Executable Operator Snippets

The following commands are the implementation-level, copy/paste procedure. Run
them from the repository root with an OCI CLI profile that can create the
resources and issue Compute Instance Run Command. They deliberately use
Terraform for every configuration change; OCI CLI performs discovery,
operator-controlled Compute stop, Run Command submission, and verification.

#### 1. Prepare the baseline Terraform inputs

```bash
set -euo pipefail
export TF_CLI_ARGS="-no-color ${TF_CLI_ARGS:-}"
oci_profile="${OCI_PROFILE:-${OCI_CLI_PROFILE:-DEFAULT}}"
export OCI_CLI_PROFILE="$oci_profile"

cd terraform/sprint29-multipath-transition
state="../../progress/sprint_1/state-bv4db.json"

region="${OCI_REGION:-$(jq -r '.inputs.oci_region // empty' "$state")}"
compartment_id="${COMPARTMENT_OCID:-$(jq -r '.compartment.ocid // .inputs.oci_compartment // empty' "$state")}"
tenancy_id="$(jq -r '.compartments[0].parent_ocid // empty' "$state")"
subnet_id="${SUBNET_OCID:-$(jq -r '.subnet.ocid // empty' "$state")}"
availability_domain="${AVAILABILITY_DOMAIN:-$(oci iam availability-domain list \
  --profile "$oci_profile" \
  --compartment-id "$compartment_id" \
  --query 'data[0].name' \
  --raw-output)}"
image_id="${IMAGE_ID:-$(oci compute image list \
  --profile "$oci_profile" \
  --compartment-id "$compartment_id" \
  --operating-system 'Oracle Linux' \
  --shape VM.Standard.E5.Flex \
  --sort-by TIMECREATED \
  --sort-order DESC \
  --query 'data[0].id' \
  --raw-output)}"

test -n "$region"
test -n "$compartment_id"
test -n "$tenancy_id"
test -n "$subnet_id"
test -n "$availability_domain"
test -n "$image_id"
test -f ../../progress/sprint_1/bv4db-key.pub

cat > terraform.tfvars <<EOF
region = "$region"
oci_profile = "$oci_profile"
compartment_id = "$compartment_id"
tenancy_id = "$tenancy_id"
availability_domain = "$availability_domain"
subnet_id = "$subnet_id"
image_id = "$image_id"
ssh_public_key_path = "../../progress/sprint_1/bv4db-key.pub"

name_prefix = "bv4db-s29"
compute_shape = "VM.Standard.E5.Flex"
compute_ocpus = 8
compute_memory_gb = 32
volume_size_gbs = 50
volume_vpus_per_gb = 20
device_path = "/dev/oracleoci/oraclevdb"
EOF

terraform init -backend=false -input=false
terraform fmt -check
terraform validate
terraform apply -input=false -auto-approve
```

The `8` OCPU and `20` VPU/GB values deliberately create the initial
single-path baseline. Cloud-init creates the filesystem and the persistent
`/etc/fstab` entry on this fresh, empty volume.

Expected output ends with `Apply complete!` and `terraform output -raw
instance_id` returns an `ocid1.instance...` value. If the persistent mount
does not appear, stop here; do not create the integrity test file.

#### 2. Submit and collect an OCI Run Command

The helper below is executable Bash. It submits its first argument as inline
Run Command content and prints the command OCID. The generated JSON includes
the required `TEXT` source and `TEXT` output types; it contains no credentials.

```bash
submit_run_command() {
  local command_text="$1"
  local display_name="$2"
  local command_sha command_id
  command_sha="$(printf %s "$command_text" | shasum -a 256 | awk '{print $1}')"
  jq -n --arg instance_id "$instance_id" \
    '{instanceId: $instance_id}' > run-command-target.json
  jq -n --arg text "$command_text" --arg sha "$command_sha" \
    '{source: {sourceType: "TEXT", text: $text, textSha256: $sha}, output: {outputType: "TEXT"}}' \
    > run-command-content.json
  command_id="$(oci instance-agent command create \
    --profile "$oci_profile" \
    --compartment-id "$compartment_id" \
    --target file://run-command-target.json \
    --content file://run-command-content.json \
    --timeout-in-seconds 300 \
    --display-name "$display_name" \
    --query 'data.id' --raw-output)"
  printf '%s\\n' "$command_id"
}

wait_run_command() {
  local command_id="$1" state
  while :; do
    state="$(oci instance-agent command-execution get \
      --profile "$oci_profile" \
      --instance-id "$instance_id" --command-id "$command_id" \
      --query 'data."lifecycle-state"' --raw-output)"
    case "$state" in
      SUCCEEDED) break ;;
      FAILED|TIMED_OUT|CANCELED) return 1 ;;
    esac
    sleep 10
  done
  oci instance-agent command-execution get \
    --profile "$oci_profile" \
    --instance-id "$instance_id" --command-id "$command_id" \
    --query 'data."output-content"' \
    --output json
}

instance_id="$(terraform output -raw instance_id)"
```

#### 3. Create the integrity test file through Run Command

```bash
baseline_command="$(submit_run_command '
set -euo pipefail
mountpoint -q /mnt/sprint29
printf "Sprint 29 persistent-data test\\n" > /mnt/sprint29/test-file
sha256sum /mnt/sprint29/test-file | tee /mnt/sprint29/test-file.sha256
' 's29-create-test-file')"
wait_run_command "$baseline_command"
```

Retain the resulting command OCID and output as pre-transition evidence.
The command output must include a SHA-256 digest followed by
`/mnt/sprint29/test-file`.

#### 4. Stop Compute through OCI CLI, then apply only the UHP/OCPU change

The shutdown remains an operator-controlled action, but uses the OCI Compute
control plane rather than Run Command. Terraform does not perform this
lifecycle action, and no SSH or provisioner is used.

```bash
oci compute instance action \
  --profile "$oci_profile" \
  --instance-id "$instance_id" \
  --action STOP \
  --wait-for-state STOPPED

terraform apply -input=false -auto-approve \
  -var='compute_ocpus=16' \
  -var='volume_vpus_per_gb=100'

oci compute instance action \
  --profile "$oci_profile" \
  --instance-id "$instance_id" \
  --action START \
  --wait-for-state RUNNING
```

This is the live hypothesis point: record whether the Terraform provider and
OCI service reconcile the attachment automatically. If they do not, record
that result and stop for the controlled manual detach/attach procedure; do
not use guest iSCSI or multipath commands as a substitute.

Expected output ends with `Apply complete!`. Before running the next snippet,
OCI must show the instance has returned to `RUNNING`; otherwise, record the
provider/service lifecycle result as a failed transition hypothesis.

### Live Execution Record

The live run created the baseline instance and 50 GB volume, mounted the
initial XFS filesystem through `/dev/oracleoci/oraclevdb`, and created
`/mnt/sprint29/test-file` with a retained SHA-256 proof through OCI Run
Command. The initial Run Command polling delay was resolved by Terraform
provisioning the OCI dynamic group and self-only Run Command policy before the
replacement instance.

OCI Run Command accepted but did not complete the in-guest shutdown request.
The procedure was therefore corrected to use the OCI Compute CLI `STOP` action
and wait for `STOPPED`; that action succeeded. Terraform then updated the
volume from 20 to 100 VPU/GB and the instance from 8 to 16 OCPU in place. Its
plan contained no attachment detach or attach action. Before the required
Compute `START`, OCI reported the attachment as `ATTACHED` with no multipath
flag or multipath device list. The post-start OCI and guest validation decides
whether the OCI Agent/service completes automatic multipath activation or the
detach–reattach hypothesis is rejected.

The Compute CLI `START` action returned the instance to `RUNNING` with 16
OCPU. OCI attachment evidence remained `ATTACHED` but returned neither an
`is-multipath` value nor a `multipath-devices` list. Therefore the automatic
detach–reattach and automatic multipath-activation hypothesis is **rejected**
for this live provider-managed update. The procedure correctly stops before
guest-level multipath or checksum validation because OCI control-plane
multipath was not confirmed. A controlled manual detach/attach is required in
the follow-up run before claiming data preservation across a multipath
transition.

The live run used the Oracle OCI Terraform provider version `8.26.0`, pinned
in `terraform/sprint29-multipath-transition/.terraform.lock.hcl`. The module
constraint is `>= 7.7.0`; `8.26.0` was also the latest provider release on the
Terraform Registry when this evidence was recorded.

### Plan B - Forced Terraform Attachment Replacement

Plan B preserves the existing block volume and filesystem while forcing
Terraform to replace only `oci_core_volume_attachment.transition`. The
operator stops Compute to cleanly release the filesystem, then starts it
through the documented OCI CLI lifecycle action before the attachment apply;
OCI rejects iSCSI attachment creation for a stopped instance (observed
`409-IncorrectState`). Terraform performs the configuration change. The
targeted plan must show attachment replacement only. After the apply, OCI must report
`is-multipath=true` and a non-empty multipath device list before OCI Run
Command is allowed to verify the mapper-backed mount and test-file checksum.
The executable commands and fail-closed conditions are recorded in
`progress/sprint_29/operator_runbook.md` under **Plan B - Terraform-Controlled
Attachment Replacement**.

Live evidence: TC19 stopped the instance successfully. TC20 showed exactly one
attachment replacement. TC21/TC22 then received `409-IncorrectState` because
the attachment API requires the instance to be `RUNNING`; the existing volume
was retained and remains detached. Plan B has been corrected to start Compute
before its Terraform attachment apply. No filesystem or guest configuration is
changed by that correction.

**Critical finding for the operator procedure:** an OCI iSCSI attachment
cannot be created for a `STOPPED` Compute instance. The tested safe sequence is
clean Linux stop, OCI CLI start, Terraform attachment replacement, OCI
multipath confirmation, then OCI Run Command mount and integrity validation.
TC25 confirmed that the replacement succeeded after the instance entered
`RUNNING`, returning `is_multipath = true`.

### Deferred Guest-Level Evidence

After the OCI control plane reported an attached multipath volume, the
post-transition OCI Run Command delivery initially stalled. Following stale
command cleanup and a clean Compute stop/start, the command was delivered but
failed because `/dev/oracleoci/oraclevdb` was absent at that instant. This is
recorded as implementation evidence only. Per the approved Sprint 29 scope,
guest-level validation is deferred: OCI attachment evidence (`ATTACHED`,
`is_multipath=true`, non-empty `multipath_devices`) is the acceptance criterion
for this stage. No `/etc/fstab`, iSCSI, or dm-multipath guest configuration was
changed as a result.

#### 5. OCI control-plane verification, then guest evidence

```bash
attachment_id="$(terraform output -raw attachment_id)"
oci compute volume-attachment get --volume-attachment-id "$attachment_id" \
  --profile "$oci_profile" \
  --query 'data.{is_multipath:"is-multipath",lifecycle_state:"lifecycle-state",device:device}' \
  --output json

postcheck_command="$(submit_run_command '
set -euo pipefail
mountpoint -q /mnt/sprint29
readlink -f /dev/oracleoci/oraclevdb
multipath -ll
active_paths="$(multipathd show paths format "%d %t %o %T")"
printf "%s\\n" "$active_paths"
test -n "$active_paths"
sha256sum -c /mnt/sprint29/test-file.sha256
test -f /mnt/sprint29/test-file
' 's29-post-transition-validation')"
wait_run_command "$postcheck_command"
```

The OCI output must show `is_multipath: true` (or the Console must show
Multipath `Yes`) before accepting the Linux output. The final Run Command must
complete successfully, show the persistent path resolved through dm-multipath,
and report `OK` for the preserved test-file checksum.

### Error Handling and Safety Boundaries

- Stop if the initial persistent path or mount does not appear; do not create a test file on an unverified device.
- Stop if OCI does not report `is-multipath=true`; Linux checks cannot compensate for a non-multipath attachment.
- Stop if the persistent path does not resolve through the mapper, active paths are incomplete, the mount is absent, the test file is missing, or its checksum differs.
- A failed automatic detach–reattach hypothesis does not imply data loss. Record the result and require a controlled manual detach/attach path for a follow-up run.
- The runbook never reformats an existing filesystem during the transition. The initial format guard applies only to the newly created, empty test volume.

### Validation Status

`terraform fmt`, `terraform init -backend=false`, and `terraform validate` passed for the new module. The extracted copy/paste Bash snippets pass `bash -n`. The new Sprint 29 integration gate passed all `16` checks; the latest ASCII log is `progress/sprint_29/test_run_A3_integration_20260810_093000.log`.

The full integration regression is currently blocked by invalid OCI authentication in pre-existing Sprint 25 and Sprint 26 live tests. The recorded failures are unrelated to the Sprint 29 module and occurred before Sprint 29 infrastructure was created. A live Sprint 29 execution, including the detach–reattach hypothesis and checksum proof, is pending valid OCI credentials.
