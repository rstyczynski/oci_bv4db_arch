# Sprint 30 attempt report: REGULAR_BASELINE_INITIAL_initial_2

## Result

- Candidate: `REGULAR_BASELINE_INITIAL`
- Repetition: `2`
- VPU tier: `50 VPUs/GB`
- Final recorded state: `passed`
- Started: `2026-08-18T23:10:45Z`
- Ended: `2026-08-18T23:21:45Z`
- Measured attempt duration: `660 seconds`
- FIO exit code: `0`

## Performance summary

| Metric | Result |
| --- | ---: |
| DATA read IOPS (all four jobs) | 33609.43 |
| DATA write IOPS (all four jobs) | 14393.90 |
| DATA total IOPS | 48003.33 |
| REDO write IOPS | 1145.83 |
| REDO write throughput (MiB/s) | 4.48 |
| REDO write latency p95 (ms) | 0.561 |
| REDO write latency p99 (ms) | 0.684 |
| REDO write latency p99.9 (ms) | 0.979 |
| FRA aggregate throughput (MiB/s) | 93.75 |
| Host CPU mean (%) | 37.23 |
| Mean FIO process CPU (%) | 9.53 |

## Per-job results

| Job | Read IOPS | Write IOPS | Read MiB/s | Write MiB/s | Write p99 ms | Write p99.9 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `data-8k#1` | 8400.87 | 3600.88 | 65.63 | 28.13 | 14.352 | 19.005 |
| `data-8k#2` | 8399.15 | 3598.05 | 65.62 | 28.11 | 14.352 | 19.005 |
| `data-8k#3` | 8404.92 | 3598.50 | 65.66 | 28.11 | 14.352 | 19.005 |
| `data-8k#4` | 8404.49 | 3596.46 | 65.66 | 28.10 | 14.352 | 19.005 |
| `redo#5` | 0.00 | 1145.83 | 0.00 | 4.48 | 0.684 | 0.979 |
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
