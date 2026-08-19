# Sprint 30 attempt report: REGULAR_BASELINE_INITIAL_stability_extension_4

## Result

- Candidate: `REGULAR_BASELINE_INITIAL`
- Repetition: `4`
- VPU tier: `50 VPUs/GB`
- Final recorded state: `passed`
- Started: `2026-08-18T23:33:53Z`
- Ended: `2026-08-18T23:44:53Z`
- Measured attempt duration: `660 seconds`
- FIO exit code: `0`

## Performance summary

| Metric | Result |
| --- | ---: |
| DATA read IOPS (all four jobs) | 33611.75 |
| DATA write IOPS (all four jobs) | 14394.90 |
| DATA total IOPS | 48006.65 |
| REDO write IOPS | 2435.72 |
| REDO write throughput (MiB/s) | 9.51 |
| REDO write latency p95 (ms) | 0.528 |
| REDO write latency p99 (ms) | 0.643 |
| REDO write latency p99.9 (ms) | 0.872 |
| FRA aggregate throughput (MiB/s) | 93.75 |
| Host CPU mean (%) | 32.75 |
| Mean FIO process CPU (%) | 9.62 |

## Per-job results

| Job | Read IOPS | Write IOPS | Read MiB/s | Write MiB/s | Write p99 ms | Write p99.9 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `data-8k#1` | 8401.95 | 3601.38 | 65.64 | 28.14 | 14.877 | 19.530 |
| `data-8k#2` | 8397.06 | 3597.13 | 65.60 | 28.10 | 14.877 | 19.530 |
| `data-8k#3` | 8402.13 | 3597.25 | 65.64 | 28.10 | 15.008 | 19.530 |
| `data-8k#4` | 8410.62 | 3599.14 | 65.71 | 28.12 | 15.008 | 19.530 |
| `redo#5` | 0.00 | 2435.72 | 0.00 | 9.51 | 0.643 | 0.872 |
| `fra-1m#6` | 47.15 | 46.58 | 47.16 | 46.59 | 137.363 | 145.752 |

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
