# Sprint 30 attempt report: OFFLOAD_GRO_screening_1

## Result

- Candidate: `OFFLOAD_GRO`
- Repetition: `1`
- VPU tier: `50 VPUs/GB`
- Final recorded state: `passed`
- Started: `2026-08-19T15:15:47Z`
- Ended: `2026-08-19T15:26:49Z`
- Measured attempt duration: `662 seconds`
- FIO exit code: `0`

## Performance summary

| Metric | Result |
| --- | ---: |
| DATA read IOPS (all four jobs) | 46030.64 |
| DATA write IOPS (all four jobs) | 19714.12 |
| DATA total IOPS | 65744.77 |
| REDO write IOPS | 2165.21 |
| REDO write throughput (MiB/s) | 8.46 |
| REDO write latency p95 (ms) | 0.618 |
| REDO write latency p99 (ms) | 0.799 |
| REDO write latency p99.9 (ms) | 1.729 |
| FRA aggregate throughput (MiB/s) | 175.78 |
| Host CPU mean (%) | 38.91 |
| Mean FIO process CPU (%) | 12.91 |

## Per-job results

| Job | Read IOPS | Write IOPS | Read MiB/s | Write MiB/s | Write p99 ms | Write p99.9 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `data-8k#1` | 11505.64 | 4930.31 | 89.89 | 38.52 | 3.097 | 5.210 |
| `data-8k#2` | 11507.34 | 4931.15 | 89.90 | 38.52 | 3.097 | 5.210 |
| `data-8k#3` | 11506.85 | 4927.41 | 89.90 | 38.50 | 3.097 | 5.210 |
| `data-8k#4` | 11510.81 | 4925.27 | 89.93 | 38.48 | 3.097 | 5.210 |
| `redo#5` | 0.00 | 2165.21 | 0.00 | 8.46 | 0.799 | 1.729 |
| `fra-1m#6` | 88.03 | 87.74 | 88.04 | 87.74 | 72.876 | 78.119 |

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
