# Sprint 23 OCI Metrics Dashboard (bv4db multipath A/B with LB policy)

- Start time: `2026-04-25T22:29:32Z`
- End time: `2026-04-25T22:38:33Z`
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
| VolumeReadThroughput (bytes/interval) | 7 | 0.00 MiB (807.27 MiB) | 2001.32 MiB | 7952.86 MiB | 0.00 MiB |
| VolumeWriteThroughput (bytes/interval) | 7 | 0.00 MiB (0.02 MiB) | 858.65 MiB | 3415.40 MiB | 0.00 MiB |
| VolumeReadOps (ops) | 7 | 0.00 (206192.33) | 512247.62 | 2035835.00 | 0.00 |
| VolumeWriteOps (ops) | 7 | 0.00 (0.20) | 219762.98 | 874336.00 | 0.00 |

## Compute

### compute

| Metric | Points | Min | Avg | Max | Latest |
| ------ | ------ | --- | --- | --- | ------ |
| CpuUtilization (percent) | 8 | 0.00% | 0.78% | 2.96% | 0.00% |
| MemoryUtilization (percent) | 8 | 2.33% | 2.77% | 4.07% | 2.33% |
| DiskBytesRead (bytes/s) | 8 | -843.07 MiB/s | -78.81 MiB/s | 132.47 MiB/s | 0.00 MiB/s |
| DiskBytesWritten (bytes/s) | 8 | -360.98 MiB/s | -33.71 MiB/s | 56.89 MiB/s | 0.00 MiB/s |

## Network

### primary_vnic

| Metric | Points | Min | Avg | Max | Latest |
| ------ | ------ | --- | --- | --- | ------ |
| VnicFromNetworkBytes (bytes/interval) | 8 | 0.02 MiB | 2015.95 MiB | 7915.54 MiB | 0.03 MiB |
| VnicToNetworkBytes (bytes/interval) | 8 | 0.06 MiB | 908.45 MiB | 3561.05 MiB | 0.06 MiB |
| VnicEgressDropsSecurityList (packets) | 8 | 0.00 | 0.00 | 0.00 | 0.00 |
| VnicIngressDropsSecurityList (packets) | 8 | 0.00 (1.00) | 0.75 | 1.00 | 1.00 |

