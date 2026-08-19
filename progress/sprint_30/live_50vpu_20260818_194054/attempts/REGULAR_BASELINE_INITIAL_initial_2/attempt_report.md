# Sprint 30 attempt report: REGULAR_BASELINE_INITIAL_initial_2

## Result

- Candidate: `REGULAR_BASELINE_INITIAL`
- Repetition: `unknown`
- VPU tier: `50 VPUs/GB`
- Final recorded state: `restored`
- Started: `unknown`
- Ended: `unknown`
- Measured attempt duration: `unknown seconds`
- FIO exit code: `unknown`

## Performance summary

| Metric | Result |
| --- | ---: |
| DATA read IOPS (all four jobs) | 33606.06 |
| DATA write IOPS (all four jobs) | 14392.59 |
| DATA total IOPS | 47998.65 |
| REDO write IOPS | 1158.91 |
| REDO write throughput (MiB/s) | 4.53 |
| REDO write latency p95 (ms) | 0.578 |
| REDO write latency p99 (ms) | 0.717 |
| REDO write latency p99.9 (ms) | 1.221 |
| FRA aggregate throughput (MiB/s) | 93.74 |
| Host CPU mean (%) | 35.01 |
| Mean FIO process CPU (%) | 9.62 |

## Per-job results

| Job | Read IOPS | Write IOPS | Read MiB/s | Write MiB/s | Write p99 ms | Write p99.9 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `data-8k#1` | 8401.09 | 3600.99 | 65.63 | 28.13 | 13.828 | 18.481 |
| `data-8k#2` | 8399.05 | 3598.01 | 65.62 | 28.11 | 13.959 | 18.481 |
| `data-8k#3` | 8397.79 | 3595.44 | 65.61 | 28.09 | 13.959 | 18.481 |
| `data-8k#4` | 8408.14 | 3598.15 | 65.69 | 28.11 | 13.828 | 18.481 |
| `redo#5` | 0.00 | 1158.91 | 0.00 | 4.53 | 0.717 | 1.221 |
| `fra-1m#6` | 47.14 | 46.58 | 47.15 | 46.59 | 137.363 | 154.141 |

## Safety and evidence gates

- Restoration state: `unknown`
- Restoration checks passed: `yes`
- Restored controls byte-equal to baseline: `yes`
- Sentinels valid: `unknown`
- Rollback lease disarmed: `unknown`
- Monitored error counters clean: `no`

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
- [errors_after.json](errors_after.json)
- [guest_preflight.json](guest_preflight.json)
- [oci_preflight.json](oci_preflight.json)
