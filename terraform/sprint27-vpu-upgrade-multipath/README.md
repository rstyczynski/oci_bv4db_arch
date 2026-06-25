# Sprint 27 - Non-UHP to UHP VPU Update Multipath Probe

This module creates the baseline for BV4DB-61. It creates one Oracle Linux instance with the Block Volume Management plugin enabled, one block volume below UHP level, and one native iSCSI attachment with an OCI consistent device path. The live probe defaults to the `avq3` OCI profile.

The live integration test captures the initial non-UHP evidence, detaches the volume, updates the detached volume to `100` VPUs/GB, and then attaches the now-UHP volume with the same persistent device path. The module intentionally avoids guest-side iSCSI login, guest multipath setup, raw API helpers, and provider fields that force the agent path.

## Oracle References

- <https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/configuringmultipathattachments.htm>
- <https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/enablingblockvolumemanagementplugin.htm>

## Validation

Run the live integration test:

```bash
tests/run.sh --integration --new-only progress/sprint_27/new_tests.manifest
```

The test archives evidence under `progress/sprint_27/` and records whether multipath appears in place after the VPU update, appears only after reattach or reboot, or does not appear.
