# Sprint 30 attempt report: REGULAR_BASELINE_INITIAL_stability_extension_5

## Result

- Candidate: `REGULAR_BASELINE_INITIAL`
- Repetition: `5`
- VPU tier: `50 VPUs/GB`
- Final recorded state: `passed`
- Started: `2026-08-18T23:45:27Z`
- Ended: `2026-08-18T23:56:27Z`
- Measured attempt duration: `660 seconds`
- FIO exit code: `0`

## Performance summary

| Metric | Result |
| --- | ---: |
| DATA read IOPS (all four jobs) | 33611.11 |
| DATA write IOPS (all four jobs) | 14394.65 |
| DATA total IOPS | 48005.76 |
| REDO write IOPS | 2409.57 |
| REDO write throughput (MiB/s) | 9.41 |
| REDO write latency p95 (ms) | 0.537 |
| REDO write latency p99 (ms) | 0.651 |
| REDO write latency p99.9 (ms) | 0.913 |
| FRA aggregate throughput (MiB/s) | 93.75 |
| Host CPU mean (%) | 33.25 |
| Mean FIO process CPU (%) | 9.72 |

## Per-job results

| Job | Read IOPS | Write IOPS | Read MiB/s | Write MiB/s | Write p99 ms | Write p99.9 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `data-8k#1` | 8400.09 | 3600.65 | 65.63 | 28.13 | 14.877 | 19.530 |
| `data-8k#2` | 8396.95 | 3597.00 | 65.60 | 28.10 | 14.877 | 19.268 |
| `data-8k#3` | 8404.87 | 3598.44 | 65.66 | 28.11 | 14.877 | 19.530 |
| `data-8k#4` | 8409.19 | 3598.56 | 65.70 | 28.11 | 14.877 | 19.530 |
| `redo#5` | 0.00 | 2409.57 | 0.00 | 9.41 | 0.651 | 0.913 |
| `fra-1m#6` | 47.16 | 46.58 | 47.16 | 46.59 | 137.363 | 149.946 |

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
