# Sprint 2 — fio Analysis

## Context

- **Sprint:** 2
- **Region:** `eu-zurich-1`
- **Artifact analyzed:** `progress/sprint_2/fio-results-perf.json`
- **Sequential artifact:** `progress/sprint_2/fio-results-perf-sequential.json`
- **Random artifact:** `progress/sprint_2/fio-results-perf-random.json`
- **Compute shape:** `VM.Standard.E5.Flex`
- **OCPUs:** `40`
- **Block volume size:** `1500 GB`
- **Block volume VPUs/GB:** `120`
- **Attachment multipath-enabled:** `true`
- **Sequential test:** `rw`, `1M` block size, `64G` file, `1` job
- **Random test:** `randrw`, `4k` block size, `64G` file, `4` jobs, `iodepth=32`
- **Total fio runtime window:** `60 seconds`

## Measured Results

| Workload | Read | Write | Mean latency | Tail latency |
| --- | --- | --- | --- | --- |
| Sequential 1M | ~183 IOPS / ~183 MB/s | ~184 IOPS / ~184 MB/s | read `2.64 ms`, write `2.81 ms` | p95 read `3.03 ms`, p99 read `3.16 ms`, p95 write `3.19 ms`, p99 write `3.46 ms` |
| Random 4k | ~24015 IOPS / ~94 MB/s | ~24051 IOPS / ~94 MB/s | read `1.65 ms`, write `3.68 ms` | p95 read `3.92 ms`, p99 read `6.85 ms`, p95 write `7.44 ms`, p99 write `10.29 ms` |

Disk utilization reported by fio:

- Sequential workload: `99.91%`
- Random workload: `100.00%`

## Interpretation

1. Sprint 2 is materially faster than Sprint 1 in every user-visible storage dimension. The UHP volume with multipath and a larger compute shape moved the benchmark from a low-throughput baseline into a clearly higher-performance profile.
2. Sequential throughput improved from about `11-12 MB/s` in Sprint 1 to about `183-184 MB/s` in Sprint 2. That is roughly a fifteen-fold increase and shows that the Sprint 1 baseline was not close to the ceiling of the storage stack.
3. Random `4k` performance improved from about `1520` read and write IOPS in Sprint 1 to about `24k` read and write IOPS in Sprint 2. That is also about a sixteen-fold increase, with much lower latency.
4. Latency behavior improved sharply. Sprint 1 random write latency was the weakest metric at about `68 ms` mean and `198 ms` p99; Sprint 2 random write latency dropped to about `3.68 ms` mean and `10.29 ms` p99.
5. fio still reports effectively full disk utilization in both workloads, so the storage path remains the main constrained resource in the benchmark. That is expected and acceptable for this sprint because the goal was to drive the volume near its service envelope, not to leave unused headroom.
6. This run is still a short-window characterization, not a long-duration endurance result. It is valid for proving that the Sprint 2 implementation and UHP multipath path work correctly, but it should not be treated as the final production sizing result for sustained database load.

## Comparison to Sprint 1

| Metric | Sprint 1 | Sprint 2 | Change |
| --- | --- | --- | --- |
| Sequential read throughput | ~11 MB/s | ~183 MB/s | ~16.6x higher |
| Sequential write throughput | ~12 MB/s | ~184 MB/s | ~15.3x higher |
| Random read IOPS | ~1520 | ~24015 | ~15.8x higher |
| Random write IOPS | ~1520 | ~24051 | ~15.8x higher |
| Random write mean latency | `68.46 ms` | `3.68 ms` | ~18.6x lower |
| Random write p99 latency | `198.18 ms` | `10.29 ms` | ~19.3x lower |

## Practical Conclusion

Sprint 2 now has a valid analyzed result set for the current 60-second benchmark window:

- combined raw JSON in `progress/sprint_2/fio-results-perf.json`
- separate per-workload JSON artifacts in `progress/sprint_2/fio-results-perf-sequential.json` and `progress/sprint_2/fio-results-perf-random.json`
- a UHP + multipath execution path that completed end to end and tore down cleanly

The remaining engineering question is not whether the path works. It does. The next question is whether Sprint 3 should keep the same topology and extend the runtime, or further change shape/queueing/workload structure to search for more throughput.
