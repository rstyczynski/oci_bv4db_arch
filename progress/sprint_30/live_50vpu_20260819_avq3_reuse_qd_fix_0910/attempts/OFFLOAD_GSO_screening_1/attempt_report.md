# Sprint 30 attempt report: OFFLOAD_GSO_screening_1

## Result

- Candidate: `OFFLOAD_GSO`
- Repetition: `1`
- VPU tier: `50 VPUs/GB`
- Final recorded state: `passed`
- Started: `2026-08-19T11:16:43Z`
- Ended: `2026-08-19T11:27:45Z`
- Measured attempt duration: `662 seconds`
- FIO exit code: `0`

## Performance summary

| Metric | Result |
| --- | ---: |
| DATA read IOPS (all four jobs) | 33610.61 |
| DATA write IOPS (all four jobs) | 14394.39 |
| DATA total IOPS | 48005.00 |
| REDO write IOPS | 2204.67 |
| REDO write throughput (MiB/s) | 8.61 |
| REDO write latency p95 (ms) | 0.602 |
| REDO write latency p99 (ms) | 0.733 |
| REDO write latency p99.9 (ms) | 1.020 |
| FRA aggregate throughput (MiB/s) | 93.75 |
| Host CPU mean (%) | 32.74 |
| Mean FIO process CPU (%) | 9.76 |

## Per-job results

| Job | Read IOPS | Write IOPS | Read MiB/s | Write MiB/s | Write p99 ms | Write p99.9 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `data-8k#1` | 8400.55 | 3600.76 | 65.63 | 28.13 | 14.352 | 19.005 |
| `data-8k#2` | 8400.95 | 3598.78 | 65.63 | 28.12 | 14.352 | 19.005 |
| `data-8k#3` | 8401.28 | 3596.89 | 65.64 | 28.10 | 14.352 | 19.005 |
| `data-8k#4` | 8407.83 | 3597.95 | 65.69 | 28.11 | 14.352 | 19.005 |
| `redo#5` | 0.00 | 2204.67 | 0.00 | 8.61 | 0.733 | 1.020 |
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
