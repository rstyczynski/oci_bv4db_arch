# Sprint 30 test reports

Generated from the archived FIO, iostat, state, restoration, integrity, and
error-counter evidence. A report marked passed is still only one repetition;
candidate or baseline conclusions require the aggregate analyzer and all
Sprint 30 gates.

## Newest run: `live_50vpu_20260818_224723`

The five completed initial-baseline repetitions each passed their local FIO,
restoration, sentinel, rollback-lease, and monitored-error gates.

| Attempt | DATA total IOPS | REDO p99.9 ms | FRA MiB/s | Host CPU mean | Report |
| --- | ---: | ---: | ---: | ---: | --- |
| Initial 1 | 48018.83 | 1.073 | 93.75 | 34.33% | [report](live_50vpu_20260818_224723/attempts/REGULAR_BASELINE_INITIAL_initial_1/attempt_report.md) |
| Initial 2 | 48003.33 | 0.979 | 93.75 | 37.23% | [report](live_50vpu_20260818_224723/attempts/REGULAR_BASELINE_INITIAL_initial_2/attempt_report.md) |
| Initial 3 | 47994.11 | 0.913 | 93.75 | 35.39% | [report](live_50vpu_20260818_224723/attempts/REGULAR_BASELINE_INITIAL_initial_3/attempt_report.md) |
| Stability extension 4 | 48006.65 | 0.872 | 93.75 | 32.75% | [report](live_50vpu_20260818_224723/attempts/REGULAR_BASELINE_INITIAL_stability_extension_4/attempt_report.md) |
| Stability extension 5 | 48005.76 | 0.913 | 93.75 | 33.25% | [report](live_50vpu_20260818_224723/attempts/REGULAR_BASELINE_INITIAL_stability_extension_5/attempt_report.md) |

This is a factual per-attempt summary, not a completed Sprint 30 performance
recommendation. The run-level state and aggregate stability decision remain in
`live_50vpu_20260818_224723/run_state.json` and `results_index.json` until the
controller finishes.

## Earlier diagnostic runs

These attempts are retained because they contain useful FIO or failure
evidence. They must not be pooled with the newest run: each directory belongs
to a separately provisioned test environment, and several runs ended on a
safety or evidence gate.

- `live_50vpu_20260818_182030`: [initial 1](live_50vpu_20260818_182030/attempts/REGULAR_BASELINE_INITIAL_initial_1/attempt_report.md)
- `live_50vpu_20260818_185628`: [initial 1](live_50vpu_20260818_185628/attempts/REGULAR_BASELINE_INITIAL_initial_1/attempt_report.md)
- `live_50vpu_20260818_194054`: [initial 1](live_50vpu_20260818_194054/attempts/REGULAR_BASELINE_INITIAL_initial_1/attempt_report.md), [initial 2](live_50vpu_20260818_194054/attempts/REGULAR_BASELINE_INITIAL_initial_2/attempt_report.md)
- `live_50vpu_20260818_203616`: [interrupted/invalid FIO attempt](live_50vpu_20260818_203616/attempts/REGULAR_BASELINE_INITIAL_initial_1/attempt_report.md)
- `live_50vpu_20260818_211430`: [initial 1](live_50vpu_20260818_211430/attempts/REGULAR_BASELINE_INITIAL_initial_1/attempt_report.md), [initial 2](live_50vpu_20260818_211430/attempts/REGULAR_BASELINE_INITIAL_initial_2/attempt_report.md), [initial 3](live_50vpu_20260818_211430/attempts/REGULAR_BASELINE_INITIAL_initial_3/attempt_report.md)
- `live_50vpu_20260818_220616`: [initial 1](live_50vpu_20260818_220616/attempts/REGULAR_BASELINE_INITIAL_initial_1/attempt_report.md)

## Report contract

Every future successful attempt is required to create `attempt_report.md`
immediately after its HTML FIO rendering. The controller treats a missing or
empty Markdown report as an attempt failure. Each report includes the measured
window, aggregate and per-job metrics, host CPU, restoration and integrity
gates, and links to the underlying evidence.
