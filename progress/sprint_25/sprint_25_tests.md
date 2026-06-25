# Sprint 25 - Test Execution Results

## Summary

| Gate | Result | Retries | Pass Rate |
| ---- | ------ | ------- | --------- |
| A3 Integration | PASS | 1 | 100% |
| B3 Integration | PASS | 0 | 100% |
| A3 Integration BV4DB-59 Addendum | FAIL | 0 | 98% |
| Live OCI BV4DB-59 Native Refresh | FAIL | 0 | n/a |
| B3 Integration BV4DB-59 Addendum | Pending | 0 | n/a |

## Artifacts

| Gate | Log File |
| ---- | -------- |
| A3 Integration | `test_run_A3_integration_20260507_114625.log` |
| A3 Integration Retry | `test_run_A3_integration_20260507_114636.log` |
| B3 Integration | `test_run_B3_integration_20260507_114645.log` |
| A3 Integration BV4DB-59 Addendum | `test_run_A3_integration_20260507_131001.log` |
| A3 Integration BV4DB-59 Manual Addendum | `test_run_A3_integration_20260507_131151.log` |
| A3 Integration BV4DB-59 Autodiscovery Manual Retry | `test_run_A3_integration_20260507_131311.log` |
| A3 Integration BV4DB-59 Autodiscovery Manual Pass | `test_run_A3_integration_20260507_131325.log` |
| A3 Integration BV4DB-59 multipath.conf Manual Pass | `test_run_A3_integration_20260507_131503.log` |
| A3 Integration BV4DB-59 Refresh-Only Output Pass | `test_run_A3_integration_20260507_131538.log` |
| A3 Integration BV4DB-59 Structural Latest | `test_run_A3_integration_20260507_131647.log` |
| Live OCI BV4DB-59 Native Refresh | existing Terraform state refreshed 2026-05-07 |
| A3 Integration BV4DB-59 Live Gate | `test_run_A3_integration_20260507_132029.log` |
| A3 Integration BUG-1 Persistent Path Safety Gate | `test_run_A3_integration_20260508_112519.log` |
| A3 Integration OCI Access Fixed Rerun | `test_run_A3_integration_20260508_113338.log` |
| A3 Integration BUG-2 Auto Login Removal Rerun | `test_run_A3_integration_20260508_121839.log` |
| B3 Integration BV4DB-59 Addendum | Pending |

## Failures

### Retry 1 - A3 Integration

- **Test:** `test_sprint25_terraform_agent_multipath.sh`
- **Error:** static regex failed to match `resource "terraform_data" "multipath_attachment"` in `main.tf`.
- **Fix:** corrected the regex to include Terraform's `resource` keyword.
- **Result:** pass on retry 1.

## Overall Results

| Scope | Scripts Passed | Scripts Failed | Status |
| ----- | -------------- | -------------- | ------ |
| New-code integration | 1 | 0 | PASS |
| Regression integration | 21 | 0 | PASS |

## Terraform Validation

The Sprint 25 repository integration gate ran:

- `terraform fmt -check -recursive`
- `terraform init -backend=false -input=false`
- `terraform validate`
- `terraform plan -refresh=false -input=false` with dummy OCI identifiers and a temporary SSH public key

The structural plan reported `Plan: 3 to add, 0 to change, 0 to destroy`.

This historical gate was structural only. It did not allocate live OCI resources and did not prove that a native Terraform attachment produces OCI multipath. It is superseded by the live gate added for BV4DB-59.

## BV4DB-59 Addendum

The Sprint 25 new-code integration gate was rerun after adding `terraform/sprint25-agent-multipath-native/`.

The addendum gate ran the existing helper module checks plus native module checks:

- native module file/README contract checks
- no raw API helper or guest setup patterns in the native module
- `terraform fmt -check -recursive`
- `terraform init -backend=false -input=false`
- `terraform validate`
- `terraform plan -refresh=false -input=false` with dummy OCI identifiers and a temporary SSH public key

The native structural plan reported `Plan: 3 to add, 0 to change, 0 to destroy`.

This historical addendum validated module shape only. Live OCI acceptance for BV4DB-59 requires a real apply plus `is_multipath=true`, non-empty `multipath_devices`, and guest `multipath -ll` evidence.

The plan emitted a provider warning that `compartment_id` on `oci_core_volume_attachment` is deprecated. This does not fail the gate; it is retained for parity with the provider schema and can be removed in a follow-up cleanup if desired.

## BV4DB-59 Manual Addendum

After adding `progress/sprint_25/sprint25_native_manual.md`, the Sprint 25 new-code integration gate was rerun. The gate verified the manual exists and includes apply, `is_multipath` output, guest `multipath -ll`, and destroy steps.

The rerun reported `43` script-level checks passed and `0` failed.

## BV4DB-59 Autodiscovery Manual Addendum

The native operator manual was updated so Step 1 writes `terraform.tfvars` directly and autodiscovers region, compartment, subnet, availability domain, and image ID from Sprint state plus OCI CLI. The integration test now verifies that the manual writes `terraform.tfvars` and includes OCI CLI discovery commands for availability domain and image.

First rerun failed because `terraform.tfvars.example` in the native module needed formatting after the doc/test change:

- **Log:** `test_run_A3_integration_20260507_131311.log`
- **Failure:** `native terraform fmt check`
- **Fix:** ran `terraform fmt -recursive` for the native module.

Retry passed:

- **Log:** `test_run_A3_integration_20260507_131325.log`
- **Result:** `46` script-level checks passed and `0` failed.

## BV4DB-59 multipath.conf Manual Addendum

The native operator manual Step 6 was updated to capture `/etc/multipath.conf` with `sudo sed -n '1,220p' /etc/multipath.conf`. The integration test now verifies that the manual includes this guest configuration dump.

- **Log:** `test_run_A3_integration_20260507_131503.log`
- **Result:** `47` script-level checks passed and `0` failed.

## BV4DB-59 Refresh-Only Output Addendum

The native operator manual Step 4 was updated to run `terraform apply -refresh-only` before reading outputs. This handles the case where resources already exist but the local state was created before the `is_multipath` output was added.

- **Log:** `test_run_A3_integration_20260507_131538.log`
- **Result:** `48` script-level checks passed and `0` failed.

## BV4DB-59 Live OCI Native Refresh Result

A refresh-only check was run against the existing live native Terraform state on 2026-05-07:

```bash
terraform -chdir=terraform/sprint25-agent-multipath-native apply -refresh-only -auto-approve
terraform -chdir=terraform/sprint25-agent-multipath-native show -json
```

Result:

```text
Apply complete! Resources: 0 added, 0 changed, 0 destroyed.
multipath_devices = tolist([])
is_multipath = null
iscsi_login_state = "UNKNOWN"
state = "ATTACHED"
```

Conclusion: the native no-helper path is **not green** on live OCI evidence. The validated Sprint 25 solution remains the helper-based Terraform module until native Terraform produces `is_multipath=true`, non-empty `multipath_devices`, and matching guest multipath evidence.

## BV4DB-59 Live A3 Gate

The Sprint 25 integration test was corrected so BV4DB-59 performs live validation instead of accepting structural Terraform checks. The gate now requires `terraform/sprint25-agent-multipath-native/terraform.tfvars`, runs live Terraform `plan`, `apply`, and `apply -refresh-only`, then asserts the OCI attachment state.

- **Log:** `test_run_A3_integration_20260507_132029.log`
- **Result:** `49` script-level checks passed and `1` failed.
- **Failure:** `native live Terraform OCI multipath validation`

Observed live state:

```text
native live is_multipath=null
native live multipath_devices=0
native live iscsi_login_state=UNKNOWN
```

Conclusion: BV4DB-59 fails the RUP live integration gate. Sprint 25 cannot be marked fully tested while BV4DB-59 remains in the sprint.

## BUG-1 Persistent Path and LVM Preservation Fix

BUG-1 was recorded in `progress/sprint_25/sprint_25_bugs.md` after review of existing-volume migration risk. Oracle documents that consistent device paths are required when attaching Ultra High Performance volumes, and the UHP multipath prerequisites explicitly include configuring the attachment to use a consistent device path.

The fix adds:

- Terraform variable validation requiring `/dev/oracleoci/oraclevd[b-z]` for both Sprint 25 modules.
- Helper-side validation rejecting non-OCI persistent paths and the boot-volume path `/dev/oracleoci/oraclevda`.
- README guidance that existing LVM stacks must be rediscovered/reactivated, not recreated.
- Manual data-preservation steps that create a sentinel file, capture LVM identity, run `pvscan`, `vgscan`, `vgchange -ay`, remount, and verify `sha256sum -c`.

The current environment could not execute a live sentinel-file test on an existing data LV because OCI authentication failed with `401-NotAuthenticated` during the native live gate, and the active Sprint 25 native host has no proven multipath/LVM data volume to migrate. No destructive LVM commands were run.

Latest verification:

```text
Log: progress/sprint_25/test_run_A3_integration_20260508_112519.log
Persistent-path checks: PASS
Sentinel/LVM preservation documentation checks: PASS
Sprint 25 bug registration check: PASS
Final gate result: FAIL at native live Terraform OCI multipath validation due 401-NotAuthenticated
```

After OCI access was fixed, the A3 gate was rerun:

```text
Log: progress/sprint_25/test_run_A3_integration_20260508_113338.log
Persistent-path checks: PASS
Sentinel/LVM preservation documentation checks: PASS
Terraform live native plan/apply/refresh: PASS, no infrastructure changes
native live is_multipath=null
native live multipath_devices=0
native live iscsi_login_state=UNKNOWN
Final gate result: FAIL at native live Terraform OCI multipath validation
```

## BUG-2 Auto Login Removal Rerun

BUG-2 removed `is_agent_auto_iscsi_login_enabled` from the native module so the no-helper test keeps only the persistent `device` path and leaves guest login/multipath work to the Block Volume Management plugin.

Verification:

```text
Log: progress/sprint_25/test_run_A3_integration_20260508_121839.log
Native module auto-login field removed: PASS
Native module auto-login variable removed: PASS
Terraform live native plan/apply/refresh: PASS, no infrastructure changes
native live is_multipath=null
native live multipath_devices=0
native live iscsi_login_state=UNKNOWN
Final gate result: FAIL at native live Terraform OCI multipath validation
```

Important caveat: Terraform reported no infrastructure changes for the existing native attachment after removing `is_agent_auto_iscsi_login_enabled`, so this rerun did not create a fresh attachment. A clean recreate may still be needed to prove whether the absence of the auto-login flag changes attach-time OCI behavior.

## BV4DB-60 Follow-Up

BV4DB-60 was added to the backlog and Sprint 25 tracking after the BUG-2 rerun. Its purpose is a clean, vanilla run from fresh state that follows Oracle documentation strictly: UHP volume, capable shape, enabled Block Volume Management plugin, network/IAM prerequisites, and a persistent `device` path on the attachment. It must avoid the raw API helper, guest-side iSCSI or multipath setup, and Terraform attachment flags that bypass the plugin's documented discovery flow.

This is tracked separately because the current BV4DB-59 state contains investigation history and Terraform reported no attachment recreation after removing the auto-login flag.

## BV4DB-59 Failure Analysis

### Live Evidence

The native Terraform module created the expected OCI resources:

```text
instance_id = ocid1.instance.oc1.eu-zurich-1.an5heljrknhfuyicov7k6cgozpkinfiphegsdfxcnfac6usnvywy3naqx4pa
volume_attachment_id = ocid1.volumeattachment.oc1.eu-zurich-1.an5heljrknhfuyicypeys6zfsjcjdedih23t3sdqzqk6zdbaf7j4vesjjxqa
```

Terraform state and direct OCI CLI attachment inspection agree on the failure point:

```text
attachment_type = iscsi
state = ATTACHED
device = /dev/oracleoci/oraclevdb
is_agent_auto_iscsi_login_enabled = true
is_multipath = null
multipath_devices = null / []
iscsi_login_state = UNKNOWN
```

This means the attachment exists, but OCI did not mark it as multipath-enabled and did not publish multipath target devices for the agent to consume.

### Oracle Documentation Cross-Check

Oracle's UHP attachment documentation states that Ultra High Performance volume attachments must be multipath-enabled for optimal performance, and that the Block Volume service attempts to enable multipath during attach only when all prerequisites are satisfied. If prerequisites are not satisfied, the attachment is not multipath-enabled. Source: [Configuring Attachments to Ultra High Performance Volumes](https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/configuringmultipathattachments.htm).

The same document lists the iSCSI prerequisites that matter for this run: supported shape, supported Linux image, Block Volume Management plugin enabled, public IP or service gateway access to Oracle services, IAM permissions for the plugin, and a consistent device path.

The live native module satisfies several visible prerequisites:

```text
shape = VM.Standard.E5.Flex
ocpus = 16
image = Oracle Linux image OCID
public_ip = 152.67.87.87
Block Volume Management desired_state = ENABLED
device = /dev/oracleoci/oraclevdb
volume_vpus_per_gb = 120
```

Additional live checks on 2026-05-07:

```text
OSN service gateway = not present in Sprint 1 state
Internet gateway route = 0.0.0.0/0 via Sprint 1 internet gateway
Security list egress = all protocols to 0.0.0.0/0
Instance public IP = 152.67.87.87
OCI agent desired state = Block Volume Management ENABLED
Guest oracle-cloud-agent service = active, enabled
Guest oracle-cloud-agent version = 1.57.0-2.el10.x86_64
Guest oci-blockautoconfig process = running under oracle-cloud-agent
/etc/multipath.conf = missing
```

The absence of an OSN service gateway is not itself a failure for this topology because Oracle requires either public IP access or service-gateway access to Oracle services. This instance has a public IP, an internet gateway default route, and unrestricted egress.

The guest plugin log repeatedly polls IMDS successfully:

```text
Polling volume attachments metadata from IMDS
completed the request http://169.254.169.254/opc/v2/volumeAttachments/
fetched volumeAttachments ..., status 200 OK
Got volume attachment: ... iqn... 169.254.2.2 3260
There is not change in the volume attachments.
Skipping since the volume attachments don't change.
```

This confirms the agent is running and can read attachment metadata. The metadata it receives is not multipath metadata: it contains the single iSCSI target but no multipath target list. Therefore the plugin does not create `/etc/multipath.conf` and does not configure a multipath mapper.

Oracle's Block Volume Management plugin documentation says the plugin checks instance metadata for multipath-enabled UHP attachments, creates `/etc/multipath.conf` only when such attachments exist, and performs batch iSCSI login commands for matching attachment metadata. Source: [Enabling the Block Volume Management Plugin](https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/enablingblockvolumemanagementplugin.htm).

That behavior explains the observed state: because the OCI attachment metadata has no multipath flag and no multipath device list, the plugin has no multipath-enabled UHP attachment metadata to act on. Waiting is unlikely to fix this after refresh-only apply and direct OCI CLI inspection still return null/empty multipath fields.

Oracle's Terraform provider documentation for `oci_core_volume_attachment` describes `is_agent_auto_iscsi_login_enabled` as agent login/logout automation for non-multipath iSCSI attachments, while `is_multipath` is exposed as attachment state rather than an argument used by this native module. Source: [OCI Terraform `oci_core_volume_attachment`](https://docs.oracle.com/en-us/iaas/tools/terraform-provider-oci/7.14.0/docs/r/core_volume_attachment.html).

### Current Root-Cause Assessment

Most likely failure point: native `oci_core_volume_attachment` did not create an attachment that OCI reports as multipath-enabled. The helper module succeeds because it sends the raw API property `isMultipath: true`; the native module intentionally does not, because the Terraform provider does not expose it as a settable argument in the tested path.

Secondary items still worth checking before closing the investigation:

- Confirm the instance-agent plugin runtime status from OCI Console or a newer OCI CLI plugin/status command.
- Confirm dynamic-group policy includes the native instance compartment and grants `use instances` plus `use volume-attachments`.
- Confirm guest plugin logs after connecting with the matching private SSH key. The current `terraform.tfvars` points to `progress/sprint_1/bv4db-key.pub`, which is a public key path and cannot be used for SSH log collection.

### Decision

BV4DB-59 is a valid negative result: the native no-helper Terraform path did not prove OCI agent-managed multipath. Keep the helper-based Sprint 25 module as the validated Terraform implementation until the provider exposes a settable multipath argument or a future live run proves that native attachment creation returns `is_multipath=true` and non-empty `multipath_devices`.
