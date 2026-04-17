# Sprint 3 — Mixed 8k fio Analysis (smoke)

## Context

- Runtime: `60 seconds`
- Region: `eu-zurich-1`
- Compute shape: `VM.Standard.E5.Flex`
- Block volume VPUs/GB: `120`

## Measured Results

- Read: 28946 IOPS, 226 MB/s, mean latency 3 ms
- Write: 12425 IOPS, 97 MB/s, mean latency 3 ms
- Read mix: `70%`, block size: `8k`, numjobs: `4`, iodepth: `32`

## Interpretation

This Sprint 3 run validates the mixed 8k fio profile file on the Sprint 2 UHP topology. Compare this artifact with Sprint 2 to determine how the database-oriented mixed workload shifts throughput and latency relative to the earlier benchmark.
