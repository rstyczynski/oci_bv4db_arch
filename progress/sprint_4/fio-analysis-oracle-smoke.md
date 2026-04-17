# Sprint 4 — Oracle Layout fio Analysis (smoke)

## Context

- Runtime: `60 seconds`
- Region: `eu-zurich-1`
- Compute shape: `VM.Standard.E5.Flex` (40 OCPUs)
- Block volumes: 5 (2x UHP 120 VPU, 2x HP 20 VPU, 1x Balanced 10 VPU)

## Measured Results

### Aggregated fio result
- fio reported a single aggregated group: `data-8k`
- Read: `56197 IOPS`, `462 MB/s`, mean latency `2 ms`
- Write: `24294 IOPS`, `267 MB/s`, mean latency `2 ms`

### Data stripe
- `dm-2` avg read `182.62 MB/s`, avg write `78.92 MB/s`, avg util `82.51%`
- `dm-3` avg read `182.44 MB/s`, avg write `78.79 MB/s`, avg util `82.52%`
- `dm-4` avg read `365.06 MB/s`, avg write `157.71 MB/s`, avg util `82.53%`
- `sdb` avg read `167.40 MB/s`, avg write `72.34 MB/s`, avg util `75.64%`
- `sdg` avg read `182.44 MB/s`, avg write `78.79 MB/s`, avg util `82.53%`

### Redo stripe
- `dm-5` avg read `0.00 MB/s`, avg write `45.04 MB/s`, avg util `75.55%`
- `sdl` avg read `0.00 MB/s`, avg write `22.52 MB/s`, avg util `28.50%`
- `sdm` avg read `0.00 MB/s`, avg write `24.56 MB/s`, avg util `69.79%`

### FRA
- `sdn` avg read `19.74 MB/s`, avg write `20.35 MB/s`, avg util `84.11%`


## Interpretation

This Sprint 4 smoke run validates the Oracle-style multi-volume layout with concurrent fio workloads.
fio aggregates the concurrent sections into one reporting group in JSON output, so storage-class isolation is validated from device-level iostat data.
The expected pattern is a busy data stripe on the UHP pair, redo traffic on the redo pair, and FRA traffic isolated to the FRA volume.
