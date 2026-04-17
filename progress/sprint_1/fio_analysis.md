# Sprint 1 — fio Analysis

## Context

- **Sprint:** 1
- **Region:** `eu-zurich-1`
- **Artifact analyzed:** `progress/sprint_1/fio-results.json`
- **Sequential test:** `rw`, `1M` block size, `1G` file, `1` job
- **Random test:** `randrw`, `4k` block size, `512M` file, `4` jobs, `iodepth=32`

## Measured Results

| Workload | Read | Write | Mean latency | Tail latency |
| --- | --- | --- | --- | --- |
| Sequential 1M | ~11 IOPS / ~11 MB/s | ~12 IOPS / ~12 MB/s | read `43.15 ms`, write `41.66 ms` | p99 read `46.40 ms`, p99 write `44.30 ms` |
| Random 4k | ~1520 IOPS / ~6 MB/s | ~1520 IOPS / ~6 MB/s | read `15.73 ms`, write `68.46 ms` | p95 read `40.11 ms`, p99 read `46.92 ms`, p95 write `131.60 ms`, p99 write `198.18 ms`, p99.9 write `421.53 ms` |

Disk utilization reported by fio:

- Sequential workload: `99.81%`
- Random workload: `100.00%`

## Interpretation

1. The block volume is clearly the bottleneck during both workloads. fio reports essentially full disk utilization in both runs, so the guest VM is not the limiting factor here.
2. Sequential throughput is low for a `1M` block test at about `11-12 MB/s`. That is adequate only for a basic smoke/performance sanity check, not for throughput-heavy database backup, restore, or large-table scan expectations.
3. Random `4k` performance is materially better in IOPS terms than sequential throughput, with about `1520` read and `1520` write IOPS. This is enough to prove the volume is functioning correctly, but the latency profile is not strong for write-sensitive database workloads.
4. Random write latency is the weakest part of the result set. Mean write latency is about `68 ms`, p95 is `132 ms`, and p99 reaches `198 ms`, with rare outliers above `400 ms`. That suggests the storage path is stable but not low-latency under sustained small-block mixed I/O.
5. Read latency is materially better than write latency in the random workload. That asymmetry is typical of storage configurations where write acknowledgement cost is noticeably higher than read service time.

## Practical Conclusion

For Sprint 1, the fio report is sufficient to satisfy BV4DB-6: the benchmark ran successfully, produced valid JSON, and captured an end-to-end block volume performance profile in the target region.

From an engineering perspective, the measured profile should be treated as a **baseline only**, not as a production-ready database performance target. Before using this architecture for database benchmarking or sizing, the next sprint should vary at least:

- block volume performance tier / VPUs
- volume size
- queue depth and job count
- read-only, write-only, and mixed workloads separately
- filesystem vs raw-device testing

## Recommendation

Keep this result as the Sprint 1 reference baseline for `eu-zurich-1`. Compare all future storage changes against this file to determine whether later tuning produces real throughput gains or only shifts latency between read and write paths.
