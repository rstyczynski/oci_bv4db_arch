# Sprint 18 Summary

## Scope

- Multi-volume Oracle-style benchmark topology on a UHP-sized compute profile
- Phase 1: Oracle-style `fio` with guest `iostat` and OCI metrics
- Phase 2: Oracle Database Free `Swingbench` with guest `iostat`, OCI metrics, and AWR

## Phase Windows

- FIO phase: `2026-04-23T20:22:58Z` -> `2026-04-23T20:40:28Z`
- Swingbench phase: `2026-04-23T21:43:45Z` -> `2026-04-23T22:18:01Z`
- AWR snapshots: `1` -> `2`

## FIO Highlights

- `data-8k`: read `56.75 MiB/s`, write `24.32 MiB/s`
- `data-8k`: read `56.76 MiB/s`, write `24.32 MiB/s`
- `data-8k`: read `56.78 MiB/s`, write `24.31 MiB/s`
- `data-8k`: read `56.8 MiB/s`, write `24.3 MiB/s`
- `redo`: read `0.0 MiB/s`, write `2.69 MiB/s`
- `fra-1m`: read `11.94 MiB/s`, write `11.62 MiB/s`

## Swingbench Highlights

- Benchmark: `"Order Entry (PLSQL) V2"`
- Run time: `0:15:00`
- Completed transactions: `1319532`
- Failed transactions: `0`
- Average TPS: `1466.15`
- Maximum transaction rate: `89880`

## HTML Reports

- `fio_report.html`
- `fio_oci_metrics_report.html`
- `swingbench_report.html`
- `swingbench_oci_metrics_report.html`
- `awr_report.html`

## Consolidated Conclusion

- Sprint 18 combines storage-only stress and database-level stress on one repeatable Oracle-style topology.
- The result set now aligns benchmark output, guest `iostat`, OCI metrics, and AWR into one end-to-end benchmark package.
- The final Swingbench OCI metrics report includes both the attached block volumes and the `boot_volume`, so the evidence set can explicitly distinguish database I/O on the intended Oracle storage layout from residual boot-volume activity.
