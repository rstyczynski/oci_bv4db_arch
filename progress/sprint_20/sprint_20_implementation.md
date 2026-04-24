# Sprint 20 - Implementation

## Backlog Items

- BV4DB-50. UHP multipath diagnostics sandbox host
- BV4DB-51. FIO benchmark: multipath vs single-path iSCSI on UHP

## Scripts

- `tools/run_bv4db_multipath_diag_sprint20.sh`
  - provisions compute + single UHP block volume
  - enables iSCSI multipath on guest
  - collects diagnostics and archives artifacts under `progress/sprint_20/`
  - tears down resources

- `tools/run_bv4db_fio_multipath_ab_sprint20.sh`
  - runs A/B: multipath vs single-path
  - preferred load generator: `fio`
  - fallback load generator: parallel `dd` workers (`DD_JOBS`)
  - archives artifacts under `progress/sprint_20/`
  - tears down resources

## Artifacts

- `progress/sprint_20/multipath_diagnostics_*.txt`
- `progress/sprint_20/diag_multipath_*.txt`
- `progress/sprint_20/diag_singlepath_*.txt`
- `progress/sprint_20/fio_multipath_*.json`
- `progress/sprint_20/fio_singlepath_*.json`
- `progress/sprint_20/dd_multipath_*.txt` (only when dd fallback used)
- `progress/sprint_20/dd_singlepath_*.txt` (only when dd fallback used)
- `progress/sprint_20/fio_compare_*.md`
- `progress/sprint_20/state-bv4db-s20-*.json`
