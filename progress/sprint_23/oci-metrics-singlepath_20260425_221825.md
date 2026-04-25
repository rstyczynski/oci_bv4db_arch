# Sprint 23 OCI Metrics Dashboard (bv4db multipath A/B with LB policy)

- Start time: `2026-04-25T22:11:20Z`
- End time: `2026-04-25T22:20:21Z`
- Resolution: `1m`

## Table of Contents

- [Blockvolume](#blockvolume)
  - [blockvolume](#blockvolume)
- [Compute](#compute)
  - [compute](#compute)
- [Network](#network)
  - [primary_vnic](#primary_vnic)

## Blockvolume

### blockvolume

| Metric | Points | Min | Avg | Max | Latest |
| ------ | ------ | --- | --- | --- | ------ |
| VolumeReadThroughput (bytes/interval) | 6 | 0.00 MiB (1628.52 MiB) | 2190.70 MiB | 7406.82 MiB | 0.00 MiB |
| VolumeWriteThroughput (bytes/interval) | 6 | 0.00 MiB | 940.03 MiB | 3180.09 MiB | 0.02 MiB |
| VolumeReadOps (ops) | 6 | 0.00 (416221.50) | 560685.75 | 1896046.00 | 0.00 |
| VolumeWriteOps (ops) | 6 | 0.40 | 240560.20 | 814103.00 | 1.00 |

## Compute

### compute

| Metric | Points | Min | Avg | Max | Latest |
| ------ | ------ | --- | --- | --- | ------ |
| CpuUtilization (percent) | 8 | 0.01% | 0.79% | 2.86% | 0.01% |
| MemoryUtilization (percent) | 8 | 2.30% | 2.74% | 4.03% | 2.31% |
| DiskBytesRead (bytes/s) | 8 | -196.65 MiB/s | -2.70 MiB/s | 121.01 MiB/s | 0.00 MiB/s |
| DiskBytesWritten (bytes/s) | 8 | -382.21 MiB/s | -38.05 MiB/s | 51.92 MiB/s | 0.02 MiB/s |

## Network

### primary_vnic

| Metric | Points | Min | Avg | Max | Latest |
| ------ | ------ | --- | --- | --- | ------ |
| VnicFromNetworkBytes (bytes/interval) | 8 | 0.02 MiB | 1909.92 MiB | 7862.48 MiB | 0.02 MiB |
| VnicToNetworkBytes (bytes/interval) | 8 | 0.07 MiB | 859.73 MiB | 3548.13 MiB | 0.07 MiB |
| VnicEgressDropsSecurityList (packets) | 8 | 0.00 | 0.00 | 0.00 | 0.00 |
| VnicIngressDropsSecurityList (packets) | 8 | 1.00 | 1.50 | 3.00 | 1.00 |

