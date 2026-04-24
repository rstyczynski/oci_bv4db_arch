# Sprint 18 FIO OCI Metrics

- Start time: `2026-04-23T20:22:58Z`
- End time: `2026-04-23T20:40:28Z`
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
| VolumeReadThroughput (bytes/interval) | 18 | 0.00 MiB (1220.32 MiB) | 2297.65 MiB | 2665.71 MiB | 2348.90 MiB |
| VolumeWriteThroughput (bytes/interval) | 18 | 0.00 MiB (525.02 MiB) | 984.58 MiB | 1140.54 MiB | 1007.78 MiB |
| VolumeReadOps (ops) | 18 | 0.00 (156187.80) | 294022.97 | 341203.20 | 300593.60 |
| VolumeWriteOps (ops) | 18 | 0.00 (67203.80) | 126010.32 | 145985.80 | 128976.80 |

### data2

| Metric | Points | Min | Avg | Max | Latest |
| ------ | ------ | --- | --- | --- | ------ |
| VolumeReadThroughput (bytes/interval) | 18 | 0.00 MiB (813.87 MiB) | 2309.74 MiB | 2976.90 MiB | 2976.90 MiB |
| VolumeWriteThroughput (bytes/interval) | 18 | 0.00 MiB (350.00 MiB) | 989.20 MiB | 1275.77 MiB | 1275.77 MiB |
| VolumeReadOps (ops) | 18 | 0.00 (104168.80) | 295608.76 | 381031.50 | 381031.50 |
| VolumeWriteOps (ops) | 18 | 0.00 (44799.80) | 126609.48 | 163295.50 | 163295.50 |

### redo1

| Metric | Points | Min | Avg | Max | Latest |
| ------ | ------ | --- | --- | --- | ------ |
| VolumeReadThroughput (bytes/interval) | 18 | 0.00 MiB (0.50 MiB) | 0.03 MiB | 0.50 MiB | 0.00 MiB |
| VolumeWriteThroughput (bytes/interval) | 18 | 0.00 MiB (35.55 MiB) | 433.13 MiB | 536.19 MiB | 475.07 MiB |
| VolumeReadOps (ops) | 18 | 0.00 (4.00) | 0.22 | 4.00 | 0.00 |
| VolumeWriteOps (ops) | 18 | 0.00 (5467.00) | 74463.22 | 95926.00 | 80558.00 |

### redo2

| Metric | Points | Min | Avg | Max | Latest |
| ------ | ------ | --- | --- | --- | ------ |
| VolumeReadThroughput (bytes/interval) | 17 | 0.00 MiB (0.25 MiB) | 0.01 MiB | 0.25 MiB | 0.00 MiB |
| VolumeWriteThroughput (bytes/interval) | 17 | 0.00 MiB (321.80 MiB) | 450.46 MiB | 531.15 MiB | 481.75 MiB |
| VolumeReadOps (ops) | 17 | 0.00 (2.00) | 0.12 | 2.00 | 0.00 |
| VolumeWriteOps (ops) | 17 | 0.00 (50216.00) | 77480.18 | 94665.00 | 82207.00 |

### fra

| Metric | Points | Min | Avg | Max | Latest |
| ------ | ------ | --- | --- | --- | ------ |
| VolumeReadThroughput (bytes/interval) | 18 | 0.00 MiB (1120.00 MiB) | 1091.94 MiB | 1475.00 MiB | 1402.00 MiB |
| VolumeWriteThroughput (bytes/interval) | 18 | 1338.14 MiB | 1715.82 MiB | 2813.19 MiB | 1411.14 MiB |
| VolumeReadOps (ops) | 18 | 0.00 (1120.00) | 1091.94 | 1475.00 | 1402.00 |
| VolumeWriteOps (ops) | 18 | 1362.00 | 1740.06 | 2846.00 | 1435.00 |

## Compute

### compute

| Metric | Points | Min | Avg | Max | Latest |
| ------ | ------ | --- | --- | --- | ------ |
| CpuUtilization (percent) | 18 | 0.45% | 7.90% | 10.21% | 6.95% |
| MemoryUtilization (percent) | 18 | 4.28% | 5.82% | 6.01% | 5.84% |
| DiskBytesRead (bytes/s) | 18 | 0.03 MiB/s | 407.48 MiB/s | 469.75 MiB/s | 405.49 MiB/s |
| DiskBytesWritten (bytes/s) | 18 | 47.07 MiB/s | 209.50 MiB/s | 232.84 MiB/s | 202.77 MiB/s |

## Network

### primary_vnic

| Metric | Points | Min | Avg | Max | Latest |
| ------ | ------ | --- | --- | --- | ------ |
| VnicFromNetworkBytes (bytes/interval) | 18 | 4.55 MiB | 24131.07 MiB | 28199.42 MiB | 26039.50 MiB |
| VnicToNetworkBytes (bytes/interval) | 18 | 2832.26 MiB | 12717.21 MiB | 14452.10 MiB | 13207.03 MiB |
| VnicEgressDropsSecurityList (packets) | 18 | 0.00 | 0.00 | 0.00 | 0.00 |
| VnicIngressDropsSecurityList (packets) | 18 | 275.00 | 280.78 | 287.00 | 285.00 |

