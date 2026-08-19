# Sprint 30 attempt report: NETDEV_BACKLOG_4X_screening_1

## Result

- Candidate: `NETDEV_BACKLOG_4X`
- Repetition: `1`
- VPU tier: `50 VPUs/GB`
- Final recorded state: `passed`
- Started: `2026-08-19T10:19:42Z`
- Ended: `2026-08-19T10:30:43Z`
- Measured attempt duration: `661 seconds`
- FIO exit code: `0`

## Performance summary

| Metric | Result |
| --- | ---: |
| DATA read IOPS (all four jobs) | 33612.95 |
| DATA write IOPS (all four jobs) | 14395.33 |
| DATA total IOPS | 48008.28 |
| REDO write IOPS | 2182.56 |
| REDO write throughput (MiB/s) | 8.53 |
| REDO write latency p95 (ms) | 0.610 |
| REDO write latency p99 (ms) | 0.733 |
| REDO write latency p99.9 (ms) | 1.028 |
| FRA aggregate throughput (MiB/s) | 93.75 |
| Host CPU mean (%) | 33.02 |
| Mean FIO process CPU (%) | 9.74 |

## Per-job results

| Job | Read IOPS | Write IOPS | Read MiB/s | Write MiB/s | Write p99 ms | Write p99.9 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `data-8k#1` | 8402.34 | 3601.50 | 65.64 | 28.14 | 14.090 | 18.743 |
| `data-8k#2` | 8400.80 | 3598.73 | 65.63 | 28.12 | 14.090 | 18.743 |
| `data-8k#3` | 8402.84 | 3597.56 | 65.65 | 28.11 | 14.090 | 18.743 |
| `data-8k#4` | 8406.96 | 3597.54 | 65.68 | 28.11 | 14.090 | 18.743 |
| `redo#5` | 0.00 | 2182.56 | 0.00 | 8.53 | 0.733 | 1.028 |
| `fra-1m#6` | 47.16 | 46.58 | 47.16 | 46.59 | 137.363 | 145.752 |

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
