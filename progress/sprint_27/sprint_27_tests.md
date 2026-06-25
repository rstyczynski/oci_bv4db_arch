# Sprint 27 - Test Execution Results

## Summary

| Gate | Result | Retries | Pass Rate |
| ---- | ------ | ------- | --------- |
| A3 Integration - full Sprint 27 matrix | PASS | 1 | 100% |
| Focused TC4 consistent-path rerun | PASS | 0 | 100% |
| B3 Integration | Not run | 0 | n/a |

## Artifacts

| Gate | Log File |
| ---- | -------- |
| A3 Integration - full Sprint 27 matrix | `test_run_A3_integration_20260625_012045.log` |
| Evidence | `vpu_upgrade_multipath_evidence_20260624_232047.txt` |
| Focused TC4 consistent-path rerun | `test_run_TC4_linux_clean_20260625_093221.log` |
| Focused TC4 evidence | `vpu_upgrade_multipath_evidence_20260625_073223.txt` |
| B3 Integration | Not run; Sprint 27 uses live OCI discovery and no separate regression scope was executed |

## Full Matrix Result

The passing full-matrix evidence is `vpu_upgrade_multipath_evidence_20260624_232047.txt`.

Observed sequence:

- Baseline OCI attachment at `20` VPUs/GB was non-multipath.
- Linux manually connected to the non-UHP iSCSI target with `iscsiadm`.
- Linux discovered `/dev/sdb`, created ext4, wrote `stable.bin`, and verified checksum before detach.
- Linux unmounted and logged out of iSCSI before OCI detach.
- OCI detached, updated the volume to `100` VPUs/GB, and reattached.
- OCI reported `is_multipath=true` with `multipath_devices=4`.
- Linux discovered `/dev/mapper/mpatha` with active paths and verified the original checksum read-only.
- TC1 result: in-place `20 -> 100` VPU update without detach stayed non-multipath.
- TC2 result: detach, update to `100`, and reattach produced OCI multipath and the OCI-agent consistent path.
- TC3 result: unsafe detach with mounted writer was captured on disposable data; the stable file survived in this run, but read-only `e2fsck` reported filesystem errors.
- TC4 result: clean Linux release, detach, update, reattach, agent path wait, read-only filesystem check, and checksum verification all passed.

## Focused TC4 Consistent-Path Rerun

The focused rerun after updating the baseline path logic is `test_run_TC4_linux_clean_20260625_093221.log`.

Observed sequence:

- Baseline OCI attachment at `20` VPUs/GB was non-multipath: `is_multipath=null`, `multipath_devices=0`.
- Linux manually connected to the non-UHP iSCSI target with `iscsiadm`.
- TC4 waited for the configured OCI consistent path `/dev/oracleoci/oraclevdb`; it was absent on poll 1 and ready on poll 2.
- The baseline consistent path resolved as `/dev/oracleoci/oraclevdb -> ../sdb`; TC4 used `/dev/oracleoci/oraclevdb` as the baseline device.
- After clean unmount, iSCSI logout, OCI detach, VPU update to `100`, and reattach, OCI reported `is_multipath=true`.
- The OCI agent and Linux multipath stack remapped the same consistent path as `/dev/oracleoci/oraclevdb -> /dev/mapper/mpatha -> /dev/dm-2`.
- Checksum verification passed after read-only mount through `/dev/oracleoci/oraclevdb`.
- Result: `20 passed, 0 failed`.

## Overall Results

| Scope | Scripts Passed | Scripts Failed | Status |
| ----- | -------------- | -------------- | ------ |
| New-code integration | 23 | 0 | PASS |
| Focused TC4 consistent-path rerun | 20 | 0 | PASS |
| Regression integration | n/a | n/a | Not run |
