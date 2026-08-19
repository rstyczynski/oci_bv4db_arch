# Sprint 30 attempt report: TCP_BUF_4X_screening_1

## Result

- Candidate: `TCP_BUF_4X`
- Repetition: `1`
- VPU tier: `50 VPUs/GB`
- Final recorded state: `passed`
- Started: `2026-08-19T08:30:42Z`
- Ended: `2026-08-19T08:41:43Z`
- Measured attempt duration: `661 seconds`
- FIO exit code: `0`

## Performance summary

| Metric | Result |
| --- | ---: |
| DATA read IOPS (all four jobs) | 33613.26 |
| DATA write IOPS (all four jobs) | 14395.57 |
| DATA total IOPS | 48008.83 |
| REDO write IOPS | 1068.29 |
| REDO write throughput (MiB/s) | 4.17 |
| REDO write latency p95 (ms) | 0.627 |
| REDO write latency p99 (ms) | 0.758 |
| REDO write latency p99.9 (ms) | 1.073 |
| FRA aggregate throughput (MiB/s) | 93.75 |
| Host CPU mean (%) | 35.82 |
| Mean FIO process CPU (%) | 9.58 |

## Per-job results

| Job | Read IOPS | Write IOPS | Read MiB/s | Write MiB/s | Write p99 ms | Write p99.9 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `data-8k#1` | 8395.96 | 3598.87 | 65.59 | 28.12 | 14.221 | 18.743 |
| `data-8k#2` | 8401.43 | 3598.99 | 65.64 | 28.12 | 14.221 | 18.743 |
| `data-8k#3` | 8407.14 | 3599.39 | 65.68 | 28.12 | 14.221 | 18.743 |
| `data-8k#4` | 8408.73 | 3598.32 | 65.69 | 28.11 | 14.221 | 18.743 |
| `redo#5` | 0.00 | 1068.29 | 0.00 | 4.17 | 0.758 | 1.073 |
| `fra-1m#6` | 47.15 | 46.59 | 47.15 | 46.59 | 137.363 | 152.044 |

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
