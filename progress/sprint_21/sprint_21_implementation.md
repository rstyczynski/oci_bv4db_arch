# Sprint 21 - Implementation

Status: None

## Summary

Sprint 21 reuses Sprint 20 provisioning and A/B benchmarking approach, but adds:

- `/etc/fstab` entry management for the benchmark mountpoint using `_netdev,nofail`
- operator manual guidance for enabling/disabling multipath via fstab + iSCSI sessions

## Entry scripts

- `tools/run_bv4db_multipath_diag_sprint21.sh`
- `tools/run_bv4db_fio_multipath_ab_sprint21.sh`

## Guest-side behavior (fstab)

- Scripts manage a tagged fstab line for the sprint mountpoint:
  - `defaults,_netdev,nofail`
  - device is updated per mode:
    - multipath: consistent device path `/dev/oracleoci/oraclevdb` (or mapper path when required)
    - single-path: raw `/dev/disk/by-path/ip-...-lun-*` (auto-discovered)

## Notes

- `/etc/fstab` is not automatically managed by OCI; it is an OS responsibility.
- See Oracle guidance: `fstab Options for Block Volumes Using Consistent Device Paths`.

