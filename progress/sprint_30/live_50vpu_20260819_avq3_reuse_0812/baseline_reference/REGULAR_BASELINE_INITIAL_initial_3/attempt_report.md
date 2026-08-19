# Sprint 30 attempt report: REGULAR_BASELINE_INITIAL_initial_3

## Result

- Candidate: `REGULAR_BASELINE_INITIAL`
- Repetition: `3`
- VPU tier: `50 VPUs/GB`
- Final recorded state: `passed`
- Started: `2026-08-18T23:22:18Z`
- Ended: `2026-08-18T23:33:19Z`
- Measured attempt duration: `661 seconds`
- FIO exit code: `0`

## Performance summary

| Metric | Result |
| --- | ---: |
| DATA read IOPS (all four jobs) | 33602.76 |
| DATA write IOPS (all four jobs) | 14391.34 |
| DATA total IOPS | 47994.11 |
| REDO write IOPS | 1601.64 |
| REDO write throughput (MiB/s) | 6.26 |
| REDO write latency p95 (ms) | 0.545 |
| REDO write latency p99 (ms) | 0.659 |
| REDO write latency p99.9 (ms) | 0.913 |
| FRA aggregate throughput (MiB/s) | 93.75 |
| Host CPU mean (%) | 35.39 |
| Mean FIO process CPU (%) | 9.52 |

## Per-job results

| Job | Read IOPS | Write IOPS | Read MiB/s | Write MiB/s | Write p99 ms | Write p99.9 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `data-8k#1` | 8398.48 | 3599.94 | 65.61 | 28.12 | 14.877 | 19.268 |
| `data-8k#2` | 8397.50 | 3597.35 | 65.61 | 28.10 | 14.877 | 19.268 |
| `data-8k#3` | 8396.67 | 3594.92 | 65.60 | 28.09 | 14.877 | 19.268 |
| `data-8k#4` | 8410.12 | 3599.13 | 65.70 | 28.12 | 14.877 | 19.268 |
| `redo#5` | 0.00 | 1601.64 | 0.00 | 6.26 | 0.659 | 0.913 |
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
