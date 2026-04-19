# Sprint 10 Lower Cost Single — Oracle Layout fio Analysis (integration)

## Context

- Runtime: `600 seconds`
- Region: `eu-zurich-1`
- Compute shape: `VM.Standard.E5.Flex`
- Compute resources: `2 OCPUs`, `16 GB`
- Block volumes: 1
- Volume detail: `600 GB` at `0 VPU/GB`, guest-partitioned into data/redo/fra slices

## Measured Results

### Logical volume totals

#### DATA logical volume
- Read: `754 IOPS`, `5.89 MiB/s`
- Write: `324 IOPS`, `2.53 MiB/s`

#### REDO logical volume
- Write: `4 IOPS`, `0.02 MiB/s`

#### FRA logical volume
- Read: `13 IOPS`, `12.88 MiB/s`
- Write: `12 IOPS`, `12.39 MiB/s`

### fio per-job results
#### data-8k
- Read: `189 IOPS`, `1 MB/s`, mean latency `55 ms`
- Write: `81 IOPS`, `1 MB/s`, mean latency `68 ms`

#### data-8k
- Read: `188 IOPS`, `1 MB/s`, mean latency `56 ms`
- Write: `81 IOPS`, `1 MB/s`, mean latency `69 ms`

#### data-8k
- Read: `188 IOPS`, `1 MB/s`, mean latency `56 ms`
- Write: `81 IOPS`, `1 MB/s`, mean latency `69 ms`

#### data-8k
- Read: `189 IOPS`, `1 MB/s`, mean latency `55 ms`
- Write: `81 IOPS`, `1 MB/s`, mean latency `69 ms`

#### redo
- Read: `0 IOPS`, `0 MB/s`, mean latency `0 ms`
- Write: `4 IOPS`, `0.02 MiB/s`, mean latency `81 ms`

#### fra-1m
- Read: `13 IOPS`, `13 MB/s`, mean latency `328 ms`
- Write: `12 IOPS`, `12 MB/s`, mean latency `305 ms`

### Most active devices
- `sdb` avg read `7.85 MB/s`, avg write `84.97 MB/s`, avg util `98.31%`
- `dm-2` avg read `3.00 MB/s`, avg write `65.81 MB/s`, avg util `96.69%`
- `dm-3` avg read `0.00 MB/s`, avg write `0.17 MB/s`, avg util `86.83%`
- `sda` avg read `0.07 MB/s`, avg write `0.09 MB/s`, avg util `0.19%`
- `dm-0` avg read `0.07 MB/s`, avg write `0.07 MB/s`, avg util `0.17%`
- `dm-1` avg read `0.00 MB/s`, avg write `0.01 MB/s`, avg util `0.02%`


## Interpretation

This run validates the Sprint 9 Oracle-style fio workload on one OCI Lower Cost block volume.
The guest-visible filesystem and LVM structure stay the same, but all activity shares one very low-performance contention domain.
The redo result is intentionally synchronous (`iodepth=1`, `fdatasync=1`, `4k` writes), so low throughput is expected and the meaningful signal is very low sync write rate.
This layout is useful as the OCI Lower Cost Oracle reference point, but it is too weak for any serious concurrent production-style Oracle workload.
