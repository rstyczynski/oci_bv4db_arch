# Sprint 30 attempt report: TCP_BUF_4X_screening_1

## Result

- Candidate: `TCP_BUF_4X`
- Repetition: `1`
- VPU tier: `50 VPUs/GB`
- Final recorded state: `passed`
- Started: `2026-08-19T09:33:16Z`
- Ended: `2026-08-19T09:44:18Z`
- Measured attempt duration: `662 seconds`
- FIO exit code: `0`

## Performance summary

| Metric | Result |
| --- | ---: |
| DATA read IOPS (all four jobs) | 33613.67 |
| DATA write IOPS (all four jobs) | 14395.82 |
| DATA total IOPS | 48009.49 |
| REDO write IOPS | 2121.67 |
| REDO write throughput (MiB/s) | 8.29 |
| REDO write latency p95 (ms) | 0.643 |
| REDO write latency p99 (ms) | 0.807 |
| REDO write latency p99.9 (ms) | 1.270 |
| FRA aggregate throughput (MiB/s) | 93.75 |
| Host CPU mean (%) | 33.48 |
| Mean FIO process CPU (%) | 9.84 |

## Per-job results

| Job | Read IOPS | Write IOPS | Read MiB/s | Write MiB/s | Write p99 ms | Write p99.9 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `data-8k#1` | 8400.84 | 3600.96 | 65.63 | 28.13 | 14.483 | 19.005 |
| `data-8k#2` | 8403.92 | 3600.07 | 65.66 | 28.13 | 14.483 | 19.005 |
| `data-8k#3` | 8401.07 | 3596.84 | 65.63 | 28.10 | 14.483 | 19.005 |
| `data-8k#4` | 8407.85 | 3597.96 | 65.69 | 28.11 | 14.483 | 19.005 |
| `redo#5` | 0.00 | 2121.67 | 0.00 | 8.29 | 0.807 | 1.270 |
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
