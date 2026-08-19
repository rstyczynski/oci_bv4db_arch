# Sprint 30 attempt report: NETDEV_BACKLOG_2X_screening_1

## Result

- Candidate: `NETDEV_BACKLOG_2X`
- Repetition: `1`
- VPU tier: `50 VPUs/GB`
- Final recorded state: `passed`
- Started: `2026-08-19T14:18:47Z`
- Ended: `2026-08-19T14:29:49Z`
- Measured attempt duration: `662 seconds`
- FIO exit code: `0`

## Performance summary

| Metric | Result |
| --- | ---: |
| DATA read IOPS (all four jobs) | 45789.38 |
| DATA write IOPS (all four jobs) | 19610.66 |
| DATA total IOPS | 65400.04 |
| REDO write IOPS | 2134.32 |
| REDO write throughput (MiB/s) | 8.34 |
| REDO write latency p95 (ms) | 0.635 |
| REDO write latency p99 (ms) | 0.831 |
| REDO write latency p99.9 (ms) | 1.843 |
| FRA aggregate throughput (MiB/s) | 175.78 |
| Host CPU mean (%) | 38.59 |
| Mean FIO process CPU (%) | 12.71 |

## Per-job results

| Job | Read IOPS | Write IOPS | Read MiB/s | Write MiB/s | Write p99 ms | Write p99.9 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `data-8k#1` | 11445.69 | 4904.51 | 89.42 | 38.32 | 3.064 | 5.210 |
| `data-8k#2` | 11446.98 | 4904.92 | 89.43 | 38.32 | 3.064 | 5.145 |
| `data-8k#3` | 11445.67 | 4901.35 | 89.42 | 38.29 | 3.064 | 5.210 |
| `data-8k#4` | 11451.05 | 4899.88 | 89.46 | 38.28 | 3.064 | 5.210 |
| `redo#5` | 0.00 | 2134.32 | 0.00 | 8.34 | 0.831 | 1.843 |
| `fra-1m#6` | 88.04 | 87.72 | 88.05 | 87.73 | 72.876 | 78.119 |

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
