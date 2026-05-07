# Sprint 24 - OCI Agent-Managed Multipath Manual

## Purpose

This manual validates the Oracle Cloud Agent Block Volume Management plugin as the primary mechanism for UHP iSCSI multipath setup. It deliberately avoids custom guest-side `iscsiadm --login`, `mpathconf --enable`, and custom `multipath.conf` policy writes.

## Prerequisites

- Run from the repository root.
- Sprint 1 shared infrastructure state exists at `progress/sprint_1/state-bv4db.json`.
- OCI CLI is configured for the tenancy used by Sprint 1.
- The runner can autodiscover OCI region from `OCI_REGION`, `progress/sprint_1/state-bv4db.json`, or the active OCI CLI profile in `~/.oci/config`.
- Supported OCI shape and image are available for UHP multipath.
- Instance has public IP or service gateway access to Oracle services.
- Dynamic group and policy allow Oracle Cloud Agent to inspect instances and volume attachments.

## Operator Walkthrough

### Step 1 - Confirm Repository Context

```bash
pwd
test -f AGENTS.md
test -f progress/sprint_1/state-bv4db.json
test -f progress/sprint_1/bv4db-key.pub
```

Expected output:

```text
/Users/rstyczynski/projects/oci_bv4db_arch
```

### Step 2 - Review Autodiscovered OCI Context

```bash
jq -r '
  "compartment=" + (.compartment.ocid // "(missing)"),
  "subnet=" + (.subnet.ocid // "(missing)"),
  "ssh_secret=" + (.secret.ocid // "(missing)"),
  "state_region=" + (.inputs.oci_region // "(not recorded; runner will use OCI CLI config)")
' progress/sprint_1/state-bv4db.json

profile="${OCI_CLI_PROFILE:-DEFAULT}"
config="${OCI_CLI_CONFIG_FILE:-$HOME/.oci/config}"
awk -v profile="$profile" '
  $0 == "[" profile "]" { in_profile=1; next }
  /^\[/ { in_profile=0 }
  in_profile && /^[[:space:]]*region[[:space:]]*=/ { print "config_region=" $0 }
' "$config"
```

Expected output:

```text
compartment=ocid1.compartment...
subnet=ocid1.subnet...
ssh_secret=ocid1.vaultsecret...
state_region=...
config_region=region=...
```

### Step 3 - Run Agent-Managed Validation and Keep Infrastructure

```bash
KEEP_INFRA=true ./tools/run_bv4db_oci_agent_multipath_sprint24.sh
```

Expected output includes:

```text
[INFO] Using OCI region: ...
[INFO] Enabling OCI Block Volume Management plugin before volume attach...
[INFO] Waiting for agent-managed iSCSI sessions, mapper device, and mountable path...
[DONE] Evidence: progress/sprint_24/oci_agent_multipath_evidence_<timestamp>.txt
[DONE] Attachment JSON: progress/sprint_24/volume_attachment_<timestamp>.json
```

### Step 4 - Inspect Latest Evidence Locally

```bash
evidence="progress/sprint_24/oci_agent_multipath_evidence_latest.txt"
attachment="progress/sprint_24/volume_attachment_latest.json"

grep -E 'sessions=|maps=|active_ready_running_paths=|RESULT=' "$evidence"
jq -r '.data.id, .data."is-multipath", (.data."multipath-devices" // []) | tostring' "$attachment"
```

Expected output:

```text
sessions=2
maps=1
active_ready_running_paths=2
RESULT=PASS
ocid1.volumeattachment...
true
...
```

### Step 5 - SSH to the Kept Instance

```bash
state="progress/sprint_24/state-bv4db-s24-agent-latest.json"
public_ip="$(jq -r '.compute.public_ip' "$state")"
secret_ocid="$(jq -r '.secret.ocid // empty' progress/sprint_1/state-bv4db.json)"
key_file="$(mktemp)"

oci secrets secret-bundle get \
  --secret-id "$secret_ocid" \
  --query 'data."secret-bundle-content".content' --raw-output \
  | base64 --decode > "$key_file"
chmod 600 "$key_file"

ssh -i "$key_file" -o StrictHostKeyChecking=no "opc@$public_ip"
```

Expected result: shell prompt on the Sprint 24 instance.

### Step 6 - Verify Guest Reality on the Instance

```bash
sudo systemctl status oracle-cloud-agent --no-pager
sudo tail -100 /var/log/oracle-cloud-agent/plugins/oci-blockautoconfig/oci-blockautoconfig.log
sudo iscsiadm -m session
sudo multipath -ll
sudo multipathd show paths
lsblk -o NAME,TYPE,SIZE,MODEL,WWN,FSTYPE,MOUNTPOINT
mount | grep ' /mnt/sprint24-agent '
```

Expected output:

```text
oracle-cloud-agent service is active
at least two iSCSI sessions are listed
one mpath* mapper is listed
at least two paths are active ready running
/mnt/sprint24-agent is mounted
```

### Step 7 - Teardown After Inspection

```bash
KEEP_INFRA=false ./tools/run_bv4db_oci_agent_multipath_sprint24.sh
```

Expected output:

```text
[INFO] Teardown ...
[DONE] Evidence: progress/sprint_24/oci_agent_multipath_evidence_<timestamp>.txt
```

## Evidence Checklist

Use the generated `oci_agent_multipath_evidence_<timestamp>.txt` file and confirm all checks:

| Check | Evidence |
| ----- | -------- |
| Plugin enabled | `block volume plugin config` shows `oci-blockautoconfig` enabled or not disabled |
| Plugin active | `oracle-cloud-agent service` is running and plugin log has current activity |
| Control plane multipath | `volume_attachment_<timestamp>.json` has `data.is-multipath` set to `true` |
| iSCSI sessions | `iscsiadm -m session` lists at least two sessions for the volume |
| Mapper device | `multipath -ll` shows an `mpath*` map |
| Path state | `multipath -ll` and `multipathd show paths` show at least two active ready paths |
| Startup mode | node startup values under `/var/lib/iscsi/nodes` are consistent with OCI multipath guidance |
| Mounted filesystem | `mount verification` reports the Sprint 24 mountpoint as mounted |
| Final result | checklist block ends with `RESULT=PASS` |

## Troubleshooting

### Missing Sessions

If `iscsiadm -m session` is empty or has only one session, check the plugin log at `/var/log/oracle-cloud-agent/plugins/oci-blockautoconfig/oci-blockautoconfig.log`. Common causes are missing service gateway/public IP access, missing dynamic group policy, disabled Oracle Cloud Agent, or an attachment that was not created as multipath-enabled.

### Missing Mapper

If iSCSI sessions exist but `multipath -ll` has no `mpath*` map, confirm the attachment is really multipath-enabled in OCI and that the instance image supports multipath. Do not mix `oci-utils` and `oci-iscsi-config` on the same volume while troubleshooting because Oracle documents this as a source of false multipath reporting.

### Missing Mount

If mapper evidence is healthy but the mountpoint is not mounted, check `lsblk`, `blkid`, and the resolved device path from `/dev/oracleoci/oraclevdb`. For persistent mounts, include `_netdev,nofail` and consider `x-systemd.requires=multipathd.service` when documenting an `/etc/fstab` entry.

### Plugin Warnings

If the plugin log shows authorization or user-agent errors, verify the dynamic group policy and network path to Oracle services. The plugin must be able to read attachment configuration and report iSCSI setup status back to OCI.

## Official References

- <https://docs.oracle.com/iaas/Content/Block/Tasks/enablingblockvolumemanagementplugin.htm>
- <https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/configuringmultipathattachments.htm>
- <https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/troubleshootingmultipathattachments.htm>
- <https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/multipathcheck.htm>
