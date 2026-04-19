# Sprint 10 Balanced Single — Oracle Layout fio Analysis (integration)

## Context

- Runtime: `600 seconds`
- Region: `eu-zurich-1`
- Compute shape: `VM.Standard.E5.Flex`
- Compute resources: `8 OCPUs`, `32 GB`
- Block volumes: 1
- Volume detail: `600 GB` at `10 VPU/GB`, guest-partitioned into data/redo/fra slices

## Measured Results

### Logical volume totals

#### DATA logical volume
- Read: `6395 IOPS`, `49.96 MiB/s`
- Write: `2742 IOPS`, `21.43 MiB/s`

#### REDO logical volume
- Write: `36 IOPS`, `0.14 MiB/s`

#### FRA logical volume
- Read: `105 IOPS`, `104.77 MiB/s`
- Write: `104 IOPS`, `104.30 MiB/s`

### fio per-job results
#### data-8k
- Read: `1596 IOPS`, `12 MB/s`, mean latency `6 ms`
- Write: `685 IOPS`, `5 MB/s`, mean latency `8 ms`

#### data-8k
- Read: `1598 IOPS`, `12 MB/s`, mean latency `6 ms`
- Write: `686 IOPS`, `5 MB/s`, mean latency `8 ms`

#### data-8k
- Read: `1601 IOPS`, `13 MB/s`, mean latency `6 ms`
- Write: `686 IOPS`, `5 MB/s`, mean latency `8 ms`

#### data-8k
- Read: `1599 IOPS`, `12 MB/s`, mean latency `6 ms`
- Write: `685 IOPS`, `5 MB/s`, mean latency `8 ms`

#### redo
- Read: `0 IOPS`, `0 MB/s`, mean latency `0 ms`
- Write: `36 IOPS`, `0.14 MiB/s`, mean latency `9 ms`

#### fra-1m
- Read: `105 IOPS`, `105 MB/s`, mean latency `38 ms`
- Write: `104 IOPS`, `104 MB/s`, mean latency `38 ms`

### Most active devices
- `sdb` avg read `103.52 MB/s`, avg write `172.22 MB/s`, avg util `97.09%`
- `dm-2` avg read `33.45 MB/s`, avg write `73.26 MB/s`, avg util `91.54%`
- `dm-3` avg read `0.00 MB/s`, avg write `3.09 MB/s`, avg util `83.57%`
- `sda` avg read `0.41 MB/s`, avg write `0.88 MB/s`, avg util `2.06%`
- `dm-0` avg read `0.40 MB/s`, avg write `0.86 MB/s`, avg util `2.03%`
- `dm-1` avg read `0.00 MB/s`, avg write `0.02 MB/s`, avg util `0.03%`


## Interpretation

This run validates the Sprint 9 Oracle-style fio workload on one OCI Balanced block volume.
The guest keeps the same visible filesystem and LVM structure, but all activity ultimately shares one underlying block volume.
The redo result is intentionally synchronous (`iodepth=1`, `fdatasync=1`, `4k` writes), so low throughput is expected and the meaningful signal is sync write rate rather than raw bandwidth.
Balanced materially improves over Lower Cost, but the single-volume topology still lets FRA consume bandwidth that DATA and REDO also need.
