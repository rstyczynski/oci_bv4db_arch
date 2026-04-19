# Sprint 9 Single UHP — Oracle Layout fio Analysis (integration)

## Context

- Runtime: `600 seconds`
- Region: `eu-zurich-1`
- Compute shape: `VM.Standard.E5.Flex` (40 OCPUs)
- Block volumes: 1 (1x UHP 120 VPU, 600 GB total, guest-partitioned into data/redo/fra slices)

## Measured Results

### fio per-job results
#### data-8k
- Read: `4650 IOPS`, `36 MB/s`, mean latency `2 ms`
- Write: `1993 IOPS`, `16 MB/s`, mean latency `3 ms`

#### data-8k
- Read: `4651 IOPS`, `36 MB/s`, mean latency `2 ms`
- Write: `1993 IOPS`, `16 MB/s`, mean latency `3 ms`

#### data-8k
- Read: `4651 IOPS`, `36 MB/s`, mean latency `2 ms`
- Write: `1992 IOPS`, `16 MB/s`, mean latency `3 ms`

#### data-8k
- Read: `4653 IOPS`, `36 MB/s`, mean latency `2 ms`
- Write: `1990 IOPS`, `16 MB/s`, mean latency `3 ms`

#### redo
- Read: `0 IOPS`, `0 MB/s`, mean latency `0 ms`
- Write: `131 IOPS`, `1 MB/s`, mean latency `3 ms`

#### fra-1m
- Read: `120 IOPS`, `120 MB/s`, mean latency `5 ms`
- Write: `120 IOPS`, `120 MB/s`, mean latency `10 ms`

### Most active devices
- `sdb` avg read `225.03 MB/s`, avg write `244.96 MB/s`, avg util `97.16%`
- `dm-8` avg read `122.96 MB/s`, avg write `111.58 MB/s`, avg util `95.08%`
- `dm-2` avg read `225.03 MB/s`, avg write `244.96 MB/s`, avg util `94.93%`
- `dm-3` avg read `61.46 MB/s`, avg write `55.80 MB/s`, avg util `91.44%`
- `dm-4` avg read `61.50 MB/s`, avg write `55.78 MB/s`, avg util `90.24%`
- `dm-9` avg read `0.00 MB/s`, avg write `6.43 MB/s`, avg util `89.59%`
- `dm-7` avg read `102.07 MB/s`, avg write `131.30 MB/s`, avg util `68.65%`
- `dm-6` avg read `0.00 MB/s`, avg write `3.21 MB/s`, avg util `52.98%`
- `dm-5` avg read `0.00 MB/s`, avg write `3.21 MB/s`, avg util `51.67%`
- `sda` avg read `0.13 MB/s`, avg write `1.24 MB/s`, avg util `2.14%`


## Interpretation

This run validates the `4k` redo Oracle-style fio workload on a single UHP block volume.
The guest keeps the same visible filesystem and LVM structure as the separated Oracle model, but all activity ultimately shares one underlying block volume.
The result is consistent with Sprint 8: once `DATA`, `REDO`, and `FRA` all share one UHP device, the single device becomes the contention point.

The `4k` redo change did not improve the single-volume result. `REDO` reached about `131 IOPS` and about `1 MiB/s`, while the `data-8k` workers stayed around `36/16 MB/s` each and FRA still consumed about `120/120 MB/s`.
So on the single-UHP topology, moving redo from `512B` to `4k` did not remove the fundamental bottleneck: all three domains still compete on the same underlying device.
