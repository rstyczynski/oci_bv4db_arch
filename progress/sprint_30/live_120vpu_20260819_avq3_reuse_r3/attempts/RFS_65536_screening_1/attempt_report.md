# Sprint 30 attempt report: RFS_65536_screening_1

## Result

- Candidate: `RFS_65536`
- Repetition: `1`
- VPU tier: `50 VPUs/GB`
- Final recorded state: `passed`
- Started: `2026-08-19T14:41:35Z`
- Ended: `2026-08-19T14:52:37Z`
- Measured attempt duration: `662 seconds`
- FIO exit code: `0`

## Performance summary

| Metric | Result |
| --- | ---: |
| DATA read IOPS (all four jobs) | 43493.63 |
| DATA write IOPS (all four jobs) | 18624.55 |
| DATA total IOPS | 62118.18 |
| REDO write IOPS | 2109.51 |
| REDO write throughput (MiB/s) | 8.24 |
| REDO write latency p95 (ms) | 0.659 |
| REDO write latency p99 (ms) | 0.881 |
| REDO write latency p99.9 (ms) | 2.056 |
| FRA aggregate throughput (MiB/s) | 175.78 |
| Host CPU mean (%) | 36.61 |
| Mean FIO process CPU (%) | 12.03 |

## Per-job results

| Job | Read IOPS | Write IOPS | Read MiB/s | Write MiB/s | Write p99 ms | Write p99.9 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `data-8k#1` | 10868.45 | 4657.69 | 84.91 | 36.39 | 3.883 | 6.259 |
| `data-8k#2` | 10871.80 | 4657.39 | 84.94 | 36.39 | 3.883 | 6.259 |
| `data-8k#3` | 10873.10 | 4654.91 | 84.95 | 36.37 | 3.883 | 6.259 |
| `data-8k#4` | 10880.28 | 4654.56 | 85.00 | 36.36 | 3.883 | 6.259 |
| `redo#5` | 0.00 | 2109.51 | 0.00 | 8.24 | 0.881 | 2.056 |
| `fra-1m#6` | 88.03 | 87.74 | 88.04 | 87.74 | 72.876 | 78.119 |

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
