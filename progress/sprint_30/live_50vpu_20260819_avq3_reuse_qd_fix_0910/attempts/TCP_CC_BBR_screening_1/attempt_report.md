# Sprint 30 attempt report: TCP_CC_BBR_screening_1

## Result

- Candidate: `TCP_CC_BBR`
- Repetition: `1`
- VPU tier: `50 VPUs/GB`
- Final recorded state: `passed`
- Started: `2026-08-19T09:44:42Z`
- Ended: `2026-08-19T09:55:57Z`
- Measured attempt duration: `675 seconds`
- FIO exit code: `0`

## Performance summary

| Metric | Result |
| --- | ---: |
| DATA read IOPS (all four jobs) | 33617.46 |
| DATA write IOPS (all four jobs) | 14397.29 |
| DATA total IOPS | 48014.74 |
| REDO write IOPS | 2168.84 |
| REDO write throughput (MiB/s) | 8.47 |
| REDO write latency p95 (ms) | 0.618 |
| REDO write latency p99 (ms) | 0.799 |
| REDO write latency p99.9 (ms) | 1.630 |
| FRA aggregate throughput (MiB/s) | 93.75 |
| Host CPU mean (%) | 34.53 |
| Mean FIO process CPU (%) | 9.87 |

## Per-job results

| Job | Read IOPS | Write IOPS | Read MiB/s | Write MiB/s | Write p99 ms | Write p99.9 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `data-8k#1` | 8403.99 | 3602.16 | 65.66 | 28.14 | 14.483 | 19.005 |
| `data-8k#2` | 8399.91 | 3598.31 | 65.62 | 28.11 | 14.615 | 19.268 |
| `data-8k#3` | 8404.61 | 3598.36 | 65.66 | 28.11 | 14.615 | 19.005 |
| `data-8k#4` | 8408.95 | 3598.46 | 65.70 | 28.11 | 14.615 | 19.005 |
| `redo#5` | 0.00 | 2168.84 | 0.00 | 8.47 | 0.799 | 1.630 |
| `fra-1m#6` | 47.14 | 46.59 | 47.16 | 46.59 | 137.363 | 156.238 |

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
