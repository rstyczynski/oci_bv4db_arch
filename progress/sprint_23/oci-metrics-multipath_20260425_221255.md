# Sprint 23 OCI Metrics Dashboard (bv4db multipath A/B with LB policy)

- Start time: `2026-04-25T22:05:19Z`
- End time: `2026-04-25T22:14:51Z`
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
| VolumeReadThroughput (bytes/interval) | 8 | 0.00 MiB (3.33 MiB) | 402.17 MiB | 1607.70 MiB | 0.00 MiB |
| VolumeWriteThroughput (bytes/interval) | 8 | 0.00 MiB (150.50 MiB) | 600.60 MiB | 3424.06 MiB | 0.00 MiB |
| VolumeReadOps (ops) | 8 | 0.00 (160.50) | 102767.36 | 411562.60 | 0.00 |
| VolumeWriteOps (ops) | 8 | 0.00 (0.40) | 45775.60 | 176834.40 | 0.00 |

## Compute

### compute

| Metric | Points | Min | Avg | Max | Latest |
| ------ | ------ | --- | --- | --- | ------ |
| CpuUtilization (percent) | 8 | 0.01% | 2.03% | 4.31% | 0.01% |
| MemoryUtilization (percent) | 8 | 2.09% | 2.85% | 3.79% | 2.33% |
| DiskBytesRead (bytes/s) | 8 | 0.00 MiB/s (0.03 MiB/s) | 34.26 MiB/s | 133.83 MiB/s | 0.00 MiB/s |
| DiskBytesWritten (bytes/s) | 8 | 0.02 MiB/s | 55.43 MiB/s | 285.37 MiB/s | 0.02 MiB/s |

## Network

### primary_vnic

| Metric | Points | Min | Avg | Max | Latest |
| ------ | ------ | --- | --- | --- | ------ |
| VnicFromNetworkBytes (bytes/interval) | 8 | 0.02 MiB | 2158.73 MiB | 8085.80 MiB | 0.02 MiB |
| VnicToNetworkBytes (bytes/interval) | 8 | 0.07 MiB | 3096.64 MiB | 18535.70 MiB | 0.07 MiB |
| VnicEgressDropsSecurityList (packets) | 8 | 0.00 | 0.00 | 0.00 | 0.00 |
| VnicIngressDropsSecurityList (packets) | 8 | 0.00 (1.00) | 1.62 | 3.00 | 3.00 |

