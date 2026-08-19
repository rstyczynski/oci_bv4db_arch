# Sprint 30 attempt report: REGULAR_BASELINE_INITIAL_initial_1

## Result

- Candidate: `REGULAR_BASELINE_INITIAL`
- Repetition: `1`
- VPU tier: `50 VPUs/GB`
- Final recorded state: `passed`
- Started: `2026-08-19T01:30:11Z`
- Ended: `2026-08-19T01:45:51Z`
- Measured attempt duration: `940 seconds`
- FIO exit code: `0`

## Performance summary

| Metric | Result |
| --- | ---: |
| DATA read IOPS (all four jobs) | 33608.23 |
| DATA write IOPS (all four jobs) | 14393.43 |
| DATA total IOPS | 48001.66 |
| REDO write IOPS | 730.85 |
| REDO write throughput (MiB/s) | 2.85 |
| REDO write latency p95 (ms) | 0.594 |
| REDO write latency p99 (ms) | 0.717 |
| REDO write latency p99.9 (ms) | 0.971 |
| FRA aggregate throughput (MiB/s) | 93.75 |
| Host CPU mean (%) | 34.06 |
| Mean FIO process CPU (%) | 9.51 |

## Per-job results

| Job | Read IOPS | Write IOPS | Read MiB/s | Write MiB/s | Write p99 ms | Write p99.9 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `data-8k#1` | 8398.35 | 3599.78 | 65.61 | 28.12 | 14.615 | 19.268 |
| `data-8k#2` | 8394.72 | 3596.14 | 65.58 | 28.09 | 14.615 | 19.268 |
| `data-8k#3` | 8409.40 | 3600.37 | 65.70 | 28.13 | 14.615 | 19.268 |
| `data-8k#4` | 8405.76 | 3597.14 | 65.67 | 28.10 | 14.615 | 19.268 |
| `redo#5` | 0.00 | 730.85 | 0.00 | 2.85 | 0.717 | 0.971 |
| `fra-1m#6` | 47.16 | 46.58 | 47.16 | 46.59 | 137.363 | 154.141 |

## Safety and evidence gates

- Restoration state: `restored`
- Restoration checks passed: `yes`
- Restored controls byte-equal to baseline: `yes`
- Sentinels valid: `yes`
- Rollback lease disarmed: `yes`
- Monitored error counters clean: `yes`

This attempt is eligible for aggregate baseline or candidate analysis only when its final state is `passed` and all safety gates above are `yes`.

## Evidence files

- [fio.json](fio.json)
- [fio.log](fio.log)
- [fio_report.html](fio_report.html)
- [iostat.json](iostat.json)
- [attempt.json](attempt.json)
- [state.json](state.json)
- [restoration_checks.json](restoration_checks.json)
- [controls_before.json](controls_before.json)
- [controls_applied.json](controls_applied.json)
- [controls_restored.json](controls_restored.json)
- [errors_before.json](errors_before.json)
- [errors_after.json](errors_after.json)
- [guest_preflight.json](guest_preflight.json)
- [oci_preflight.json](oci_preflight.json)
