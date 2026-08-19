# Sprint 30 attempt report: TCP_BUF_2X_screening_1

## Result

- Candidate: `TCP_BUF_2X`
- Repetition: `1`
- VPU tier: `50 VPUs/GB`
- Final recorded state: `passed`
- Started: `2026-08-19T13:32:25Z`
- Ended: `2026-08-19T13:43:26Z`
- Measured attempt duration: `661 seconds`
- FIO exit code: `0`

## Performance summary

| Metric | Result |
| --- | ---: |
| DATA read IOPS (all four jobs) | 45194.83 |
| DATA write IOPS (all four jobs) | 19355.99 |
| DATA total IOPS | 64550.83 |
| REDO write IOPS | 1974.15 |
| REDO write throughput (MiB/s) | 7.71 |
| REDO write latency p95 (ms) | 0.733 |
| REDO write latency p99 (ms) | 0.971 |
| REDO write latency p99.9 (ms) | 2.310 |
| FRA aggregate throughput (MiB/s) | 175.78 |
| Host CPU mean (%) | 37.81 |
| Mean FIO process CPU (%) | 12.46 |

## Per-job results

| Job | Read IOPS | Write IOPS | Read MiB/s | Write MiB/s | Write p99 ms | Write p99.9 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `data-8k#1` | 11296.41 | 4841.41 | 88.25 | 37.82 | 3.162 | 5.341 |
| `data-8k#2` | 11298.78 | 4840.97 | 88.27 | 37.82 | 3.129 | 5.341 |
| `data-8k#3` | 11295.79 | 4837.22 | 88.25 | 37.79 | 3.129 | 5.407 |
| `data-8k#4` | 11303.86 | 4836.40 | 88.31 | 37.78 | 3.129 | 5.341 |
| `redo#5` | 0.00 | 1974.15 | 0.00 | 7.71 | 0.971 | 2.310 |
| `fra-1m#6` | 88.05 | 87.72 | 88.05 | 87.73 | 72.876 | 78.119 |

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
