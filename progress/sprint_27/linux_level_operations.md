# Sprint 27 - Linux-Level Operations for VPU 20 to 100 Reattach

## Scope

This note documents the Linux-side operation required when an OCI block volume was attached at a non-UHP performance level and is later changed to `100` VPUs/GB. Sprint 27 treats the OCI operation and the Linux data-safety operation as separate concerns:

- OCI multipath enablement requires detach, VPU update, and reattach so the new UHP attachment is evaluated during attachment.
- Linux data safety requires the guest to stop using the old block device before OCI detaches it.

## Positive Procedure

The clean Linux procedure is:

1. Stop the application or database workload using the filesystem or raw device.
2. For a non-UHP iSCSI attachment that was not created with OCI auto-connect, explicitly connect Linux to the iSCSI target using the attachment `iqn`, `ipv4`, and `port` from OCI attachment metadata.
3. After manual iSCSI login, give the OCI consistent device path a bounded wait window. If `/dev/oracleoci/oraclevdb` appears, use it and record its real target with `readlink -f`. In the focused Sprint 27 TC4 rerun this appeared on poll 2 as `/dev/oracleoci/oraclevdb -> ../sdb`.
4. If the consistent path does not appear, fall back to the actual discovered Linux block device for the baseline filesystem or storage layer. Do not hardcode `/dev/sdb`; resolve the usable device from the iSCSI attachment metadata and current block-device inventory.
5. Flush dirty writes with `sync`.
6. Unmount the filesystem, or deactivate the relevant storage layer for LVM, ASM, or a database raw-device layout.
7. Confirm the device is no longer mounted or held by the workload.
8. Log out of the baseline iSCSI session and remove the iSCSI node record.
9. Detach the block volume in OCI. The script uses OCI CLI `--force` only to skip the CLI confirmation prompt; the Linux release has already happened.
10. Update the volume to `100` VPUs/GB.
11. Reattach the volume with the persistent device path, for Sprint 27 `/dev/oracleoci/oraclevdb`.
12. Verify OCI reports `is_multipath=true` and multiple multipath devices.
13. Wait for the OCI Block Volume Management plugin and Linux multipath stack to expose the consistent device path. The positive Sprint 27 evidence showed `/dev/oracleoci/oraclevdb -> /dev/mapper/mpatha -> /dev/dm-2`.
14. Rediscover the post-reattach block device. Do not assume the old path can be mounted directly.
15. Check candidate devices with `lsblk -f`, `blkid`, `multipath -ll`, and `readlink -f /dev/oracleoci/oraclevdb`.
16. Validate the filesystem read-only first, for example `fsck.ext4 -fn <candidate>`.
17. Mount the discovered candidate read-only and verify checksum or application-level consistency.
18. Remount or reactivate the storage layer for normal use only after data validation passes.
19. Update persistent mount or activation configuration that referenced the old non-MP device. Do not keep `/dev/sdX` paths such as `/dev/sdb` in `/etc/fstab`, service units, database startup scripts, LVM filters, or operator scripts. After the UHP reattach, use the validated OCI consistent path, for example `/dev/oracleoci/oraclevdb`, or a stable filesystem UUID/LVM/ASM identity that resolves through the multipath mapper.

Sprint 27 validates this with an ext4 filesystem, checksum-verifiable disposable data, clean unmount, explicit iSCSI logout, detach-update-reattach, post-reattach multipath discovery, read-only mount, and checksum verification. The full-matrix passing evidence `vpu_upgrade_multipath_evidence_20260624_232047.txt` proved data preservation. The focused TC4 rerun `vpu_upgrade_multipath_evidence_20260625_073223.txt` additionally proved that the baseline non-MP phase can use `/dev/oracleoci/oraclevdb` when the agent creates it after manual iSCSI login, and that the same consistent path is later remapped to the multipath device.

For LVM-backed application volumes, keep first-time initialization separate from reconnect or upgrade handling. Commands such as `wipefs`, `pvcreate`, `vgcreate`, `lvcreate`, and `mkfs` are allowed only when the volume is known to be new and intentionally empty. During a VPU-to-UHP/multipath transition, the positive procedure must rediscover the existing PV/VG/LV metadata, run `pvscan`, `vgscan`, and `vgchange -ay`, then mount or validate the existing LV. A guard such as `pvs "$DEV" || wipefs/pvcreate` is dangerous in an upgrade path because `pvs` can fail when the path is temporarily missing, replaced by a multipath mapper, or filtered by LVM; treating that as "new empty disk" can destroy data.

Oracle documentation basis:

- For iSCSI-attached volumes, Linux must connect to the iSCSI target before the volume is usable unless automatic connection was configured.
- For Ultra High Performance multipath, OCI evaluates and configures multipath at attachment time, and the guest uses the multipath-backed device.
- The Block Volume Management plugin is required for the UHP multipath flow; it does not imply that every non-UHP iSCSI attachment is automatically logged in.
- The configured OCI device path in attachment metadata is not by itself proof that the same path exists inside Linux during a non-MP baseline. In non-MP mode the script owns iSCSI login, waits briefly for the consistent path, and falls back to real-device discovery if the path is absent. In the focused TC4 rerun the path appeared as `/dev/oracleoci/oraclevdb -> ../sdb`. In UHP MP mode the OCI agent and Linux multipath stack own the mapper and consistent-path remapping, observed as `/dev/oracleoci/oraclevdb -> /dev/mapper/mpatha -> /dev/dm-2`.

## Current Finding

Earlier failed runs showed:

- OCI detach, VPU update, and reattach succeeded.
- OCI reported `is_multipath=true` with `multipath_devices=4`.
- Linux remount through the previous device path failed with `wrong fs type, bad option, bad superblock on /dev/mapper/mpatha`.

One follow-up attempt showed an additional precondition failure: the non-UHP baseline Linux device `/dev/oracleoci/oraclevdb` was missing when TC4 attempted to create the filesystem. That run did not actually write checksum data before detach, so it cannot prove data loss after the VPU switch. The root cause was a wrong test assumption: Linux will not necessarily auto-login a normal non-UHP iSCSI attachment.

The corrected TC4 run proved the positive path:

- Baseline non-UHP attachment had `is_multipath=null`, `multipath_devices=0`, and `iscsi_login_state=UNKNOWN`.
- Linux manually connected with `iscsiadm` to the OCI attachment target, waited for the OCI consistent path, and found `/dev/oracleoci/oraclevdb -> ../sdb` on poll 2.
- TC4 created ext4 through `/dev/oracleoci/oraclevdb`, wrote `stable.bin`, and verified the checksum before detach.
- Linux unmounted and logged out of iSCSI before OCI detach.
- OCI detached, changed the volume to `100` VPUs/GB, and reattached.
- OCI reported `is_multipath=true` with `multipath_devices=4`.
- Linux waited for the OCI agent and multipath stack, then found `/dev/oracleoci/oraclevdb -> /dev/mapper/mpatha -> /dev/dm-2` with five active paths and the original ext4 UUID.
- Read-only mount through `/dev/oracleoci/oraclevdb` resolved to `/dev/mapper/mpatha` and verified `stable.bin` checksum successfully.

This is the key conclusion: data was not lost by the VPU-to-UHP/multipath transition when the baseline data existed and the Linux procedure rediscovered the correct multipath device. A first mount failure on an old or wrong path is not proof of data loss.

Persistent mount definitions must be treated as part of the transition. A mount that previously used the non-MP discovered device, for example `/dev/sdb`, must be changed before returning the workload. After UHP multipath is active, the old `/dev/sdX` device is a path member behind the multipath device and must not be used as the stable mount target. Use `/dev/oracleoci/oraclevdb` after it resolves to `/dev/mapper/mpath*`, or use a filesystem UUID/LVM/ASM name that is verified to resolve through the multipath mapper.

The TC4 test now proves data preservation by:

- collecting `lsblk`, `blkid`, `/dev/oracleoci`, `/dev/mapper`, `multipath -ll`, and `multipathd show paths`,
- probing candidate block devices with `fsck.ext4 -fn`,
- mounting candidates read-only,
- checking the saved checksum file.

Only a checksum failure after finding the correct device should be treated as evidence of data loss. A first mount failure is evidence that the procedure needs device rediscovery.

The final Sprint 27 A3 run is `test_run_A3_integration_20260625_012045.log` and finished with `Results: 23 passed, 0 failed`. The later focused TC4 consistent-path rerun is `test_run_TC4_linux_clean_20260625_093221.log` with evidence `vpu_upgrade_multipath_evidence_20260625_073223.txt`; it finished with `Results: 20 passed, 0 failed`.

## Negative Procedure

The unsafe negative test intentionally keeps a Linux writer process active on a mounted filesystem and then force-detaches the OCI attachment. This is disposable-data-only validation. The expected risk is not just a missing multipath flag; it is a Linux data-safety failure mode:

- the writer process can receive I/O errors,
- the mount can retain stale device state,
- the filesystem can require repair,
- checksum validation can fail,
- application-visible data loss or corruption can occur.

The test must never target real data. Its purpose is to prove why the Linux release procedure is mandatory before the OCI detach/update/reattach operation.

## Evidence Requirements

Each run should archive:

- OCI volume and attachment metadata before and after the operation,
- `is_multipath`, `multipath_devices`, and `iscsi_login_state`,
- Linux mount state with `findmnt`,
- block layout with `lsblk`,
- iSCSI sessions with `iscsiadm -m session`,
- multipath state with `multipath -ll` and `multipathd show paths`,
- checksum output before detach and after reattach,
- process status and kernel log tail for the unsafe negative test.
