# Sprint 22 OCI Metrics Dashboard (bv4db multipath A/B)

- Start time: `2026-04-25T20:57:41Z`
- End time: `2026-04-25T21:09:43Z`
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
| VolumeReadThroughput (bytes/interval) | 11 | 0.00 MiB (597.31 MiB) | 981.99 MiB | 1579.71 MiB | 0.00 MiB |
| VolumeWriteThroughput (bytes/interval) | 11 | 0.00 MiB (0.01 MiB) | 420.67 MiB | 675.65 MiB | 0.01 MiB |
| VolumeReadOps (ops) | 11 | 0.00 (152449.20) | 251235.09 | 404398.00 | 0.00 |
| VolumeWriteOps (ops) | 11 | 0.00 (0.60) | 107659.84 | 172965.60 | 2.00 |

## Compute

### compute

| Metric | Points | Min | Avg | Max | Latest |
| ------ | ------ | --- | --- | --- | ------ |
| CpuUtilization (percent) | 10 | 0.03% | 2.43% | 3.32% | 0.03% |
| MemoryUtilization (percent) | 10 | 2.30% | 3.62% | 4.07% | 2.30% |
| DiskBytesRead (bytes/s) | 11 | -966.00 MiB/s | -8.14 MiB/s | 130.60 MiB/s | 0.00 MiB/s |
| DiskBytesWritten (bytes/s) | 11 | -413.78 MiB/s | -3.46 MiB/s | 55.91 MiB/s | 0.02 MiB/s |

## Network

### primary_vnic

| Metric | Points | Min | Avg | Max | Latest |
| ------ | ------ | --- | --- | --- | ------ |
| VnicFromNetworkBytes (bytes/interval) | 10 | 0.02 MiB | 5945.10 MiB | 8097.96 MiB | 0.02 MiB |
| VnicToNetworkBytes (bytes/interval) | 10 | 0.08 MiB | 2673.72 MiB | 3638.28 MiB | 0.08 MiB |
| VnicEgressDropsSecurityList (packets) | 10 | 0.00 | 0.00 | 0.00 | 0.00 |
| VnicIngressDropsSecurityList (packets) | 11 | 0.00 (1.00) | 0.73 | 2.00 | 2.00 |

