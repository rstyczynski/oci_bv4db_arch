# Sprint 22 — Bug Report

## BUG-1: “multipath == single-path performance” (false result)

### Summary

In early Sprint 22 A/B runs, the reported multipath and single-path performance was identical (or near-identical), suggesting multipath was not working. This was **a false result**: multipath was functioning on the instance, but the benchmark was unintentionally executed on the **boot/root volume** because the Sprint mountpoint was **not mounted**.

### Impact

- A/B comparison results were invalid for those runs.
- It looked like “multipath doesn’t work” even though iSCSI sessions and multipath mapping were present.

### Where it showed up

Example invalid comparison:
- `progress/sprint_22/fio_compare_20260425_195158.md`
  - multipath: 11.87 MB/s
  - single-path: 11.90 MB/s

### Expected

- Multipath run should mount the BV via a mapper device:
  - `/mnt/sprint22` mounted from `/dev/mapper/mpath*` or `/dev/dm-*`
- Single-path run should mount from a raw iSCSI device:
  - `/dev/sdX` or `/dev/disk/by-path/...`
- fio JSON `disk_util` should show activity on the BV devices (mapper device for multipath, raw disk for single-path), not only on the root disk.

### Actual

For the invalid run:
- fio JSON `disk_util` only contained the boot/root device:
  - multipath result: `disk_util = ['dm-0', 'sda']`
  - single-path result: `disk_util = ['dm-0', 'sda']`

This indicates fio ran on the root filesystem because `/mnt/sprint22` was not mounted to the BV.

### Evidence

1) fio results show root disk only

- `progress/sprint_22/fio_multipath_20260425_195158.json` → `disk_util` lists `dm-0`/`sda`
- `progress/sprint_22/fio_singlepath_20260425_195158.json` → `disk_util` lists `dm-0`/`sda`

2) Multipath was actually configured on the guest

- `progress/sprint_22/diag_multipath_20260425_195158.txt`
  - `iscsiadm -m session` shows 5 sessions (targets `169.254.2.2`..`169.254.2.6`)
  - `multipath -ll` shows `mpatha`
  - `lsblk` shows `mpatha` exists

Therefore, multipath was present, but the benchmark target filesystem was wrong/unmounted.

### Root cause

Two contributing factors:

1) **No hard validation that `/mnt/sprint22` was mounted** to the intended device before running fio.
   - When the mount didn’t happen, fio still ran and wrote to a directory on `/` (root filesystem).

2) **fstab + systemd mount unit confusion when switching modes**
   - `/etc/fstab` was being updated during the run, but systemd’s generated unit (`mnt-sprint22.mount`) could keep stale “What=” device bindings.
   - Without a `systemctl daemon-reload`, and without removing prior `/mnt/sprint22` entries consistently, systemd could unmount the mountpoint when the previous device disappeared during mode switching.
   - Additionally, the tag used to manage entries was not being passed consistently, leading to stale entries from other sprints affecting `/mnt/sprint22`.

### Fix / Mitigation

Implemented guardrails in the A/B script so this cannot silently produce invalid results:

- **Mountpoint assertions**:
  - After filesystem preparation, assert that `/mnt/sprint22` is mounted.
  - In multipath mode, assert mount source is a mapper device (`/dev/mapper/*` or `/dev/dm-*`).
  - In single-path mode, assert mount source is **not** a mapper device.

- **fstab update hardening**:
  - Pass a sprint-specific `FSTAB_TAG` (Sprint 22 uses `bv4db-sprint22`).
  - Remove any existing active entry for the mountpoint before adding a new one.
  - Run `systemctl daemon-reload` after changing `/etc/fstab`.

### How to verify (post-fix)

Run Sprint 22 A/B and confirm in logs:

- multipath assertion prints: `mounted source=/dev/mapper/mpatha`
- single-path assertion prints: `mounted source=/dev/sdX`

and confirm fio JSON `disk_util` contains BV devices rather than only `dm-0`/`sda`.

