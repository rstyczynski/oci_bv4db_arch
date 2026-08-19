# Sprint 30 attempt report: REGULAR_BASELINE_INITIAL_initial_1

## Result

- Candidate: `REGULAR_BASELINE_INITIAL`
- Repetition: `1`
- VPU tier: `50 VPUs/GB`
- Final recorded state: `passed`
- Started: `2026-08-18T22:54:36Z`
- Ended: `2026-08-18T23:10:16Z`
- Measured attempt duration: `940 seconds`
- FIO exit code: `0`

## Performance summary

| Metric | Result |
| --- | ---: |
| DATA read IOPS (all four jobs) | 33620.19 |
| DATA write IOPS (all four jobs) | 14398.64 |
| DATA total IOPS | 48018.83 |
| REDO write IOPS | 740.80 |
| REDO write throughput (MiB/s) | 2.89 |
| REDO write latency p95 (ms) | 0.578 |
| REDO write latency p99 (ms) | 0.709 |
| REDO write latency p99.9 (ms) | 1.073 |
| FRA aggregate throughput (MiB/s) | 93.75 |
| Host CPU mean (%) | 34.33 |
| Mean FIO process CPU (%) | 9.25 |

## Per-job results

| Job | Read IOPS | Write IOPS | Read MiB/s | Write MiB/s | Write p99 ms | Write p99.9 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `data-8k#1` | 8400.14 | 3600.64 | 65.63 | 28.13 | 14.615 | 19.005 |
| `data-8k#2` | 8401.42 | 3599.03 | 65.64 | 28.12 | 14.615 | 19.268 |
| `data-8k#3` | 8410.70 | 3600.92 | 65.71 | 28.13 | 14.615 | 19.268 |
| `data-8k#4` | 8407.94 | 3598.05 | 65.69 | 28.11 | 14.615 | 19.005 |
| `redo#5` | 0.00 | 740.80 | 0.00 | 2.89 | 0.709 | 1.073 |
| `fra-1m#6` | 47.16 | 46.58 | 47.16 | 46.59 | 137.363 | 156.238 |

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
