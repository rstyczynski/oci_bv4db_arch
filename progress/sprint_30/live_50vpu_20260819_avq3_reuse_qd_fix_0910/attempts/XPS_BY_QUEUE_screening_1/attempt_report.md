# Sprint 30 attempt report: XPS_BY_QUEUE_screening_1

## Result

- Candidate: `XPS_BY_QUEUE`
- Repetition: `1`
- VPU tier: `50 VPUs/GB`
- Final recorded state: `passed`
- Started: `2026-08-19T10:53:54Z`
- Ended: `2026-08-19T11:04:55Z`
- Measured attempt duration: `661 seconds`
- FIO exit code: `0`

## Performance summary

| Metric | Result |
| --- | ---: |
| DATA read IOPS (all four jobs) | 33612.92 |
| DATA write IOPS (all four jobs) | 14395.35 |
| DATA total IOPS | 48008.28 |
| REDO write IOPS | 2204.76 |
| REDO write throughput (MiB/s) | 8.61 |
| REDO write latency p95 (ms) | 0.602 |
| REDO write latency p99 (ms) | 0.725 |
| REDO write latency p99.9 (ms) | 1.028 |
| FRA aggregate throughput (MiB/s) | 93.75 |
| Host CPU mean (%) | 32.76 |
| Mean FIO process CPU (%) | 9.90 |

## Per-job results

| Job | Read IOPS | Write IOPS | Read MiB/s | Write MiB/s | Write p99 ms | Write p99.9 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `data-8k#1` | 8403.65 | 3602.08 | 65.65 | 28.14 | 14.483 | 19.005 |
| `data-8k#2` | 8398.44 | 3597.69 | 65.61 | 28.11 | 14.483 | 19.005 |
| `data-8k#3` | 8404.24 | 3598.20 | 65.66 | 28.11 | 14.615 | 19.005 |
| `data-8k#4` | 8406.59 | 3597.38 | 65.68 | 28.10 | 14.615 | 19.005 |
| `redo#5` | 0.00 | 2204.76 | 0.00 | 8.61 | 0.725 | 1.028 |
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
