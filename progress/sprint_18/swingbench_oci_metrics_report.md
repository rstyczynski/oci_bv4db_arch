# Sprint 18 Swingbench OCI Metrics

- Start time: `2026-04-23T21:43:45Z`
- End time: `2026-04-23T22:18:01Z`
- Resolution: `1m`

## Table of Contents

- [Blockvolume](#blockvolume)
  - [data1](#data1)
  - [data2](#data2)
  - [redo1](#redo1)
  - [redo2](#redo2)
  - [fra](#fra)
  - [boot_volume](#boot_volume)
- [Compute](#compute)
  - [compute](#compute)
- [Network](#network)
  - [primary_vnic](#primary_vnic)

## Blockvolume

### data1

| Metric | Points | Min | Avg | Max | Latest |
| ------ | ------ | --- | --- | --- | ------ |
| VolumeReadThroughput (bytes/interval) | 35 | 0.00 MiB (0.10 MiB) | 0.00 MiB | 0.10 MiB | 0.00 MiB |
| VolumeWriteThroughput (bytes/interval) | 35 | 0.09 MiB | 129.70 MiB | 272.11 MiB | 185.90 MiB |
| VolumeReadOps (ops) | 35 | 0.00 (0.80) | 0.02 | 0.80 | 0.00 |
| VolumeWriteOps (ops) | 35 | 8.40 | 5266.13 | 9117.25 | 9117.25 |

### data2

| Metric | Points | Min | Avg | Max | Latest |
| ------ | ------ | --- | --- | --- | ------ |
| VolumeReadThroughput (bytes/interval) | 35 | 0.00 MiB (0.05 MiB) | 0.00 MiB | 0.05 MiB | 0.00 MiB |
| VolumeWriteThroughput (bytes/interval) | 35 | 0.23 MiB | 130.44 MiB | 276.48 MiB | 182.34 MiB |
| VolumeReadOps (ops) | 35 | 0.00 (0.40) | 0.01 | 0.40 | 0.00 |
| VolumeWriteOps (ops) | 35 | 20.00 | 5298.71 | 9008.25 | 9008.25 |

### redo1

| Metric | Points | Min | Avg | Max | Latest |
| ------ | ------ | --- | --- | --- | ------ |
| VolumeReadThroughput (bytes/interval) | 35 | 0.00 MiB (0.50 MiB) | 0.01 MiB | 0.50 MiB | 0.00 MiB |
| VolumeWriteThroughput (bytes/interval) | 35 | 86.27 MiB | 234.01 MiB | 468.29 MiB | 217.93 MiB |
| VolumeReadOps (ops) | 35 | 0.00 (4.00) | 0.11 | 4.00 | 0.00 |
| VolumeWriteOps (ops) | 35 | 847.00 | 18128.77 | 21505.00 | 21321.00 |

### redo2

| Metric | Points | Min | Avg | Max | Latest |
| ------ | ------ | --- | --- | --- | ------ |
| VolumeReadThroughput (bytes/interval) | 35 | 0.00 MiB (0.25 MiB) | 0.01 MiB | 0.25 MiB | 0.00 MiB |
| VolumeWriteThroughput (bytes/interval) | 35 | 5.26 MiB | 232.27 MiB | 723.08 MiB | 211.53 MiB |
| VolumeReadOps (ops) | 35 | 0.00 (2.00) | 0.06 | 2.00 | 0.00 |
| VolumeWriteOps (ops) | 35 | 85.00 | 18475.80 | 21617.00 | 19547.00 |

### fra

| Metric | Points | Min | Avg | Max | Latest |
| ------ | ------ | --- | --- | --- | ------ |
| VolumeReadThroughput (bytes/interval) | 35 | 0.00 MiB | 0.00 MiB | 0.00 MiB | 0.00 MiB |
| VolumeWriteThroughput (bytes/interval) | 35 | 0.66 MiB | 1.17 MiB | 2.23 MiB | 1.04 MiB |
| VolumeReadOps (ops) | 35 | 0.00 | 0.00 | 0.00 | 0.00 |
| VolumeWriteOps (ops) | 35 | 55.00 | 87.06 | 154.00 | 77.00 |

### boot_volume

| Metric | Points | Min | Avg | Max | Latest |
| ------ | ------ | --- | --- | --- | ------ |
| VolumeReadThroughput (bytes/interval) | 35 | 0.04 MiB | 0.11 MiB | 0.81 MiB | 0.07 MiB |
| VolumeWriteThroughput (bytes/interval) | 35 | 1.24 MiB | 4.53 MiB | 83.82 MiB | 2.42 MiB |
| VolumeReadOps (ops) | 35 | 10.00 | 24.11 | 84.00 | 18.00 |
| VolumeWriteOps (ops) | 35 | 63.00 | 109.20 | 498.00 | 81.00 |

## Compute

### compute

| Metric | Points | Min | Avg | Max | Latest |
| ------ | ------ | --- | --- | --- | ------ |
| CpuUtilization (percent) | 35 | 1.42% | 6.64% | 11.26% | 6.22% |
| MemoryUtilization (percent) | 35 | 6.02% | 6.62% | 6.94% | 6.49% |
| DiskBytesRead (bytes/s) | 35 | 0.00 MiB/s (0.03 MiB/s) | 0.00 MiB/s | 0.03 MiB/s | 0.00 MiB/s |
| DiskBytesWritten (bytes/s) | 35 | 5.82 MiB/s | 29.57 MiB/s | 68.51 MiB/s | 28.53 MiB/s |

## Network

### primary_vnic

| Metric | Points | Min | Avg | Max | Latest |
| ------ | ------ | --- | --- | --- | ------ |
| VnicFromNetworkBytes (bytes/interval) | 35 | 2.42 MiB | 19.62 MiB | 52.66 MiB | 22.46 MiB |
| VnicToNetworkBytes (bytes/interval) | 35 | 408.94 MiB | 1774.58 MiB | 3252.34 MiB | 1904.79 MiB |
| VnicEgressDropsSecurityList (packets) | 35 | 0.00 | 0.00 | 0.00 | 0.00 |
| VnicIngressDropsSecurityList (packets) | 35 | 274.00 | 280.23 | 288.00 | 281.00 |

