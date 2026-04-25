# Sprint 23 OCI Metrics Dashboard (bv4db multipath A/B with LB policy)

- Start time: `2026-04-25T22:23:58Z`
- End time: `2026-04-25T22:32:59Z`
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
| VolumeReadThroughput (bytes/interval) | 8 | 0.00 MiB (2.09 MiB) | 1543.65 MiB | 5828.40 MiB | 0.00 MiB |
| VolumeWriteThroughput (bytes/interval) | 8 | 0.00 MiB (1018.26 MiB) | 660.98 MiB | 2497.88 MiB | 0.00 MiB |
| VolumeReadOps (ops) | 8 | 0.00 (111.67) | 394896.29 | 1491657.20 | 0.00 |
| VolumeWriteOps (ops) | 8 | 0.00 (0.20) | 169177.47 | 639356.20 | 0.00 |

## Compute

### compute

| Metric | Points | Min | Avg | Max | Latest |
| ------ | ------ | --- | --- | --- | ------ |
| CpuUtilization (percent) | 8 | 0.01% | 4.61% | 17.93% | 0.01% |
| MemoryUtilization (percent) | 8 | 2.31% | 2.79% | 4.10% | 2.36% |
| DiskBytesRead (bytes/s) | 8 | -245.99 MiB/s | 80.59 MiB/s | 445.58 MiB/s | 0.00 MiB/s |
| DiskBytesWritten (bytes/s) | 8 | -105.67 MiB/s | 34.52 MiB/s | 190.88 MiB/s | 0.03 MiB/s |

## Network

### primary_vnic

| Metric | Points | Min | Avg | Max | Latest |
| ------ | ------ | --- | --- | --- | ------ |
| VnicFromNetworkBytes (bytes/interval) | 8 | 0.02 MiB | 6927.66 MiB | 26642.20 MiB | 0.08 MiB |
| VnicToNetworkBytes (bytes/interval) | 8 | 0.06 MiB | 3160.00 MiB | 12151.25 MiB | 0.09 MiB |
| VnicEgressDropsSecurityList (packets) | 8 | 0.00 | 0.00 | 0.00 | 0.00 |
| VnicIngressDropsSecurityList (packets) | 8 | 0.00 (1.00) | 0.38 | 1.00 | 0.00 |

