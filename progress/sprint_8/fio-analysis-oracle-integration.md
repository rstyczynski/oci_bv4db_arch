# Sprint 8 — Oracle Layout fio Analysis (integration)

## Context

- Runtime: `600 seconds`
- Region: `eu-zurich-1`
- Compute shape: `VM.Standard.E5.Flex` (40 OCPUs)
- Block volumes: `1` (`1x` UHP `120 VPU/GB`, `600 GB` total)
- Guest layout: same as Sprint 5
  - `/u02/oradata` on striped `vg_data/lv_oradata`
  - `/u03/redo` on striped `vg_redo/lv_redo`
  - `/u04/fra` on direct-mounted FRA partition
- Difference from Sprint 5: all guest-visible domains are backed by partitions of the same single UHP block volume

## Measured Results

### fio per-job results
#### data-8k
- Read: `4771 IOPS`, `37 MB/s`, mean latency `2 ms`
- Write: `2045 IOPS`, `16 MB/s`, mean latency `3 ms`

#### data-8k
- Read: `4772 IOPS`, `37 MB/s`, mean latency `2 ms`
- Write: `2045 IOPS`, `16 MB/s`, mean latency `3 ms`

#### data-8k
- Read: `4773 IOPS`, `37 MB/s`, mean latency `2 ms`
- Write: `2044 IOPS`, `16 MB/s`, mean latency `3 ms`

#### data-8k
- Read: `4777 IOPS`, `37 MB/s`, mean latency `2 ms`
- Write: `2043 IOPS`, `16 MB/s`, mean latency `3 ms`

#### redo
- Read: `0 IOPS`, `0 MB/s`, mean latency `0 ms`
- Write: `292 IOPS`, `0 MB/s`, mean latency `3 ms`

#### fra-1m
- Read: `120 IOPS`, `120 MB/s`, mean latency `5 ms`
- Write: `120 IOPS`, `120 MB/s`, mean latency `10 ms`

### Most active devices
- `sdb` avg read `225.71 MB/s`, avg write `237.21 MB/s`, avg util `96.88%`
- `dm-2` avg read `225.71 MB/s`, avg write `237.21 MB/s`, avg util `94.75%`
- `dm-8` avg read `124.38 MB/s`, avg write `108.86 MB/s`, avg util `94.62%`
- `dm-3` avg read `62.16 MB/s`, avg write `54.44 MB/s`, avg util `90.71%`
- `dm-9` avg read `0.00 MB/s`, avg write `2.92 MB/s`, avg util `89.63%`
- `dm-4` avg read `62.21 MB/s`, avg write `54.42 MB/s`, avg util `89.25%`
- `dm-7` avg read `101.33 MB/s`, avg write `127.99 MB/s`, avg util `69.07%`

## Interpretation

This run validates the Sprint 5 Oracle fio workload on a single UHP block volume while preserving the same guest-visible filesystem and LVM layout. The test is therefore a direct topology comparison: Sprint 5 separates storage domains across multiple block volumes, while Sprint 8 keeps the same guest shape but collapses all domains onto one underlying device.

The result is clear. The single UHP volume sustains the combined workload, but the shared device becomes the contention point. Compared with Sprint 5, the `data-8k` workers drop from about `99/43 MB/s` per worker to about `37/16 MB/s` per worker, and the `redo` path drops from about `1532 IOPS` to about `292 IOPS`. FRA behaves differently: on Sprint 8 it reaches roughly the configured `120 MB/s` rate in both directions, which is better than the balanced-volume FRA result from Sprint 5, but it does so by consuming bandwidth from the same underlying UHP volume that must also serve data and redo.

Device-level `iostat` supports that reading. The dominant activity converges on the single underlying UHP device and its mapped layers instead of staying isolated by storage class. So Sprint 8 is a valid execution and a useful comparison point, but it is not equivalent to Sprint 5 from an isolation standpoint: keeping the same mount points and LVM names does not preserve storage-domain separation when all traffic ultimately shares one block volume.
