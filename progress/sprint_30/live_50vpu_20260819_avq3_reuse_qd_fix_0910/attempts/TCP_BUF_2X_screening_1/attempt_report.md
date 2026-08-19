# Sprint 30 attempt report: TCP_BUF_2X_screening_1

## Result

- Candidate: `TCP_BUF_2X`
- Repetition: `1`
- VPU tier: `50 VPUs/GB`
- Final recorded state: `passed`
- Started: `2026-08-19T09:21:50Z`
- Ended: `2026-08-19T09:32:52Z`
- Measured attempt duration: `662 seconds`
- FIO exit code: `0`

## Performance summary

| Metric | Result |
| --- | ---: |
| DATA read IOPS (all four jobs) | 33619.20 |
| DATA write IOPS (all four jobs) | 14398.30 |
| DATA total IOPS | 48017.51 |
| REDO write IOPS | 2132.59 |
| REDO write throughput (MiB/s) | 8.33 |
| REDO write latency p95 (ms) | 0.635 |
| REDO write latency p99 (ms) | 0.791 |
| REDO write latency p99.9 (ms) | 1.286 |
| FRA aggregate throughput (MiB/s) | 93.75 |
| Host CPU mean (%) | 33.77 |
| Mean FIO process CPU (%) | 9.92 |

## Per-job results

| Job | Read IOPS | Write IOPS | Read MiB/s | Write MiB/s | Write p99 ms | Write p99.9 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `data-8k#1` | 8398.74 | 3600.08 | 65.62 | 28.13 | 14.352 | 19.005 |
| `data-8k#2` | 8403.71 | 3600.00 | 65.65 | 28.13 | 14.352 | 19.005 |
| `data-8k#3` | 8405.09 | 3598.59 | 65.66 | 28.11 | 14.352 | 18.743 |
| `data-8k#4` | 8411.66 | 3599.63 | 65.72 | 28.12 | 14.352 | 18.743 |
| `redo#5` | 0.00 | 2132.59 | 0.00 | 8.33 | 0.791 | 1.286 |
| `fra-1m#6` | 47.14 | 46.59 | 47.15 | 46.60 | 137.363 | 149.946 |

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
