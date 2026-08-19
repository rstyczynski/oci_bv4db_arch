# Sprint 30 attempt report: NETDEV_BACKLOG_2X_screening_1

## Result

- Candidate: `NETDEV_BACKLOG_2X`
- Repetition: `1`
- VPU tier: `50 VPUs/GB`
- Final recorded state: `passed`
- Started: `2026-08-19T10:08:17Z`
- Ended: `2026-08-19T10:19:19Z`
- Measured attempt duration: `662 seconds`
- FIO exit code: `0`

## Performance summary

| Metric | Result |
| --- | ---: |
| DATA read IOPS (all four jobs) | 33619.16 |
| DATA write IOPS (all four jobs) | 14398.07 |
| DATA total IOPS | 48017.23 |
| REDO write IOPS | 2174.23 |
| REDO write throughput (MiB/s) | 8.49 |
| REDO write latency p95 (ms) | 0.618 |
| REDO write latency p99 (ms) | 0.750 |
| REDO write latency p99.9 (ms) | 1.044 |
| FRA aggregate throughput (MiB/s) | 93.75 |
| Host CPU mean (%) | 33.06 |
| Mean FIO process CPU (%) | 9.82 |

## Per-job results

| Job | Read IOPS | Write IOPS | Read MiB/s | Write MiB/s | Write p99 ms | Write p99.9 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `data-8k#1` | 8406.77 | 3603.43 | 65.68 | 28.15 | 13.566 | 18.481 |
| `data-8k#2` | 8401.63 | 3599.09 | 65.64 | 28.12 | 13.697 | 18.481 |
| `data-8k#3` | 8404.18 | 3598.15 | 65.66 | 28.11 | 13.566 | 18.481 |
| `data-8k#4` | 8406.58 | 3597.39 | 65.68 | 28.10 | 13.566 | 18.481 |
| `redo#5` | 0.00 | 2174.23 | 0.00 | 8.49 | 0.750 | 1.044 |
| `fra-1m#6` | 47.14 | 46.59 | 47.15 | 46.59 | 137.363 | 145.752 |

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
