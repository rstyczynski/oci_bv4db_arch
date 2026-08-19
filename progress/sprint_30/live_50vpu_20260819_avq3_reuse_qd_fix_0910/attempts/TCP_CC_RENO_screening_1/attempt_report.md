# Sprint 30 attempt report: TCP_CC_RENO_screening_1

## Result

- Candidate: `TCP_CC_RENO`
- Repetition: `1`
- VPU tier: `50 VPUs/GB`
- Final recorded state: `passed`
- Started: `2026-08-19T09:56:30Z`
- Ended: `2026-08-19T10:07:44Z`
- Measured attempt duration: `674 seconds`
- FIO exit code: `0`

## Performance summary

| Metric | Result |
| --- | ---: |
| DATA read IOPS (all four jobs) | 33614.11 |
| DATA write IOPS (all four jobs) | 14395.98 |
| DATA total IOPS | 48010.09 |
| REDO write IOPS | 2174.06 |
| REDO write throughput (MiB/s) | 8.49 |
| REDO write latency p95 (ms) | 0.618 |
| REDO write latency p99 (ms) | 0.758 |
| REDO write latency p99.9 (ms) | 1.286 |
| FRA aggregate throughput (MiB/s) | 93.75 |
| Host CPU mean (%) | 33.61 |
| Mean FIO process CPU (%) | 9.77 |

## Per-job results

| Job | Read IOPS | Write IOPS | Read MiB/s | Write MiB/s | Write p99 ms | Write p99.9 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `data-8k#1` | 8403.41 | 3601.99 | 65.65 | 28.14 | 13.959 | 18.743 |
| `data-8k#2` | 8403.01 | 3599.67 | 65.65 | 28.12 | 14.090 | 18.743 |
| `data-8k#3` | 8397.50 | 3595.30 | 65.61 | 28.09 | 14.090 | 18.743 |
| `data-8k#4` | 8410.20 | 3599.02 | 65.70 | 28.12 | 14.090 | 18.743 |
| `redo#5` | 0.00 | 2174.06 | 0.00 | 8.49 | 0.758 | 1.286 |
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
