# Sprint 10 Higher Performance Single — Oracle Layout fio Analysis (integration)

## Context

- Runtime: `600 seconds`
- Region: `eu-zurich-1`
- Compute shape: `VM.Standard.E5.Flex`
- Compute resources: `8 OCPUs`, `32 GB`
- Block volumes: 1
- Volume detail: `600 GB` at `20 VPU/GB`, guest-partitioned into data/redo/fra slices

## Measured Results

### Logical volume totals

#### DATA logical volume
- Read: `9893 IOPS`, `77.29 MiB/s`
- Write: `4241 IOPS`, `33.13 MiB/s`

#### REDO logical volume
- Write: `60 IOPS`, `0.23 MiB/s`

#### FRA logical volume
- Read: `120 IOPS`, `120.00 MiB/s`
- Write: `120 IOPS`, `120.00 MiB/s`

### fio per-job results
#### data-8k
- Read: `2472 IOPS`, `19 MB/s`, mean latency `4 ms`
- Write: `1060 IOPS`, `8 MB/s`, mean latency `5 ms`

#### data-8k
- Read: `2474 IOPS`, `19 MB/s`, mean latency `4 ms`
- Write: `1061 IOPS`, `8 MB/s`, mean latency `5 ms`

#### data-8k
- Read: `2473 IOPS`, `19 MB/s`, mean latency `4 ms`
- Write: `1060 IOPS`, `8 MB/s`, mean latency `5 ms`

#### data-8k
- Read: `2474 IOPS`, `19 MB/s`, mean latency `4 ms`
- Write: `1059 IOPS`, `8 MB/s`, mean latency `5 ms`

#### redo
- Read: `0 IOPS`, `0 MB/s`, mean latency `0 ms`
- Write: `60 IOPS`, `0.23 MiB/s`, mean latency `6 ms`

#### fra-1m
- Read: `120 IOPS`, `120 MB/s`, mean latency `21 ms`
- Write: `120 IOPS`, `120 MB/s`, mean latency `27 ms`

### Most active devices
- `sdb` avg read `143.64 MB/s`, avg write `200.75 MB/s`, avg util `97.09%`
- `dm-2` avg read `56.27 MB/s`, avg write `83.26 MB/s`, avg util `92.84%`
- `dm-3` avg read `0.00 MB/s`, avg write `3.49 MB/s`, avg util `86.33%`
- `sda` avg read `0.42 MB/s`, avg write `0.98 MB/s`, avg util `2.24%`
- `dm-0` avg read `0.42 MB/s`, avg write `0.96 MB/s`, avg util `2.23%`
- `dm-1` avg read `0.00 MB/s`, avg write `0.02 MB/s`, avg util `0.02%`


## Interpretation

This run validates the Sprint 9 Oracle-style fio workload on one OCI Higher Performance block volume.
The guest keeps the same visible filesystem and LVM structure, but all activity ultimately shares one underlying block volume.
The redo result is intentionally synchronous (`iodepth=1`, `fdatasync=1`, `4k` writes), so low MiB/s is expected and the real signal is sync write rate.
Higher Performance improves single-volume DATA and REDO over Balanced, but it still does not create true Oracle storage-domain isolation.
