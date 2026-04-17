# Sprint 4 — Oracle Layout fio Analysis (integration)

## Context

- Runtime: `900 seconds`
- Region: `eu-zurich-1`
- Compute shape: `VM.Standard.E5.Flex` (40 OCPUs)
- Block volumes: 5 (2x UHP 120 VPU, 2x HP 20 VPU, 1x Balanced 10 VPU)

## Measured Results

### Aggregated fio result

- fio reported a single aggregated group: `data-8k`
- Read: `52446 IOPS`, `433 MB/s`, mean latency `2 ms`
- Write: `22712 IOPS`, `255 MB/s`, mean latency `2 ms`

### Device-level view

#### Data stripe

- `dm-2` avg read `128.38 MB/s`, avg write `77.30 MB/s`, avg util `68.93%`
- `dm-3` avg read `129.93 MB/s`, avg write `78.23 MB/s`, avg util `69.81%`
- `dm-4` avg read `256.74 MB/s`, avg write `154.58 MB/s`, avg util `69.09%`
- `sdb` avg read `118.39 MB/s`, avg write `71.29 MB/s`, avg util `63.63%`
- `sdg` avg read `119.71 MB/s`, avg write `72.07 MB/s`, avg util `64.42%`

#### Redo stripe

- `dm-5` avg read `0.00 MB/s`, avg write `48.79 MB/s`, avg util `80.64%`
- `sdl` avg read `0.00 MB/s`, avg write `24.40 MB/s`, avg util `70.15%`
- `sdm` avg read `0.00 MB/s`, avg write `24.78 MB/s`, avg util `29.04%`

#### FRA

- `sdn` avg read `12.82 MB/s`, avg write `31.28 MB/s`, avg util `92.80%`

## Interpretation

This `900`-second run confirms the Oracle-style layout under a sustained concurrent workload.
The fio JSON still aggregates the concurrent sections into one reported group, so storage-class isolation is validated primarily from the device-level `iostat` data.
The expected split remains visible over the longer interval: the striped UHP data pair carries the dominant mixed workload, redo traffic stays concentrated on the redo stripe, and FRA traffic remains isolated on the FRA volume.
