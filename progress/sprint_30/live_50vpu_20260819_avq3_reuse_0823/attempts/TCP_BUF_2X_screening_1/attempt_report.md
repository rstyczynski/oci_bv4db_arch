# Sprint 30 attempt report: TCP_BUF_2X_screening_1

## Result

- Candidate: `TCP_BUF_2X`
- Repetition: `1`
- VPU tier: `50 VPUs/GB`
- Final recorded state: `passed`
- Started: `2026-08-19T08:16:18Z`
- Ended: `2026-08-19T08:30:17Z`
- Measured attempt duration: `839 seconds`
- FIO exit code: `0`

## Performance summary

| Metric | Result |
| --- | ---: |
| DATA read IOPS (all four jobs) | 33619.43 |
| DATA write IOPS (all four jobs) | 14398.23 |
| DATA total IOPS | 48017.66 |
| REDO write IOPS | 690.75 |
| REDO write throughput (MiB/s) | 2.70 |
| REDO write latency p95 (ms) | 0.627 |
| REDO write latency p99 (ms) | 0.758 |
| REDO write latency p99.9 (ms) | 1.073 |
| FRA aggregate throughput (MiB/s) | 93.75 |
| Host CPU mean (%) | 34.22 |
| Mean FIO process CPU (%) | 9.52 |

## Per-job results

| Job | Read IOPS | Write IOPS | Read MiB/s | Write MiB/s | Write p99 ms | Write p99.9 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `data-8k#1` | 8399.72 | 3600.46 | 65.62 | 28.13 | 14.090 | 18.743 |
| `data-8k#2` | 8402.96 | 3599.70 | 65.65 | 28.12 | 14.221 | 18.743 |
| `data-8k#3` | 8408.39 | 3599.87 | 65.69 | 28.12 | 14.090 | 18.743 |
| `data-8k#4` | 8408.37 | 3598.20 | 65.69 | 28.11 | 14.090 | 18.743 |
| `redo#5` | 0.00 | 690.75 | 0.00 | 2.70 | 0.758 | 1.073 |
| `fra-1m#6` | 47.16 | 46.58 | 47.16 | 46.59 | 137.363 | 149.946 |

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
