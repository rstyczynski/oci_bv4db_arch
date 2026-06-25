# Sprint 27 - Documentation

## Operator Notes

Sprint 27 documentation is embedded in:

- `terraform/sprint27-vpu-upgrade-multipath/README.md`
- `progress/sprint_27/sprint_27_design.md`
- `progress/sprint_27/sprint_27_tests.md`
- `progress/sprint_27/linux_level_operations.md`

The live integration test writes its evidence file under `progress/sprint_27/`.

## Oracle References

Sprint 27 follows Oracle's Ultra High Performance attachment guidance:

- <https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/configuringmultipathattachments.htm>
- <https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/enablingblockvolumemanagementplugin.htm>
- <https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/connectingtoavolume.htm>
- <https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/connectingtoavolume_topic-Connecting_to_iSCSIAttached_Volumes.htm>
- <https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/connectingtouhpvolumes.htm>

The important behavior for this sprint is that multipath enablement is evaluated when a volume is attached. Therefore the sprint detaches the initial non-UHP attachment before changing the volume to `100` VPUs/GB, then attaches the now-UHP volume with the same persistent device path.

The Linux-side behavior is separate. A normal non-UHP iSCSI attachment is not automatically usable unless the attachment was configured for automatic connection; Linux must connect to the iSCSI target using the OCI attachment metadata. The UHP reattach path is different because OCI/agent-managed multipath creates the multipath-backed device after the UHP attachment.

## Test Analysis Summary

Sprint 27 evidence supports the operational rule:

`VPU change makes the volume eligible for UHP multipath, but the attachment operation is where OCI produces the multipath-enabled attachment.`

Observed cases:

- In-place `20 -> 100` VPU update without detach stayed non-multipath: `is_multipath=null`, `multipath_devices=0`.
- Detach, update to `100`, and reattach produced a multipath-enabled attachment: `is_multipath=true`, `multipath_devices=4`.
- Unsafe Linux procedure with a mounted writer process is a separate data-safety risk. OCI can still create a multipath attachment after reattach, but the Linux workload can see I/O or filesystem-level failure modes.
- Earlier failed TC4 attempts showed that after successful multipath reattach, remounting the old path could fail with `wrong fs type, bad option, bad superblock on /dev/mapper/mpatha`. A follow-up attempt also showed that the non-UHP baseline Linux device path could be missing when TC4 attempted `mkfs`, so that attempt did not actually create checksum data before detach. Therefore those attempts could not prove data loss. They proved TC4 needed a baseline Linux-device guard, post-reattach device rediscovery, read-only mount, and checksum validation before returning workload traffic.
- Corrected TC4 requested the fixed OCI device path `/dev/oracleoci/oraclevdb` on the attachment, but the non-UHP attachment was not auto-logged-in by Linux. After manual `iscsiadm` login, the script waited for the OCI consistent path. The focused rerun `test_run_TC4_linux_clean_20260625_093221.log` found it on poll 2 as `/dev/oracleoci/oraclevdb -> ../sdb`, used `/dev/oracleoci/oraclevdb` for baseline filesystem work, cleanly unmounted and logged out, detached, updated to `100`, reattached, and verified the checksum after the agent remapped the same consistent path to `/dev/mapper/mpatha`.
- Non-MP iSCSI mode and UHP MP mode have different path ownership, but the same OCI consistent path can be the operator-facing path when the OCI agent creates it. In non-MP mode, the operator script must connect with `iscsiadm`, wait briefly for `/dev/oracleoci/oraclevdb`, and use it if it appears. In the focused TC4 rerun it appeared as `/dev/oracleoci/oraclevdb -> ../sdb`; if it does not appear, the script must fall back to discovering the real Linux block device from the attachment metadata and device inventory, and must not hardcode `/dev/sdb`. In UHP MP mode, the OCI Block Volume Management plugin and Linux multipath stack create the mapper device and remap the OCI consistent path, for example `/dev/oracleoci/oraclevdb -> /dev/mapper/mpatha -> /dev/dm-2`. Operator scripts should use the OCI consistent path after it exists, and treat the mapper name as runtime evidence, not a stable configuration value.
- Persistent mounts and activation scripts must be updated when moving from non-MP to MP. Any previous reference to the old discovered `/dev/sdX` device must be removed from `/etc/fstab`, service units, database startup scripts, or operator scripts. After UHP multipath is active, use `/dev/oracleoci/oraclevdb` once it resolves to `/dev/mapper/mpath*`, or use a verified filesystem UUID/LVM/ASM identity that resolves through the multipath mapper.
- Passing evidence: `vpu_upgrade_multipath_evidence_20260624_232047.txt`.
- Clean A3 log: `test_run_A3_integration_20260625_012045.log` (`Results: 23 passed, 0 failed`).
- Focused TC4 consistent-path rerun: `test_run_TC4_linux_clean_20260625_093221.log` with evidence `vpu_upgrade_multipath_evidence_20260625_073223.txt` (`Results: 20 passed, 0 failed`).
- Conclusion: the VPU-to-UHP/multipath transition did not lose data in the positive procedure. The operator risk is wrong Linux handling: skipping clean release, assuming non-UHP auto-login, or remounting the wrong post-reattach path.
