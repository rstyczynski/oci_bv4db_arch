# Sprint 10 Balanced Multi — Oracle Layout fio Analysis (integration)

## Context

- Runtime: `600 seconds`
- Region: `eu-zurich-1`
- Compute shape: `VM.Standard.E5.Flex`
- Compute resources: `8 OCPUs`, `32 GB`
- Block volumes: 5
- Volume detail: 2x DATA `200 GB` at `10 VPU/GB`, 2x REDO `50 GB` at `10 VPU/GB`, 1x FRA `100 GB` at `10 VPU/GB`

## Measured Results

### Logical volume totals

#### DATA logical volume
- Read: `16780 IOPS`, `131.09 MiB/s`
- Write: `7187 IOPS`, `56.15 MiB/s`

#### REDO logical volume
- Write: `827 IOPS`, `3.23 MiB/s`

#### FRA logical volume
- Read: `24 IOPS`, `23.57 MiB/s`
- Write: `23 IOPS`, `23.31 MiB/s`

### fio per-job results
#### data-8k
- Read: `4189 IOPS`, `33 MB/s`, mean latency `3 ms`
- Write: `1795 IOPS`, `14 MB/s`, mean latency `3 ms`

#### data-8k
- Read: `4189 IOPS`, `33 MB/s`, mean latency `3 ms`
- Write: `1795 IOPS`, `14 MB/s`, mean latency `3 ms`

#### data-8k
- Read: `4196 IOPS`, `33 MB/s`, mean latency `3 ms`
- Write: `1797 IOPS`, `14 MB/s`, mean latency `3 ms`

#### data-8k
- Read: `4205 IOPS`, `33 MB/s`, mean latency `3 ms`
- Write: `1799 IOPS`, `14 MB/s`, mean latency `3 ms`

#### redo
- Read: `0 IOPS`, `0 MB/s`, mean latency `0 ms`
- Write: `827 IOPS`, `3 MB/s`, mean latency `0 ms`

#### fra-1m
- Read: `24 IOPS`, `24 MB/s`, mean latency `171 ms`
- Write: `23 IOPS`, `23 MB/s`, mean latency `170 ms`

### Data stripe
- `dm-2` avg read `43.43 MB/s`, avg write `129.61 MB/s`, avg util `90.98%`
- `dm-3` avg read `0.00 MB/s`, avg write `11.73 MB/s`, avg util `70.53%`
- `sdb` avg read `21.75 MB/s`, avg write `64.82 MB/s`, avg util `53.51%`

### Redo stripe

### FRA


## Interpretation

This run validates the Oracle-style multi-volume layout with concurrent fio workloads.
Device-level iostat is used to confirm separation between data, redo, and FRA traffic.
For valid per-job fio output, the fio result must contain distinct entries for each concurrent workload.
The redo result is intentionally synchronous (`iodepth=1`, `fdatasync=1`, `4k` writes), so the main signal is stable sync write rate, not high MB/s.
Balanced multi preserves Oracle storage-domain separation and keeps REDO materially stronger than the Balanced single-volume layout.
