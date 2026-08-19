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
| DATA read IOPS (all four jobs) | 33624.37 |
| DATA write IOPS (all four jobs) | 14400.55 |
| DATA total IOPS | 48024.92 |
| REDO write IOPS | 760.85 |
| REDO write throughput (MiB/s) | 2.97 |
| REDO write latency p95 (ms) | 0.561 |
| REDO write latency p99 (ms) | 0.684 |
| REDO write latency p99.9 (ms) | 0.922 |
| FRA aggregate throughput (MiB/s) | 93.75 |
| Host CPU mean (%) | 34.69 |
| Mean FIO process CPU (%) | 9.86 |

## Per-job results

| Job | Read IOPS | Write IOPS | Read MiB/s | Write MiB/s | Write p99 ms | Write p99.9 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `data-8k#1` | 8397.68 | 3599.63 | 65.61 | 28.12 | 14.746 | 19.005 |
| `data-8k#2` | 8402.81 | 3599.61 | 65.65 | 28.12 | 14.746 | 19.268 |
| `data-8k#3` | 8412.10 | 3601.53 | 65.72 | 28.14 | 14.746 | 19.268 |
| `data-8k#4` | 8411.78 | 3599.78 | 65.72 | 28.12 | 14.746 | 19.268 |
| `redo#5` | 0.00 | 760.85 | 0.00 | 2.97 | 0.684 | 0.922 |
| `fra-1m#6` | 47.16 | 46.58 | 47.16 | 46.59 | 137.363 | 149.946 |

## Safety and evidence gates

- Restoration state: `unknown`
- Restoration checks passed: `unknown`
- Restored controls byte-equal to baseline: `unknown`
- Sentinels valid: `unknown`
- Rollback lease disarmed: `unknown`
- Monitored error counters clean: `unknown`

This attempt is eligible for aggregate baseline or candidate analysis only when its final state is `passed` and all safety gates above are `yes`.

## Evidence files

- [fio.json](fio.json)
- [fio.log](fio.log)
- [iostat.json](iostat.json)
- [state.json](state.json)
- [controls_before.json](controls_before.json)
- [controls_applied.json](controls_applied.json)
- [controls_restored.json](controls_restored.json)
- [errors_before.json](errors_before.json)
- [guest_preflight.json](guest_preflight.json)
- [oci_preflight.json](oci_preflight.json)
