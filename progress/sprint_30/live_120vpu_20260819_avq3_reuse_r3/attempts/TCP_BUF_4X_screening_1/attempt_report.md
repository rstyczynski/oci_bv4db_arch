# Sprint 30 attempt report: TCP_BUF_4X_screening_1

## Result

- Candidate: `TCP_BUF_4X`
- Repetition: `1`
- VPU tier: `50 VPUs/GB`
- Final recorded state: `passed`
- Started: `2026-08-19T13:43:48Z`
- Ended: `2026-08-19T13:54:50Z`
- Measured attempt duration: `662 seconds`
- FIO exit code: `0`

## Performance summary

| Metric | Result |
| --- | ---: |
| DATA read IOPS (all four jobs) | 46375.27 |
| DATA write IOPS (all four jobs) | 19861.49 |
| DATA total IOPS | 66236.76 |
| REDO write IOPS | 2011.17 |
| REDO write throughput (MiB/s) | 7.86 |
| REDO write latency p95 (ms) | 0.709 |
| REDO write latency p99 (ms) | 0.954 |
| REDO write latency p99.9 (ms) | 2.343 |
| FRA aggregate throughput (MiB/s) | 175.78 |
| Host CPU mean (%) | 38.52 |
| Mean FIO process CPU (%) | 12.89 |

## Per-job results

| Job | Read IOPS | Write IOPS | Read MiB/s | Write MiB/s | Write p99 ms | Write p99.9 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `data-8k#1` | 11593.17 | 4967.54 | 90.57 | 38.81 | 3.195 | 5.538 |
| `data-8k#2` | 11591.41 | 4967.10 | 90.56 | 38.81 | 3.195 | 5.538 |
| `data-8k#3` | 11594.00 | 4964.50 | 90.58 | 38.79 | 3.195 | 5.538 |
| `data-8k#4` | 11596.69 | 4962.35 | 90.60 | 38.77 | 3.195 | 5.538 |
| `redo#5` | 0.00 | 2011.17 | 0.00 | 7.86 | 0.954 | 2.343 |
| `fra-1m#6` | 88.03 | 87.74 | 88.03 | 87.75 | 72.876 | 78.119 |

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
