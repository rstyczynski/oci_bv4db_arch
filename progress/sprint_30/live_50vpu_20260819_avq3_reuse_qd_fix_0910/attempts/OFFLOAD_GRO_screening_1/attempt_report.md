# Sprint 30 attempt report: OFFLOAD_GRO_screening_1

## Result

- Candidate: `OFFLOAD_GRO`
- Repetition: `1`
- VPU tier: `50 VPUs/GB`
- Final recorded state: `passed`
- Started: `2026-08-19T11:05:17Z`
- Ended: `2026-08-19T11:16:19Z`
- Measured attempt duration: `662 seconds`
- FIO exit code: `0`

## Performance summary

| Metric | Result |
| --- | ---: |
| DATA read IOPS (all four jobs) | 33611.39 |
| DATA write IOPS (all four jobs) | 14394.78 |
| DATA total IOPS | 48006.17 |
| REDO write IOPS | 2200.89 |
| REDO write throughput (MiB/s) | 8.60 |
| REDO write latency p95 (ms) | 0.602 |
| REDO write latency p99 (ms) | 0.725 |
| REDO write latency p99.9 (ms) | 1.012 |
| FRA aggregate throughput (MiB/s) | 93.75 |
| Host CPU mean (%) | 32.63 |
| Mean FIO process CPU (%) | 9.75 |

## Per-job results

| Job | Read IOPS | Write IOPS | Read MiB/s | Write MiB/s | Write p99 ms | Write p99.9 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `data-8k#1` | 8400.81 | 3600.91 | 65.63 | 28.13 | 14.483 | 19.005 |
| `data-8k#2` | 8400.15 | 3598.47 | 65.63 | 28.11 | 14.483 | 19.005 |
| `data-8k#3` | 8403.60 | 3597.90 | 65.65 | 28.11 | 14.483 | 19.005 |
| `data-8k#4` | 8406.82 | 3597.50 | 65.68 | 28.11 | 14.483 | 19.005 |
| `redo#5` | 0.00 | 2200.89 | 0.00 | 8.60 | 0.725 | 1.012 |
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
