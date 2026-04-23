# Sprint 17 FIO OCI Metrics

- Start time: `2026-04-23T16:05:39Z`
- End time: `2026-04-23T16:14:55Z`
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
| VolumeReadThroughput (bytes/interval) | 9 | 0.00 MiB (1.84 MiB) | 224.49 MiB | 2018.60 MiB | 2018.60 MiB |
| VolumeWriteThroughput (bytes/interval) | 9 | 0.00 MiB (71.23 MiB) | 543.20 MiB | 3392.08 MiB | 867.77 MiB |
| VolumeReadOps (ops) | 9 | 0.00 (126.00) | 28722.91 | 258380.20 | 258380.20 |
| VolumeWriteOps (ops) | 9 | 0.00 (361.40) | 13101.44 | 111074.60 | 111074.60 |

### data2

| Metric | Points | Min | Avg | Max | Latest |
| ------ | ------ | --- | --- | --- | ------ |
| VolumeReadThroughput (bytes/interval) | 9 | 0.00 MiB (1.57 MiB) | 117.95 MiB | 1060.00 MiB | 1060.00 MiB |
| VolumeWriteThroughput (bytes/interval) | 9 | 0.00 MiB (70.01 MiB) | 497.28 MiB | 2111.01 MiB | 455.65 MiB |
| VolumeReadOps (ops) | 9 | 0.00 (56.60) | 15081.64 | 135678.20 | 135678.20 |
| VolumeWriteOps (ops) | 9 | 0.00 (281.20) | 7163.44 | 58323.40 | 58323.40 |

### redo1

| Metric | Points | Min | Avg | Max | Latest |
| ------ | ------ | --- | --- | --- | ------ |
| VolumeReadThroughput (bytes/interval) | 9 | 0.00 MiB (8.67 MiB) | 0.96 MiB | 8.67 MiB | 0.00 MiB |
| VolumeWriteThroughput (bytes/interval) | 9 | 0.00 MiB (46.26 MiB) | 168.18 MiB | 559.58 MiB | 407.37 MiB |
| VolumeReadOps (ops) | 9 | 0.00 (1.00) | 47.67 | 428.00 | 0.00 |
| VolumeWriteOps (ops) | 9 | 0.00 (1251.00) | 8422.67 | 63451.00 | 63451.00 |

### redo2

| Metric | Points | Min | Avg | Max | Latest |
| ------ | ------ | --- | --- | --- | ------ |
| VolumeReadThroughput (bytes/interval) | 9 | 0.00 MiB (7.88 MiB) | 0.88 MiB | 7.88 MiB | 0.00 MiB |
| VolumeWriteThroughput (bytes/interval) | 9 | 0.00 MiB (144.08 MiB) | 137.88 MiB | 564.47 MiB | 182.23 MiB |
| VolumeReadOps (ops) | 9 | 0.00 (246.00) | 27.33 | 246.00 | 0.00 |
| VolumeWriteOps (ops) | 9 | 0.00 (588.00) | 3644.00 | 28573.00 | 28573.00 |

### fra

| Metric | Points | Min | Avg | Max | Latest |
| ------ | ------ | --- | --- | --- | ------ |
| VolumeReadThroughput (bytes/interval) | 9 | 0.00 MiB (4.30 MiB) | 186.26 MiB | 1423.00 MiB | 1423.00 MiB |
| VolumeWriteThroughput (bytes/interval) | 9 | 1052.22 MiB | 2235.20 MiB | 2813.24 MiB | 1390.14 MiB |
| VolumeReadOps (ops) | 9 | 0.00 (1.00) | 212.78 | 1423.00 | 1423.00 |
| VolumeWriteOps (ops) | 9 | 1110.00 | 2271.22 | 2840.00 | 1415.00 |

## Compute

### compute

| Metric | Points | Min | Avg | Max | Latest |
| ------ | ------ | --- | --- | --- | ------ |
| CpuUtilization (percent) | 9 | 0.14% | 1.46% | 5.98% | 5.98% |
| MemoryUtilization (percent) | 9 | 3.07% | 4.13% | 4.29% | 4.18% |
| DiskBytesRead (bytes/s) | 9 | 0.00 MiB/s (0.13 MiB/s) | 57.61 MiB/s | 431.46 MiB/s | 431.46 MiB/s |
| DiskBytesWritten (bytes/s) | 9 | 46.90 MiB/s | 141.90 MiB/s | 445.36 MiB/s | 214.10 MiB/s |

## Network

### primary_vnic

| Metric | Points | Min | Avg | Max | Latest |
| ------ | ------ | --- | --- | --- | ------ |
| VnicFromNetworkBytes (bytes/interval) | 9 | 4.51 MiB | 1310.08 MiB | 11257.04 MiB | 11257.04 MiB |
| VnicToNetworkBytes (bytes/interval) | 9 | 0.71 MiB | 7454.38 MiB | 22119.71 MiB | 7154.75 MiB |
| VnicEgressDropsSecurityList (packets) | 9 | 0.00 | 0.00 | 0.00 | 0.00 |
| VnicIngressDropsSecurityList (packets) | 9 | 26.00 | 43.89 | 55.00 | 47.00 |

