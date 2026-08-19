# Sprint 30 attempt report: REGULAR_BASELINE_INITIAL_initial_1

## Result

- Candidate: `REGULAR_BASELINE_INITIAL`
- Repetition: `1`
- VPU tier: `50 VPUs/GB`
- Final recorded state: `passed`
- Started: `2026-08-18T21:20:53Z`
- Ended: `2026-08-18T21:36:33Z`
- Measured attempt duration: `940 seconds`
- FIO exit code: `0`

## Performance summary

| Metric | Result |
| --- | ---: |
| DATA read IOPS (all four jobs) | 33610.12 |
| DATA write IOPS (all four jobs) | 14394.49 |
| DATA total IOPS | 48004.61 |
| REDO write IOPS | 751.78 |
| REDO write throughput (MiB/s) | 2.94 |
| REDO write latency p95 (ms) | 0.586 |
| REDO write latency p99 (ms) | 0.741 |
| REDO write latency p99.9 (ms) | 1.253 |
| FRA aggregate throughput (MiB/s) | 93.75 |
| Host CPU mean (%) | 35.66 |
| Mean FIO process CPU (%) | 9.79 |

## Per-job results

| Job | Read IOPS | Write IOPS | Read MiB/s | Write MiB/s | Write p99 ms | Write p99.9 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `data-8k#1` | 8392.41 | 3597.38 | 65.57 | 28.10 | 15.401 | 19.792 |
| `data-8k#2` | 8399.37 | 3598.16 | 65.62 | 28.11 | 15.401 | 19.792 |
| `data-8k#3` | 8410.61 | 3600.88 | 65.71 | 28.13 | 15.401 | 19.792 |
| `data-8k#4` | 8407.72 | 3598.07 | 65.69 | 28.11 | 15.401 | 19.792 |
| `redo#5` | 0.00 | 751.78 | 0.00 | 2.94 | 0.741 | 1.253 |
| `fra-1m#6` | 47.16 | 46.58 | 47.16 | 46.59 | 137.363 | 152.044 |

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
