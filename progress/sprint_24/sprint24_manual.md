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

## Step 1 - Enable the Block Volume Management plugin

Follow Oracle’s instructions to enable the plugin on the instance:

- `https://docs.oracle.com/iaas/Content/Block/Tasks/enablingblockvolumemanagementplugin.htm`

## Step 2 - Create a multipath-enabled iSCSI attachment (UHP)

Follow Oracle’s instructions for creating a multipath-enabled attachment to an Ultra High Performance volume:

- `https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/configuringmultipathattachments.htm`

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

## Step 5 - Troubleshooting

Use Oracle’s official troubleshooting and verification guidance:

- Multipath check: `https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/multipathcheck.htm`
- Troubleshooting: `https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/troubleshootingmultipathattachments.htm`

