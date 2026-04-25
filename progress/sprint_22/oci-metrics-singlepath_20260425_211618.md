# Sprint 22 OCI Metrics Dashboard (bv4db multipath A/B)

- Start time: `2026-04-25T21:06:12Z`
- End time: `2026-04-25T21:18:13Z`
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
| VolumeReadThroughput (bytes/interval) | 10 | 0.00 MiB (2840.46 MiB) | 4273.77 MiB | 8721.50 MiB | 0.00 MiB |
| VolumeWriteThroughput (bytes/interval) | 10 | 0.00 MiB (0.02 MiB) | 1831.18 MiB | 3737.89 MiB | 0.00 MiB |
| VolumeReadOps (ops) | 10 | 0.00 (727008.00) | 1093821.40 | 2232591.00 | 0.00 |
| VolumeWriteOps (ops) | 10 | 0.00 (0.40) | 468671.20 | 956887.00 | 0.00 |

## Compute

### compute

| Metric | Points | Min | Avg | Max | Latest |
| ------ | ------ | --- | --- | --- | ------ |
| CpuUtilization (percent) | 10 | 0.03% | 1.62% | 3.32% | 0.03% |
| MemoryUtilization (percent) | 10 | 2.28% | 3.15% | 4.02% | 2.28% |
| DiskBytesRead (bytes/s) | 10 | -548.40 MiB/s | 6.73 MiB/s | 145.33 MiB/s | 0.00 MiB/s |
| DiskBytesWritten (bytes/s) | 10 | -234.75 MiB/s | 2.91 MiB/s | 62.31 MiB/s | 0.01 MiB/s |

## Network

### primary_vnic

| Metric | Points | Min | Avg | Max | Latest |
| ------ | ------ | --- | --- | --- | ------ |
| VnicFromNetworkBytes (bytes/interval) | 10 | 0.02 MiB | 4411.23 MiB | 9253.94 MiB | 0.02 MiB |
| VnicToNetworkBytes (bytes/interval) | 10 | 0.06 MiB | 1984.33 MiB | 4164.13 MiB | 0.06 MiB |
| VnicEgressDropsSecurityList (packets) | 10 | 0.00 | 0.00 | 0.00 | 0.00 |
| VnicIngressDropsSecurityList (packets) | 10 | 0.00 (1.00) | 1.10 | 3.00 | 0.00 |

