# Sprint 23 - Implementation

Status: Done

## Summary

Sprint 23 is Sprint 22 plus an explicit dm-multipath load-balancing configuration applied for the multipath phase (round-robin intent). The sprint keeps the Sprint 20 A/B core as the stable benchmark engine and layers configuration + evidence collection on top.

## Entry Scripts

- `tools/run_bv4db_multipath_diag_sprint23.sh`
- `tools/run_bv4db_fio_multipath_ab_sprint23.sh`

## Guest Scripts

- `tools/guest/bv4db_sprint23_fstab.sh`

## Notes

- Sprint 23 focuses on making the HA vs load-balancing distinction explicit and testable.
- The primary acceptance evidence is **path distribution**, not throughput increase.
