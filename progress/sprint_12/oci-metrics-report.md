# Sprint 12 OCI Metrics Dashboard

- Start time: `2026-04-19T16:58:57Z`
- End time: `2026-04-19T17:14:27Z`
- Resolution: `1m`

## Table of Contents

- [Blockvolume](#blockvolume)
  - [data1](#data1)
  - [data2](#data2)
  - [redo1](#redo1)
  - [redo2](#redo2)
  - [fra](#fra)
- [Compute](#compute)
  - [compute](#compute)
- [Network](#network)
  - [primary_vnic](#primary_vnic)

## Blockvolume

### data1

| Metric | Points | Min | Avg | Max | Latest |
| ------ | ------ | --- | --- | --- | ------ |
| VolumeReadThroughput (bytes/interval) | 16 | 0.00 MiB (8.27 MiB) | 1292.77 MiB | 3948.11 MiB | 3948.11 MiB |
| VolumeWriteThroughput (bytes/interval) | 16 | 0.00 MiB (448.00 MiB) | 1810.92 MiB | 5626.62 MiB | 1689.99 MiB |
| VolumeReadOps (ops) | 16 | 0.00 (533.00) | 165439.81 | 505352.00 | 505352.00 |
| VolumeWriteOps (ops) | 16 | 0.00 (18427.00) | 76202.75 | 216409.00 | 216320.00 |

### data2

| Metric | Points | Min | Avg | Max | Latest |
| ------ | ------ | --- | --- | --- | ------ |
| VolumeReadThroughput (bytes/interval) | 16 | 0.00 MiB (7.14 MiB) | 1181.98 MiB | 3957.06 MiB | 3937.17 MiB |
| VolumeWriteThroughput (bytes/interval) | 16 | 0.00 MiB (1377.99 MiB) | 1762.60 MiB | 5626.81 MiB | 1685.95 MiB |
| VolumeReadOps (ops) | 16 | 0.00 (234.00) | 151250.81 | 506504.00 | 503960.00 |
| VolumeWriteOps (ops) | 16 | 0.00 (5950.00) | 69847.19 | 217512.00 | 215802.00 |

### redo1

| Metric | Points | Min | Avg | Max | Latest |
| ------ | ------ | --- | --- | --- | ------ |
| VolumeReadThroughput (bytes/interval) | 16 | 0.00 MiB (0.50 MiB) | 0.47 MiB | 6.95 MiB | 0.00 MiB |
| VolumeWriteThroughput (bytes/interval) | 16 | 0.00 MiB (0.07 MiB) | 218.97 MiB | 999.69 MiB | 467.07 MiB |
| VolumeReadOps (ops) | 16 | 0.00 (1.00) | 25.25 | 399.00 | 0.00 |
| VolumeWriteOps (ops) | 16 | 0.00 (1.00) | 24010.31 | 73241.00 | 73241.00 |

### redo2

| Metric | Points | Min | Avg | Max | Latest |
| ------ | ------ | --- | --- | --- | ------ |
| VolumeReadThroughput (bytes/interval) | 16 | 0.00 MiB (7.08 MiB) | 0.44 MiB | 7.08 MiB | 0.00 MiB |
| VolumeWriteThroughput (bytes/interval) | 16 | 0.00 MiB (0.09 MiB) | 224.36 MiB | 783.00 MiB | 468.22 MiB |
| VolumeReadOps (ops) | 16 | 0.00 (249.00) | 15.56 | 249.00 | 0.00 |
| VolumeWriteOps (ops) | 16 | 0.00 (2.00) | 24811.44 | 73426.00 | 73426.00 |

### fra

| Metric | Points | Min | Avg | Max | Latest |
| ------ | ------ | --- | --- | --- | ------ |
| VolumeReadThroughput (bytes/interval) | 16 | 0.00 MiB (0.88 MiB) | 478.64 MiB | 1455.00 MiB | 1448.00 MiB |
| VolumeWriteThroughput (bytes/interval) | 16 | 0.00 MiB (556.12 MiB) | 1620.46 MiB | 2813.19 MiB | 1364.14 MiB |
| VolumeReadOps (ops) | 16 | 0.00 (1.00) | 490.62 | 1455.00 | 1448.00 |
| VolumeWriteOps (ops) | 16 | 0.00 (572.00) | 1648.38 | 2842.00 | 1388.00 |

## Compute

### compute

| Metric | Points | Min | Avg | Max | Latest |
| ------ | ------ | --- | --- | --- | ------ |
| CpuUtilization (percent) | 16 | 0.26% | 2.66% | 6.90% | 4.85% |
| MemoryUtilization (percent) | 16 | 4.00% | 7.00% | 7.46% | 7.16% |
| DiskBytesRead (bytes/s) | 16 | 0.00 MiB/s (0.01 MiB/s) | 54.41 MiB/s | 155.63 MiB/s | 155.63 MiB/s |
| DiskBytesWritten (bytes/s) | 16 | 46.89 MiB/s | 98.03 MiB/s | 219.59 MiB/s | 94.71 MiB/s |

## Network

### primary_vnic

| Metric | Points | Min | Avg | Max | Latest |
| ------ | ------ | --- | --- | --- | ------ |
| VnicFromNetworkBytes (bytes/interval) | 16 | 4.15 MiB | 2984.59 MiB | 9535.85 MiB | 9495.06 MiB |
| VnicToNetworkBytes (bytes/interval) | 16 | 0.73 MiB | 5667.46 MiB | 13104.98 MiB | 5894.56 MiB |
| VnicEgressDropsSecurityList (packets) | 16 | 0.00 | 0.00 | 0.00 | 0.00 |
| VnicIngressDropsSecurityList (packets) | 16 | 0.00 (1.00) | 1.12 | 4.00 | 0.00 |

