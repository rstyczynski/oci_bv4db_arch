# Sprint 30 attempt report: RFS_65536_screening_1

## Result

- Candidate: `RFS_65536`
- Repetition: `1`
- VPU tier: `50 VPUs/GB`
- Final recorded state: `passed`
- Started: `2026-08-19T10:31:05Z`
- Ended: `2026-08-19T10:42:07Z`
- Measured attempt duration: `662 seconds`
- FIO exit code: `0`

## Performance summary

| Metric | Result |
| --- | ---: |
| DATA read IOPS (all four jobs) | 33609.75 |
| DATA write IOPS (all four jobs) | 14394.14 |
| DATA total IOPS | 48003.89 |
| REDO write IOPS | 2077.88 |
| REDO write throughput (MiB/s) | 8.12 |
| REDO write latency p95 (ms) | 0.659 |
| REDO write latency p99 (ms) | 0.815 |
| REDO write latency p99.9 (ms) | 1.286 |
| FRA aggregate throughput (MiB/s) | 93.75 |
| Host CPU mean (%) | 30.92 |
| Mean FIO process CPU (%) | 9.65 |

## Per-job results

| Job | Read IOPS | Write IOPS | Read MiB/s | Write MiB/s | Write p99 ms | Write p99.9 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `data-8k#1` | 8400.70 | 3600.90 | 65.63 | 28.13 | 13.435 | 18.219 |
| `data-8k#2` | 8400.66 | 3598.71 | 65.63 | 28.12 | 13.435 | 18.219 |
| `data-8k#3` | 8400.59 | 3596.64 | 65.63 | 28.10 | 13.435 | 18.219 |
| `data-8k#4` | 8407.80 | 3597.89 | 65.69 | 28.11 | 13.435 | 18.219 |
| `redo#5` | 0.00 | 2077.88 | 0.00 | 8.12 | 0.815 | 1.286 |
| `fra-1m#6` | 47.16 | 46.58 | 47.16 | 46.59 | 137.363 | 145.752 |

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
