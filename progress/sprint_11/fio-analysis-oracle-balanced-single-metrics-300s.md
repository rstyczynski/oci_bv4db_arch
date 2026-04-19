# Sprint 11 — Oracle Layout fio Analysis (integration)

## Context

- Runtime: `300 seconds`
- Region: `eu-zurich-1`
- Compute shape: `VM.Standard.E5.Flex`
- Compute resources: `8 OCPUs`, `32 GB`
- Block volumes: 1
- Volume detail: `600 GB` at `10 VPU/GB`, guest-partitioned into data/redo/fra slices

## Measured Results

### fio per-job results
#### data-8k
- Read: `1626 IOPS`, `13 MB/s`, mean latency `6 ms`
- Write: `699 IOPS`, `5 MB/s`, mean latency `8 ms`

#### data-8k
- Read: `1626 IOPS`, `13 MB/s`, mean latency `6 ms`
- Write: `701 IOPS`, `5 MB/s`, mean latency `8 ms`

#### data-8k
- Read: `1630 IOPS`, `13 MB/s`, mean latency `6 ms`
- Write: `699 IOPS`, `5 MB/s`, mean latency `8 ms`

#### data-8k
- Read: `1630 IOPS`, `13 MB/s`, mean latency `6 ms`
- Write: `699 IOPS`, `5 MB/s`, mean latency `8 ms`

#### redo
- Read: `0 IOPS`, `0 MB/s`, mean latency `0 ms`
- Write: `36 IOPS`, `0 MB/s`, mean latency `9 ms`

#### fra-1m
- Read: `105 IOPS`, `105 MB/s`, mean latency `38 ms`
- Write: `103 IOPS`, `103 MB/s`, mean latency `39 ms`

### Most active devices
- `sdb` avg read `60.47 MB/s`, avg write `210.86 MB/s`, avg util `94.63%`
- `dm-2` avg read `19.66 MB/s`, avg write `116.82 MB/s`, avg util `84.57%`
- `dm-3` avg read `0.00 MB/s`, avg write `6.15 MB/s`, avg util `63.71%`
- `sda` avg read `0.71 MB/s`, avg write `2.26 MB/s`, avg util `4.06%`
- `dm-0` avg read `0.71 MB/s`, avg write `2.24 MB/s`, avg util `3.90%`
- `dm-1` avg read `0.00 MB/s`, avg write `0.02 MB/s`, avg util `0.05%`


## Interpretation

This run validates the Sprint 5 Oracle-style fio workload on a single UHP block volume.
The guest keeps the same visible filesystem and LVM structure, but all activity ultimately shares one underlying block volume.
The comparison with Sprint 5 therefore shows what is lost when storage-domain isolation is removed while keeping the workload and guest layout the same.
