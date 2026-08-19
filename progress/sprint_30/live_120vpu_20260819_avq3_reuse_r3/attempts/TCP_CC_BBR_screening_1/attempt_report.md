# Sprint 30 attempt report: TCP_CC_BBR_screening_1

## Result

- Candidate: `TCP_CC_BBR`
- Repetition: `1`
- VPU tier: `50 VPUs/GB`
- Final recorded state: `passed`
- Started: `2026-08-19T13:55:13Z`
- Ended: `2026-08-19T14:06:26Z`
- Measured attempt duration: `673 seconds`
- FIO exit code: `0`

## Performance summary

| Metric | Result |
| --- | ---: |
| DATA read IOPS (all four jobs) | 46483.71 |
| DATA write IOPS (all four jobs) | 19907.87 |
| DATA total IOPS | 66391.58 |
| REDO write IOPS | 2107.63 |
| REDO write throughput (MiB/s) | 8.23 |
| REDO write latency p95 (ms) | 0.651 |
| REDO write latency p99 (ms) | 0.840 |
| REDO write latency p99.9 (ms) | 1.712 |
| FRA aggregate throughput (MiB/s) | 175.78 |
| Host CPU mean (%) | 41.02 |
| Mean FIO process CPU (%) | 13.04 |

## Per-job results

| Job | Read IOPS | Write IOPS | Read MiB/s | Write MiB/s | Write p99 ms | Write p99.9 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `data-8k#1` | 11619.65 | 4978.41 | 90.78 | 38.89 | 3.162 | 5.472 |
| `data-8k#2` | 11617.71 | 4978.49 | 90.76 | 38.89 | 3.162 | 5.407 |
| `data-8k#3` | 11619.32 | 4975.55 | 90.78 | 38.87 | 3.162 | 5.472 |
| `data-8k#4` | 11627.03 | 4975.42 | 90.84 | 38.87 | 3.162 | 5.472 |
| `redo#5` | 0.00 | 2107.63 | 0.00 | 8.23 | 0.840 | 1.712 |
| `fra-1m#6` | 88.05 | 87.72 | 88.05 | 87.73 | 72.876 | 78.119 |

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
