# Sprint 30 attempt report: REGULAR_BASELINE_INITIAL_initial_1

## Result

- Candidate: `REGULAR_BASELINE_INITIAL`
- Repetition: `1`
- VPU tier: `50 VPUs/GB`
- Final recorded state: `passed`
- Started: `2026-08-18T19:47:21Z`
- Ended: `2026-08-18T20:03:01Z`
- Measured attempt duration: `940 seconds`
- FIO exit code: `0`

## Performance summary

| Metric | Result |
| --- | ---: |
| DATA read IOPS (all four jobs) | 33608.07 |
| DATA write IOPS (all four jobs) | 14393.40 |
| DATA total IOPS | 48001.47 |
| REDO write IOPS | 758.17 |
| REDO write throughput (MiB/s) | 2.96 |
| REDO write latency p95 (ms) | 0.578 |
| REDO write latency p99 (ms) | 0.717 |
| REDO write latency p99.9 (ms) | 1.171 |
| FRA aggregate throughput (MiB/s) | 93.75 |
| Host CPU mean (%) | 33.76 |
| Mean FIO process CPU (%) | 9.48 |

## Per-job results

| Job | Read IOPS | Write IOPS | Read MiB/s | Write MiB/s | Write p99 ms | Write p99.9 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `data-8k#1` | 8394.48 | 3598.21 | 65.58 | 28.11 | 14.090 | 18.743 |
| `data-8k#2` | 8401.36 | 3599.04 | 65.64 | 28.12 | 14.090 | 18.743 |
| `data-8k#3` | 8404.19 | 3598.13 | 65.66 | 28.11 | 14.090 | 18.743 |
| `data-8k#4` | 8408.03 | 3598.03 | 65.69 | 28.11 | 14.090 | 18.743 |
| `redo#5` | 0.00 | 758.17 | 0.00 | 2.96 | 0.717 | 1.171 |
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
