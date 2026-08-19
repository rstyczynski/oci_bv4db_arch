# Sprint 30 attempt report: TCP_CC_BBR_screening_1

## Result

- Candidate: `TCP_CC_BBR`
- Repetition: `1`
- VPU tier: `50 VPUs/GB`
- Final recorded state: `passed`
- Started: `2026-08-19T08:42:06Z`
- Ended: `2026-08-19T08:53:20Z`
- Measured attempt duration: `674 seconds`
- FIO exit code: `0`

## Performance summary

| Metric | Result |
| --- | ---: |
| DATA read IOPS (all four jobs) | 33614.13 |
| DATA write IOPS (all four jobs) | 14395.98 |
| DATA total IOPS | 48010.10 |
| REDO write IOPS | 1409.37 |
| REDO write throughput (MiB/s) | 5.51 |
| REDO write latency p95 (ms) | 0.635 |
| REDO write latency p99 (ms) | 0.774 |
| REDO write latency p99.9 (ms) | 1.221 |
| FRA aggregate throughput (MiB/s) | 93.75 |
| Host CPU mean (%) | 36.03 |
| Mean FIO process CPU (%) | 9.54 |

## Per-job results

| Job | Read IOPS | Write IOPS | Read MiB/s | Write MiB/s | Write p99 ms | Write p99.9 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `data-8k#1` | 8400.11 | 3600.66 | 65.63 | 28.13 | 15.139 | 19.530 |
| `data-8k#2` | 8400.81 | 3598.80 | 65.63 | 28.12 | 15.139 | 19.530 |
| `data-8k#3` | 8405.90 | 3598.82 | 65.67 | 28.12 | 15.139 | 19.530 |
| `data-8k#4` | 8407.30 | 3597.69 | 65.68 | 28.11 | 15.139 | 19.530 |
| `redo#5` | 0.00 | 1409.37 | 0.00 | 5.51 | 0.774 | 1.221 |
| `fra-1m#6` | 47.14 | 46.59 | 47.16 | 46.59 | 137.363 | 158.335 |

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
