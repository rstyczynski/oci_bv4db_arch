# Sprint 30 attempt report: REGULAR_BASELINE_INITIAL_initial_1

## Result

- Candidate: `REGULAR_BASELINE_INITIAL`
- Repetition: `unknown`
- VPU tier: `50 VPUs/GB`
- Final recorded state: `failed`
- Started: `unknown`
- Ended: `unknown`
- Measured attempt duration: `unknown seconds`
- FIO exit code: `unknown`

## Performance summary

| Metric | Result |
| --- | ---: |
| DATA read IOPS (all four jobs) | 33614.55 |
| DATA write IOPS (all four jobs) | 14396.22 |
| DATA total IOPS | 48010.77 |
| REDO write IOPS | 727.24 |
| REDO write throughput (MiB/s) | 2.84 |
| REDO write latency p95 (ms) | 0.602 |
| REDO write latency p99 (ms) | 0.774 |
| REDO write latency p99.9 (ms) | 1.368 |
| FRA aggregate throughput (MiB/s) | 93.75 |
| Host CPU mean (%) | 35.07 |
| Mean FIO process CPU (%) | 9.57 |

## Per-job results

| Job | Read IOPS | Write IOPS | Read MiB/s | Write MiB/s | Write p99 ms | Write p99.9 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `data-8k#1` | 8403.35 | 3601.97 | 65.65 | 28.14 | 15.139 | 19.530 |
| `data-8k#2` | 8403.05 | 3599.68 | 65.65 | 28.12 | 15.139 | 19.530 |
| `data-8k#3` | 8400.86 | 3596.76 | 65.63 | 28.10 | 15.270 | 19.530 |
| `data-8k#4` | 8407.29 | 3597.80 | 65.68 | 28.11 | 15.139 | 19.530 |
| `redo#5` | 0.00 | 727.24 | 0.00 | 2.84 | 0.774 | 1.368 |
| `fra-1m#6` | 47.16 | 46.58 | 47.16 | 46.59 | 137.363 | 154.141 |

## Safety and evidence gates

- Restoration state: `unknown`
- Restoration checks passed: `no`
- Restored controls byte-equal to baseline: `yes`
- Sentinels valid: `unknown`
- Rollback lease disarmed: `unknown`
- Monitored error counters clean: `unknown`

This attempt is eligible for aggregate baseline or candidate analysis only when its final state is `passed` and all safety gates above are `yes`.

## Evidence files

- [fio.json](fio.json)
- [fio.log](fio.log)
- [iostat.json](iostat.json)
- [state.json](state.json)
- [restoration_checks.json](restoration_checks.json)
- [controls_before.json](controls_before.json)
- [controls_applied.json](controls_applied.json)
- [controls_restored.json](controls_restored.json)
- [errors_before.json](errors_before.json)
- [guest_preflight.json](guest_preflight.json)
- [oci_preflight.json](oci_preflight.json)
