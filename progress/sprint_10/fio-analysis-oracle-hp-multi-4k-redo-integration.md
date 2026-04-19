# Sprint 10 Higher Performance Multi — Oracle Layout fio Analysis (integration)

## Context

- Runtime: `600 seconds`
- Region: `eu-zurich-1`
- Compute shape: `VM.Standard.E5.Flex`
- Compute resources: `8 OCPUs`, `32 GB`
- Block volumes: 5
- Volume detail: 2x DATA `200 GB` at `20 VPU/GB`, 2x REDO `50 GB` at `20 VPU/GB`, 1x FRA `100 GB` at `20 VPU/GB`

## Measured Results

### Logical volume totals

#### DATA logical volume
- Read: `20979 IOPS`, `163.90 MiB/s`
- Write: `8984 IOPS`, `70.19 MiB/s`

#### REDO logical volume
- Write: `769 IOPS`, `3.00 MiB/s`

#### FRA logical volume
- Read: `29 IOPS`, `29.37 MiB/s`
- Write: `29 IOPS`, `29.22 MiB/s`

### fio per-job results
#### data-8k
- Read: `5238 IOPS`, `41 MB/s`, mean latency `2 ms`
- Write: `2245 IOPS`, `18 MB/s`, mean latency `2 ms`

#### data-8k
- Read: `5245 IOPS`, `41 MB/s`, mean latency `2 ms`
- Write: `2247 IOPS`, `18 MB/s`, mean latency `2 ms`

#### data-8k
- Read: `5244 IOPS`, `41 MB/s`, mean latency `2 ms`
- Write: `2247 IOPS`, `18 MB/s`, mean latency `2 ms`

#### data-8k
- Read: `5253 IOPS`, `41 MB/s`, mean latency `2 ms`
- Write: `2246 IOPS`, `18 MB/s`, mean latency `2 ms`

#### redo
- Read: `0 IOPS`, `0 MB/s`, mean latency `0 ms`
- Write: `769 IOPS`, `3 MB/s`, mean latency `0 ms`

#### fra-1m
- Read: `29 IOPS`, `29 MB/s`, mean latency `136 ms`
- Write: `29 IOPS`, `29 MB/s`, mean latency `137 ms`

### Data stripe
- `dm-2` avg read `85.34 MB/s`, avg write `131.38 MB/s`, avg util `90.80%`
- `dm-3` avg read `0.00 MB/s`, avg write `14.70 MB/s`, avg util `74.77%`
- `sdb` avg read `42.68 MB/s`, avg write `65.72 MB/s`, avg util `68.15%`

### Redo stripe

### FRA


## Interpretation

This run validates the Oracle-style multi-volume layout with concurrent fio workloads.
Device-level iostat is used to confirm separation between data, redo, and FRA traffic.
For valid per-job fio output, the fio result must contain distinct entries for each concurrent workload.
The redo result is intentionally synchronous (`iodepth=1`, `fdatasync=1`, `4k` writes), so the main signal is sustained sync write rate, not raw throughput.
Higher Performance multi remains the strongest Sprint 10 result because it keeps the Oracle storage domains isolated while raising the OCI tier for all three domains.
