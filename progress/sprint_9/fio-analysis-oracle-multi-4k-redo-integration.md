# Sprint 9 Multi Volume — Oracle Layout fio Analysis (integration)

## Context

- Runtime: `600 seconds`
- Region: `eu-zurich-1`
- Compute shape: `VM.Standard.E5.Flex` (40 OCPUs)
- Block volumes: 5 (2x UHP 120 VPU, 2x HP 20 VPU, 1x Balanced 10 VPU)

## Measured Results

### fio per-job results
#### data-8k
- Read: `13786 IOPS`, `108 MB/s`, mean latency `1 ms`
- Write: `5907 IOPS`, `46 MB/s`, mean latency `1 ms`

#### data-8k
- Read: `13782 IOPS`, `108 MB/s`, mean latency `1 ms`
- Write: `5908 IOPS`, `46 MB/s`, mean latency `1 ms`

#### data-8k
- Read: `13780 IOPS`, `108 MB/s`, mean latency `1 ms`
- Write: `5905 IOPS`, `46 MB/s`, mean latency `1 ms`

#### data-8k
- Read: `13790 IOPS`, `108 MB/s`, mean latency `1 ms`
- Write: `5902 IOPS`, `46 MB/s`, mean latency `1 ms`

#### redo
- Read: `0 IOPS`, `0 MB/s`, mean latency `0 ms`
- Write: `791 IOPS`, `3 MB/s`, mean latency `0 ms`

#### fra-1m
- Read: `24 IOPS`, `24 MB/s`, mean latency `171 ms`
- Write: `23 IOPS`, `23 MB/s`, mean latency `170 ms`

### Data stripe
- `dm-2` avg read `92.09 MB/s`, avg write `74.67 MB/s`, avg util `52.95%`
- `dm-3` avg read `92.08 MB/s`, avg write `74.68 MB/s`, avg util `52.91%`
- `dm-4` avg read `184.17 MB/s`, avg write `149.35 MB/s`, avg util `53.09%`
- `sdb` avg read `81.16 MB/s`, avg write `65.81 MB/s`, avg util `46.75%`
- `sdg` avg read `81.16 MB/s`, avg write `65.82 MB/s`, avg util `46.78%`

### Redo stripe
- `dm-5` avg read `0.00 MB/s`, avg write `13.45 MB/s`, avg util `70.85%`
- `sdl` avg read `0.00 MB/s`, avg write `6.72 MB/s`, avg util `54.26%`
- `sdm` avg read `0.00 MB/s`, avg write `6.72 MB/s`, avg util `54.17%`

### FRA
- `sdn` avg read `8.18 MB/s`, avg write `34.78 MB/s`, avg util `89.73%`


## Interpretation

This run validates the Oracle-style multi-volume layout with the `4k` redo workload.
Device-level iostat confirms that data, redo, and FRA traffic still follow separate devices and the fio JSON preserves distinct per-job results.

Compared with Sprint 5, the `4k` redo variant improves the separated redo path materially: redo reached about `791 IOPS` and about `3 MiB/s`, while the `data-8k` workers also improved to about `108/46 MB/s` each.
The multi-volume layout therefore remains the stronger Oracle design point in this project: the domains stay separated, and the `4k` redo change can improve redo behavior without forcing FRA and data to share the same hot path.
