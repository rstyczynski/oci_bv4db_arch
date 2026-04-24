# Sprint 17 Summary

## Scope

- Multi-volume Oracle-style benchmark topology on a UHP-sized compute profile
- Phase 1: Oracle-style `fio` with guest `iostat` and OCI metrics
- Phase 2: Oracle Database Free `Swingbench` with guest `iostat`, OCI metrics, and AWR

## Executed Profile

- Live execution date: `2026-04-23`
- Requested compute profile: `VM.Standard.E5.Flex 40 OCPUs / 64 GB`
- Actual compute profile used: `VM.Standard.E5.Flex 20 OCPUs / 64 GB`
- FIO runtime override used for the live validation run: `60 seconds`
- Swingbench runtime override used for the live validation run: `60 seconds`

## Phase Windows

- FIO phase: `2026-04-23T16:05:39Z` -> `2026-04-23T16:14:55Z`
- Swingbench phase: `2026-04-23T16:21:47Z` -> `2026-04-23T16:25:46Z`
- AWR snapshots: `1` -> `2`

## FIO Highlights

- `data-8k`: read `103.13 MiB/s`, write `44.25 MiB/s`
- `data-8k`: read `103.22 MiB/s`, write `44.12 MiB/s`
- `data-8k`: read `103.27 MiB/s`, write `44.18 MiB/s`
- `data-8k`: read `103.23 MiB/s`, write `44.12 MiB/s`
- `redo`: read `0.0 MiB/s`, write `2.76 MiB/s`
- `fra-1m`: read `23.74 MiB/s`, write `23.14 MiB/s`

## Swingbench Highlights

- Benchmark: `"Order Entry (PLSQL) V2"`
- Run time: `0:01:00`
- Completed transactions: `126939`
- Failed transactions: `0`
- Average TPS: `2115.65`

## HTML Reports

- `fio_report.html`
- `fio_oci_metrics_report.html`
- `swingbench_report.html`
- `swingbench_oci_metrics_report.html`
- `awr_report.html`

## Consolidated Conclusion

- Sprint 17 combines storage-only stress and database-level stress on one repeatable Oracle-style topology.
- The result set now aligns benchmark output, guest iostat, OCI metrics, and AWR into one end-to-end benchmark package.

## Conclusions for future sprints

- **Hard-validate DB file placement before Swingbench starts**:
  - prove datafiles, redo logs, and FRA are placed on `/u02`, `/u03`, `/u04`
  - archive placement evidence as sprint artifacts so topology issues can be detected without ambiguity
- **Use benchmark-quality durations**:
  - run `Swingbench` (and preferably `fio`) for `900s` so OCI Monitoring 1-minute metrics have enough overlap for correlation
- **Treat overlap `n` as evidence quality**:
  - correlations computed on small overlaps can be misleading; avoid drawing conclusions when overlap counts are low
