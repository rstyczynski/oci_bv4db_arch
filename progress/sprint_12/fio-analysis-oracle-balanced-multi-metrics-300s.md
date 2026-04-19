# Sprint 12 — Oracle Layout fio Analysis (integration)

## Context

- Runtime: `300 seconds`
- Region: `eu-zurich-1`
- Compute shape: `VM.Standard.E5.Flex`
- Compute resources: `8 OCPUs`, `32 GB`
- Block volumes: 5
- Volume detail: 2x DATA `200 GB` at `10 VPU/GB`, 2x REDO `50 GB` at `10 VPU/GB`, 1x FRA `100 GB` at `10 VPU/GB`

## Measured Results

### fio per-job results
#### data-8k
- Read: `4191 IOPS`, `33 MB/s`, mean latency `3 ms`
- Write: `1797 IOPS`, `14 MB/s`, mean latency `3 ms`

#### data-8k
- Read: `4185 IOPS`, `33 MB/s`, mean latency `3 ms`
- Write: `1794 IOPS`, `14 MB/s`, mean latency `3 ms`

#### data-8k
- Read: `4193 IOPS`, `33 MB/s`, mean latency `3 ms`
- Write: `1797 IOPS`, `14 MB/s`, mean latency `3 ms`

#### data-8k
- Read: `4203 IOPS`, `33 MB/s`, mean latency `3 ms`
- Write: `1798 IOPS`, `14 MB/s`, mean latency `3 ms`

#### redo
- Read: `0 IOPS`, `0 MB/s`, mean latency `0 ms`
- Write: `790 IOPS`, `3 MB/s`, mean latency `0 ms`

#### fra-1m
- Read: `24 IOPS`, `24 MB/s`, mean latency `174 ms`
- Write: `23 IOPS`, `23 MB/s`, mean latency `168 ms`

### Data stripe
- `dm-2` avg read `0.00 MB/s`, avg write `170.78 MB/s`, avg util `89.55%`
- `dm-3` avg read `0.00 MB/s`, avg write `12.38 MB/s`, avg util `2.43%`
- `sdb` avg read `0.00 MB/s`, avg write `85.39 MB/s`, avg util `89.75%`

### Redo stripe

### FRA


## Interpretation

This run validates the Oracle-style multi-volume layout with concurrent fio workloads.
Device-level iostat is used to confirm separation between data, redo, and FRA traffic.
For valid per-job fio output, the fio result must contain distinct entries for each concurrent workload.
