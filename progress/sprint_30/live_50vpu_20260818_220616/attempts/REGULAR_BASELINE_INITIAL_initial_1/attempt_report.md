# Sprint 30 attempt report: REGULAR_BASELINE_INITIAL_initial_1

## Result

- Candidate: `REGULAR_BASELINE_INITIAL`
- Repetition: `1`
- VPU tier: `50 VPUs/GB`
- Final recorded state: `passed`
- Started: `2026-08-18T22:12:55Z`
- Ended: `2026-08-18T22:28:35Z`
- Measured attempt duration: `940 seconds`
- FIO exit code: `0`

## Performance summary

| Metric | Result |
| --- | ---: |
| DATA read IOPS (all four jobs) | 33625.85 |
| DATA write IOPS (all four jobs) | 14400.88 |
| DATA total IOPS | 48026.73 |
| REDO write IOPS | 756.37 |
| REDO write throughput (MiB/s) | 2.95 |
| REDO write latency p95 (ms) | 0.569 |
| REDO write latency p99 (ms) | 0.692 |
| REDO write latency p99.9 (ms) | 0.946 |
| FRA aggregate throughput (MiB/s) | 93.75 |
| Host CPU mean (%) | 34.96 |
| Mean FIO process CPU (%) | 9.61 |

## Per-job results

| Job | Read IOPS | Write IOPS | Read MiB/s | Write MiB/s | Write p99 ms | Write p99.9 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `data-8k#1` | 8402.53 | 3601.66 | 65.64 | 28.14 | 14.483 | 19.005 |
| `data-8k#2` | 8405.65 | 3600.81 | 65.67 | 28.13 | 14.615 | 19.005 |
| `data-8k#3` | 8409.86 | 3600.49 | 65.70 | 28.13 | 14.615 | 19.005 |
| `data-8k#4` | 8407.81 | 3597.92 | 65.69 | 28.11 | 14.615 | 19.005 |
| `redo#5` | 0.00 | 756.37 | 0.00 | 2.95 | 0.692 | 0.946 |
| `fra-1m#6` | 47.16 | 46.58 | 47.16 | 46.59 | 137.363 | 154.141 |

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
