# Sprint 24 - OCI Agent-Managed Multipath Validation Manual

This sprint validates a simplified multipath setup where the Oracle Cloud Agent **Block Volume Management** plugin is the primary mechanism managing multipath-enabled iSCSI attachments.

Oracle references used by this manual:

- `https://docs.oracle.com/iaas/Content/Block/Tasks/enablingblockvolumemanagementplugin.htm`
- `https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/configuringmultipathattachments.htm`
- `https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/multipathcheck.htm`
- `https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/troubleshootingmultipathattachments.htm`

## Preconditions

- OCI tenancy access with permissions to create/attach block volumes and manage instance plugins.
- Supported image where Oracle Cloud Agent + Block Volume Management plugin is supported.
- You understand the cost implications of running UHP block volumes.

## CLI environment (copy/paste)

Set the following variables (replace values):

```bash
export COMPARTMENT_ID="<compartment_ocid>"
export INSTANCE_ID="<instance_ocid>"
export AVAILABILITY_DOMAIN="<ad_name>" # example: kIdk:EU-ZURICH-1-AD-1
export VOLUME_ID="<uhp_volume_ocid>"   # pre-created UHP volume to attach
```

## Step 1 - Enable the Block Volume Management plugin

This step uses OCI CLI to enable the plugin for an existing instance via `agentConfig.pluginsConfig` (see the Oracle reference below).

Oracle reference:

- `https://docs.oracle.com/iaas/Content/Block/Tasks/enablingblockvolumemanagementplugin.htm`

### 1.1 Inspect current plugin status

```bash
oci instance-agent plugin list \
  --compartment-id "$COMPARTMENT_ID" \
  --instanceagent-id "$INSTANCE_ID" \
  --all \
  --query "data[?name=='Block Volume Management']"
```

### 1.2 Enable the plugin

```bash
oci compute instance update \
  --instance-id "$INSTANCE_ID" \
  --agent-config '{"pluginsConfig":[{"name":"Block Volume Management","desiredState":"ENABLED"}]}'
```

### 1.3 Re-check that the plugin is enabled/running

```bash
oci instance-agent plugin list \
  --compartment-id "$COMPARTMENT_ID" \
  --instanceagent-id "$INSTANCE_ID" \
  --all \
  --query "data[?name=='Block Volume Management']"
```

## Step 2 - Create a multipath-enabled iSCSI attachment (UHP)

For Ultra High Performance volumes, multipath enablement is determined by prerequisites (supported shape, supported image, plugin enabled, consistent device paths) and the Block Volume service attempts to enable multipath during attach.

Oracle reference:

- `https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/configuringmultipathattachments.htm`

### 2.1 Attach the UHP volume (iSCSI)

```bash
oci compute volume-attachment attach-iscsi-volume \
  --instance-id "$INSTANCE_ID" \
  --volume-id "$VOLUME_ID" \
  --wait-for-state ATTACHED
```

Capture the resulting **volume attachment OCID** from the command output into:

```bash
export VOLUME_ATTACHMENT_ID="<volume_attachment_ocid>"
```

### 2.2 Verify whether the attachment is multipath-enabled (provider-side)

```bash
oci compute volume-attachment get \
  --volume-attachment-id "$VOLUME_ATTACHMENT_ID" \
  --query "data.{id:id,lifecycleState:lifecycle-state,isMultipath:is-multipath,iqn:iqn,ipv4:ipv4,port:port}"
```

If `isMultipath` is not `true`, use Oracle’s verification and troubleshooting references:

- `https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/multipathcheck.htm`
- `https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/troubleshootingmultipathattachments.htm`

## Step 3 - Evidence checklist (ground truth)

Use this checklist to confirm the environment is truly multipath-enabled and is using a mapper device.

### 3.1 Check iSCSI sessions

```bash
sudo iscsiadm -m session
```

### 3.2 Check multipath mapping exists

```bash
sudo multipath -ll
```

### 3.3 Check mount source is a mapper device

Replace `<MOUNTPOINT>` with the mount you expect the block volume to be mounted at.

```bash
findmnt -no SOURCE,TARGET <MOUNTPOINT>
```

Acceptance intent:

- SOURCE should be `/dev/mapper/mpath*` (or `/dev/dm-*`), not a raw `/dev/sdX` or `/dev/disk/by-path/...` single-path device.

### 3.4 Reconcile OCI “Management” tab output with guest evidence

If the OCI Console plugin shows warnings, treat the guest evidence above as the source of truth and use Oracle troubleshooting to interpret the discrepancy:

- `https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/troubleshootingmultipathattachments.htm`

## Step 4 - Archive evidence

Capture the following into a timestamped artifact bundle under `progress/sprint_24/`:

- output of `iscsiadm -m session`
- output of `multipath -ll`
- output of `findmnt` for the target mount
- relevant Oracle Cloud Agent plugin logs (if accessible)

### 4.1 Required filenames for integration gate

The Sprint 24 integration test requires the following files to exist under `progress/sprint_24/` after a live run:

- `live_instance_agent_plugins.json` - output of the plugin list query (Step 1.1 / 1.3)
- `live_volume_attachment.json` - output of `oci compute volume-attachment get ...` (Step 2.2)
- `live_iscsiadm_session.txt` - output of `iscsiadm -m session` (Step 3.1)
- `live_multipath_ll.txt` - output of `multipath -ll` (Step 3.2)
- `live_findmnt.txt` - output of `findmnt` for the mountpoint (Step 3.3)

## Step 5 - Troubleshooting

Use Oracle’s official troubleshooting and verification guidance:

- Multipath check: `https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/multipathcheck.htm`
- Troubleshooting: `https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/troubleshootingmultipathattachments.htm`

