# Sprint 5 — Oracle Layout fio Analysis (smoke)

## Context

- Runtime: `60 seconds`
- Region: `eu-zurich-1`
- Compute shape: `VM.Standard.E5.Flex` (40 OCPUs)
- Block volumes: 5 (2x UHP 120 VPU, 2x HP 20 VPU, 1x Balanced 10 VPU)

## Measured Results

### fio per-job results

#### data-8k

- Read: `12794 IOPS`, `100 MB/s`, mean latency `1 ms`
- Write: `5492 IOPS`, `43 MB/s`, mean latency `1 ms`

#### data-8k

- Read: `12803 IOPS`, `100 MB/s`, mean latency `1 ms`
- Write: `5474 IOPS`, `43 MB/s`, mean latency `1 ms`

#### data-8k

- Read: `12807 IOPS`, `100 MB/s`, mean latency `1 ms`
- Write: `5481 IOPS`, `43 MB/s`, mean latency `1 ms`

#### data-8k

- Read: `12814 IOPS`, `100 MB/s`, mean latency `1 ms`
- Write: `5476 IOPS`, `43 MB/s`, mean latency `1 ms`

#### redo

- Read: `0 IOPS`, `0 MB/s`, mean latency `0 ms`
- Write: `1518 IOPS`, `1 MB/s`, mean latency `1 ms`

#### fra-1m

- Read: `24 IOPS`, `24 MB/s`, mean latency `177 ms`
- Write: `23 IOPS`, `23 MB/s`, mean latency `165 ms`

### Data stripe

- `dm-2` avg read `0.00 MB/s`, avg write `140.06 MB/s`, avg util `37.89%`
- `dm-3` avg read `0.00 MB/s`, avg write `140.05 MB/s`, avg util `36.76%`
- `dm-4` avg read `0.00 MB/s`, avg write `280.11 MB/s`, avg util `38.17%`
- `sdb` avg read `0.00 MB/s`, avg write `140.06 MB/s`, avg util `38.33%`
- `sdg` avg read `0.00 MB/s`, avg write `140.05 MB/s`, avg util `37.47%`

### Redo stripe

- `dm-5` avg read `0.00 MB/s`, avg write `7.90 MB/s`, avg util `1.59%`
- `sdl` avg read `0.00 MB/s`, avg write `3.95 MB/s`, avg util `1.51%`
- `sdm` avg read `0.00 MB/s`, avg write `3.95 MB/s`, avg util `1.57%`

### FRA

- `sdn` avg read `0.00 MB/s`, avg write `25.39 MB/s`, avg util `45.69%`

## Interpretation

This smoke run confirms that the corrected fio profile preserves per-job output instead of collapsing concurrent jobs into a single aggregated group.
The smoke result is suitable as a functional validation of the corrected workload definition before the longer integration run.
Device-level `iostat` still shows the intended split between the data stripe, redo stripe, and FRA volume.
