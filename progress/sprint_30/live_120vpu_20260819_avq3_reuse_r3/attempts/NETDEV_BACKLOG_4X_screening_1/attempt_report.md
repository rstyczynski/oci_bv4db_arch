# Sprint 30 attempt report: NETDEV_BACKLOG_4X_screening_1

## Result

- Candidate: `NETDEV_BACKLOG_4X`
- Repetition: `1`
- VPU tier: `50 VPUs/GB`
- Final recorded state: `passed`
- Started: `2026-08-19T14:30:12Z`
- Ended: `2026-08-19T14:41:13Z`
- Measured attempt duration: `661 seconds`
- FIO exit code: `0`

## Performance summary

| Metric | Result |
| --- | ---: |
| DATA read IOPS (all four jobs) | 45233.60 |
| DATA write IOPS (all four jobs) | 19373.10 |
| DATA total IOPS | 64606.71 |
| REDO write IOPS | 2177.76 |
| REDO write throughput (MiB/s) | 8.51 |
| REDO write latency p95 (ms) | 0.618 |
| REDO write latency p99 (ms) | 0.807 |
| REDO write latency p99.9 (ms) | 1.729 |
| FRA aggregate throughput (MiB/s) | 175.78 |
| Host CPU mean (%) | 38.08 |
| Mean FIO process CPU (%) | 12.46 |

## Per-job results

| Job | Read IOPS | Write IOPS | Read MiB/s | Write MiB/s | Write p99 ms | Write p99.9 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `data-8k#1` | 11306.47 | 4845.82 | 88.33 | 37.86 | 2.966 | 4.817 |
| `data-8k#2` | 11308.12 | 4845.18 | 88.34 | 37.85 | 2.966 | 4.817 |
| `data-8k#3` | 11307.29 | 4842.34 | 88.34 | 37.83 | 2.998 | 4.882 |
| `data-8k#4` | 11311.73 | 4839.76 | 88.37 | 37.81 | 2.966 | 4.882 |
| `redo#5` | 0.00 | 2177.76 | 0.00 | 8.51 | 0.807 | 1.729 |
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
