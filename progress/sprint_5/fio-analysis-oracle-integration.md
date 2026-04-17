# Sprint 5 — Oracle Layout fio Analysis (integration)

## Context

- Runtime: `600 seconds`
- Region: `eu-zurich-1`
- Compute shape: `VM.Standard.E5.Flex` (40 OCPUs)
- Block volumes: 5 (2x UHP 120 VPU, 2x HP 20 VPU, 1x Balanced 10 VPU)

## Measured Results

### fio per-job results
#### data-8k
- Read: `12730 IOPS`, `99 MB/s`, mean latency `1 ms`
- Write: `5454 IOPS`, `43 MB/s`, mean latency `1 ms`

#### data-8k
- Read: `12727 IOPS`, `99 MB/s`, mean latency `1 ms`
- Write: `5453 IOPS`, `43 MB/s`, mean latency `1 ms`

#### data-8k
- Read: `12729 IOPS`, `99 MB/s`, mean latency `1 ms`
- Write: `5454 IOPS`, `43 MB/s`, mean latency `1 ms`

#### data-8k
- Read: `12735 IOPS`, `99 MB/s`, mean latency `1 ms`
- Write: `5452 IOPS`, `43 MB/s`, mean latency `1 ms`

#### redo
- Read: `0 IOPS`, `0 MB/s`, mean latency `0 ms`
- Write: `1532 IOPS`, `1 MB/s`, mean latency `1 ms`

#### fra-1m
- Read: `24 IOPS`, `24 MB/s`, mean latency `170 ms`
- Write: `23 IOPS`, `23 MB/s`, mean latency `171 ms`

### Data stripe
- `dm-2` avg read `196.18 MB/s`, avg write `84.36 MB/s`, avg util `98.60%`
- `dm-3` avg read `196.19 MB/s`, avg write `84.36 MB/s`, avg util `98.60%`
- `dm-4` avg read `392.37 MB/s`, avg write `168.72 MB/s`, avg util `98.61%`
- `sdb` avg read `196.18 MB/s`, avg write `84.36 MB/s`, avg util `98.61%`
- `sdg` avg read `196.19 MB/s`, avg write `84.36 MB/s`, avg util `98.60%`

### Redo stripe
- `dm-5` avg read `0.00 MB/s`, avg write `3.77 MB/s`, avg util `98.55%`
- `sdl` avg read `0.00 MB/s`, avg write `1.89 MB/s`, avg util `56.52%`
- `sdm` avg read `0.00 MB/s`, avg write `1.89 MB/s`, avg util `57.37%`

### FRA
- `sdn` avg read `23.36 MB/s`, avg write `23.28 MB/s`, avg util `99.04%`


## Interpretation

This run confirms that the Oracle-style multi-volume layout is functioning correctly under concurrent fio workloads and that data, redo, and FRA traffic are reaching their intended devices. The data-8k workload is stable and low-latency, while the redo path sustains low-latency synchronous writes. However, device utilization reaches saturation on key paths, and the FRA workload falls well below its configured rate with high latency. This should therefore be treated as a successful integration/smoke result, but not yet as evidence of production headroom or final sizing validation. Because group_reporting=0 was used, the fio JSON exposes separate per-job results for each concurrent workload.