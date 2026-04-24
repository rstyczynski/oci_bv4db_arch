# Sprint 16 Correlation Analysis

## Retrospective Status

Retrospective verdict: failed.

This analysis was completed before the Sprint 18 storage-placement defect was fully proven, but the failure was already visible in the archived workload evidence. During Sprint 17 Swingbench, guest `iostat` did not sustain the expected data-volume traffic on attached block volumes, the attached block-volume OCI metrics were nearly all zero, and the boot device showed strong activity. Sprint 16 should have treated that contradiction as invalid correlation evidence rather than accepting it as a usable multi-volume dataset.

## Scope

This document completes:

- `BV4DB-37`: compare Oracle Database Free benchmark evidence with `fio` baselines
- `BV4DB-40`: correlate AWR evidence with OCI and guest benchmark metrics

The analysis uses archived artifacts only. No OCI rerun was required because the source evidence already exists.

This was the key mistake: artifact existence was validated, but the workload-to-storage correlation evidence was not challenged when the attached volumes appeared idle during Swingbench.

## Source Evidence

### Storage-only baselines

- Sprint 10: `progress/sprint_10/oci_performance_tier_comparison.md`
- Sprint 10: `progress/sprint_10/fio-results-oracle-hp-single-4k-redo-integration.json`
- Sprint 10: `progress/sprint_10/fio-results-oracle-hp-multi-4k-redo-integration.json`
- Sprint 12: `progress/sprint_12/oci-metrics-report.html`

### Database-level references

- Sprint 15: `progress/sprint_15/swingbench_results_db.json`
- Sprint 15: `progress/sprint_15/awr_report.html`
- Sprint 17: `progress/sprint_17/fio_results.json`
- Sprint 17: `progress/sprint_17/fio_iostat.json`
- Sprint 17: `progress/sprint_17/fio_oci_metrics_report.md`
- Sprint 17: `progress/sprint_17/swingbench_results_db.json`
- Sprint 17: `progress/sprint_17/swingbench_iostat.json`
- Sprint 17: `progress/sprint_17/swingbench_oci_metrics_report.md`
- Sprint 17: `progress/sprint_17/awr_report.html`

## What fio proves well

`fio` is the cleanest way to prove storage-domain behavior and upper storage headroom.

Sprint 10 already showed the main Oracle-storage pattern:

- Higher Performance single-volume baseline: `DATA` about `77.29 MiB/s` read and `33.13 MiB/s` write, `REDO` about `0.23 MiB/s` write, `FRA` about `120 MiB/s` read and write on the same shared device domain
- Higher Performance multi-volume baseline: `DATA` about `163.90 MiB/s` read and `70.19 MiB/s` write, `REDO` about `3.00 MiB/s` write, `FRA` about `29.37/29.22 MiB/s`

That difference matters because the separated layout raises `DATA` and `REDO` headroom while keeping `FRA` isolated instead of letting it consume the same contention domain.

Sprint 17 confirms that the multi-volume UHP path still behaves like the established Oracle-style storage baseline:

- `DATA` jobs together delivered about `412.85 MiB/s` read and `176.67 MiB/s` write
- `REDO` delivered about `2.76 MiB/s` write
- `FRA` delivered about `23.74 MiB/s` read and `23.14 MiB/s` write

That is directionally close to the earlier Sprint 10 UHP reference of about `430.76 MiB/s` read and `184.55 MiB/s` write for `DATA`, `3.09 MiB/s` for `REDO`, and `23.57/23.31 MiB/s` for `FRA`. The shorter Sprint 17 validation run therefore still looks like the same storage topology and not like a broken rerun.

## What fio cannot prove by itself

`fio` cannot tell the operator which database-visible cost dominates an Oracle workload.

It does not show:

- whether commits are bottlenecked by `log file sync`
- whether Oracle is CPU-bound or wait-bound
- how much physical read and write volume Oracle actually generated
- whether a storage headroom increase changed database throughput or only preserved margin

For those questions, `Swingbench` and AWR are required.

## Sprint 15 versus fio baselines

Sprint 15 is the standardized database-load reference. It uses the repository-owned Swingbench config and records:

- runtime `0:05:00`
- `449863` completed transactions
- `1499.54` average TPS
- AWR snapshots `1 -> 2`

The key AWR signals from Sprint 15 are:

- `DB CPU` `693.21 s`, about `52.23%` of DB time
- `log file sync` `231,700` waits, about `191.5 s` total wait time, average wait about `826.63 us`
- `db file sequential read` `355,914` waits, about `5 s` total wait time, average wait about `12.95 us`
- `redo size` about `2.82 GB`
- `physical read total bytes` about `6.87 GB`
- `physical write total bytes` about `14.61 GB`

That result already shows what `fio` alone cannot show:

- the dominant database wait is not random-read latency but commit-related `log file sync`
- `db file sequential read` is present but cheap at roughly tens of microseconds
- the workload is a mixed database workload with much heavier physical writes than reads

So Sprint 15 proves that a storage benchmark and a database benchmark are not interchangeable. The storage benchmark can show headroom, but AWR is needed to explain why database throughput landed where it did.

## Sprint 17 as the full correlation run

Sprint 17 is the first archived run where the same sprint contains:

- storage-only `fio`
- database-level `Swingbench`
- guest `iostat`
- OCI metrics
- AWR

That makes Sprint 17 the strongest correlation dataset in the repository.

### 1. fio phase

Guest `iostat` during the Sprint 17 `fio` phase shows the expected storage-stress pattern:

- `dm-4` averaged about `286.78 MiB/s` writes
- `sdb` and `sdg` each averaged about `143 MiB/s` writes
- `sdn` averaged about `25.54 MiB/s` writes for the redo side

OCI metrics for the same FIO window tell the same story from the provider side:

- `data1` peaked at about `2018.60 MiB` read and `3392.08 MiB` write per interval
- `data2` peaked at about `1060.00 MiB` read and `2111.01 MiB` write per interval
- `redo1` and `redo2` showed sustained write activity with peaks around `559-564 MiB` per interval
- `fra` showed the strongest large-block write path with average write throughput about `2235.20 MiB` per interval

The important point is not the exact absolute equivalence between guest and OCI numbers. The important point is alignment:

- guest `iostat` shows which devices were active
- OCI metrics show that the corresponding OCI block volumes were the active resources in the same window
- the pattern still matches the Oracle-style separation proven in earlier `fio` sprints

### 2. Swingbench phase

Sprint 17 `Swingbench` is shorter than Sprint 15, so it is not a fair throughput comparison. Even so, it is the best correlation run:

- runtime `0:01:00`
- `126939` completed transactions
- `2115.65` average TPS

Guest `iostat` during Sprint 17 `Swingbench` shows a much lighter and more mixed pattern than the `fio` phase:

- `dm-4` averaged about `34.94 MiB/s` read and `43.64 MiB/s` write
- `dm-2` and `dm-3` each averaged about `17.5 MiB/s` read and `21.8 MiB/s` write
- redo-side activity was present but far below the synthetic `fio` stress level

OCI metrics for the same Swingbench window show:

- compute CPU utilization averaging about `2.66%`
- compute memory utilization averaging about `6.59%`
- compute disk writes averaging about `32.04 MiB/s`

The block volume OCI metrics for the Swingbench phase are present but nearly all zeros at the per-volume level. This is not an archive gap. It is a measurement-granularity limitation of the shortened `60s` live validation run against `1m` OCI resolution. The guest `iostat`, Swingbench counters, and AWR still provide usable correlation for the phase.

## AWR correlation with guest and OCI observations

The Sprint 17 AWR report shows:

- `DB CPU` `201.50 s`, about `35.92%` of DB time
- `log file sync` `67,168` waits, about `43.4 s` total wait time, average wait about `646 us`
- `db file sequential read` `130,966` waits, about `1 s` total wait time, average wait about `10.14 us`
- `redo size` about `1.73 GB`
- `physical read total bytes` about `5.33 GB`
- `physical write total bytes` about `8.30 GB`

This lines up with the other two observation layers:

- AWR says commits and CPU dominate, not random-read waits
- guest `iostat` shows ongoing read and write activity, but far below the synthetic storage ceiling proven by the `fio` phase
- OCI compute metrics show modest CPU and write throughput rather than a saturated host

That combined picture is the main Sprint 16 result:

- the storage path has much more stress capacity under `fio` than the database workload actually consumes under this Swingbench profile
- the database workload is shaped more by commit behavior and CPU share than by block-volume random-read latency

## Directional comparison: Sprint 15 and Sprint 17

These two runs are not directly comparable because topology and duration differ, but they still show a useful trend.

Sprint 15:

- single-volume Oracle DB Free benchmark reference
- `1499.54` average TPS over `5` minutes
- `log file sync` average wait about `826.63 us`
- `DB CPU` about `52.23%` of DB time

Sprint 17:

- multi-volume Oracle-style topology with correlated storage and database evidence
- `2115.65` average TPS over `1` minute
- `log file sync` average wait about `646 us`
- `DB CPU` about `35.92%` of DB time

The direction is favorable to the multi-volume run, but Sprint 16 should not overclaim:

- Sprint 17 used a shorter database run
- Sprint 17 also used a different overall infrastructure profile
- the safe conclusion is not "Sprint 17 is definitively faster"
- the safe conclusion is that Sprint 17 proves the multi-volume topology can support the standardized database workload while preserving clear observability across storage, guest, OCI, and AWR layers

## Practical conclusions

1. `fio` is the right tool to validate storage headroom and Oracle-style domain separation.
2. `Swingbench` plus AWR is the right tool to explain database-visible bottlenecks and workload mix.
3. Sprint 15 established the standardized database-load path and project-owned config.
4. Sprint 17 closed the observability loop by adding `fio`, guest `iostat`, OCI metrics, and AWR in one sprint.
5. No required Sprint 15 or Sprint 17 source artifact is missing, so Sprint 16 did not need a rerun.
6. For future database scenario sprints, OCI metrics collection should prefer benchmark windows longer than one resolution bucket if per-volume OCI metrics are expected to be analytically strong.
