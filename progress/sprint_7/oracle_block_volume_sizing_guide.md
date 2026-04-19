# Oracle Database on OCI Block Volumes: Practical Layout Guide

## Table of Contents

- [Introduction](#introduction)
- [Three Practical Layouts](#three-practical-layouts)
  - [1. Entry-Level Block Volume](#1-entry-level-block-volume)
  - [2. Single UHP Volume](#2-single-uhp-volume)
  - [3. Multiple Volumes With Storage-Domain Separation](#3-multiple-volumes-with-storage-domain-separation)
- [Measured Comparison](#measured-comparison)
- [What To Choose](#what-to-choose)
- [RMAN and FRA During Production](#rman-and-fra-during-production)
- [FIO Testing Model Used By This Project](#fio-testing-model-used-by-this-project)
- [Official OCI References](#official-oci-references)
- [Official Oracle References](#official-oracle-references)

## Introduction

This document is the practical outcome of the work completed so far in this project. It intentionally reduces the discussion to the three OCI block volume layouts that were actually tested and are useful for Oracle Database decisions:

1. entry-level block volume
2. single UHP volume
3. multiple volumes with Oracle-style storage-domain separation

Everything else is secondary. The key project question is simple: when is one volume enough, when is one high-performance volume enough, and when do separate Oracle storage domains become worth it?

Oracle storage still needs to be read through the three familiar domains:

- `DATA`
- `REDO`
- `FRA`

Oracle directly supports separating redo from datafiles to reduce contention and recommends placing multiplexed redo members on different disks:
<a href="https://docs.oracle.com/html/E25494_01/onlineredo002.htm" target="_blank" rel="noopener noreferrer">Planning the Redo Log</a>.

Oracle also recommends placing the recovery area on a separate disk from the active database area:
<a href="https://docs.oracle.com/html/E10642_06/rcmconfb.htm" target="_blank" rel="noopener noreferrer">Configuring the RMAN Environment</a>.

Because this project is specifically about OCI, the storage conclusions here also depend on OCI block volume behavior such as VPU-based performance levels, UHP multipath requirements, and instance-side block volume limits. Those OCI-specific references are listed at the end of this document.

## Three Practical Layouts

### 1. Entry-Level Block Volume

This is the smallest practical starting point. It is represented by Sprint 1: a basic block volume attached to compute, with simple fio validation and no Oracle-style storage separation.

Practical reference:

- analysis: [progress/sprint_1/fio_analysis.md](../sprint_1/fio_analysis.md)
- runner: [tools/run_bv_fio.sh](../../tools/run_bv_fio.sh)

What it is good for:

- lab environments
- development and proof of concept
- very small non-critical databases
- first functional validation of compute plus block volume

What it is not good for:

- predictable Oracle production behavior
- isolation between `DATA`, `REDO`, and `FRA`
- meaningful scaling

Measured project conclusion:

- it works
- it is enough to start
- it is not a strong performance layout

This remains consistent with Oracle's broader I/O design guidance, which allows simpler volume layouts when manageability matters more than full isolation:
<a href="https://docs.oracle.com/database/121/TGDBA/pfgrf_iodesign.htm" target="_blank" rel="noopener noreferrer">I/O Configuration and Design</a>.

On the OCI side, this layout corresponds to the lower operational end of the Block Volume performance model:
<a href="https://docs.oracle.com/iaas/Content/Block/Concepts/blockvolumeelasticperformance.htm" target="_blank" rel="noopener noreferrer">Block Volume Performance</a>.

### 2. Single UHP Volume

This is the “one fast disk” option. In the Oracle-specific project comparison, it is represented by Sprint 8: the same Oracle-style fio job and the same guest-visible filesystem/LVM layout as Sprint 5, but all backed by one single UHP volume.

Practical references:

- Sprint 8 analysis: [progress/sprint_8/fio-analysis-oracle-integration.md](../sprint_8/fio-analysis-oracle-integration.md)
- fio job reused for the Oracle-style single-UHP comparison: [progress/sprint_5/oracle-layout.fio](../sprint_5/oracle-layout.fio)
- Oracle-layout single-UHP execution: [tools/run_bv_fio_oracle.sh](../../tools/run_bv_fio_oracle.sh)

What it is good for:

- small to lower-mid production systems
- cases where operator simplicity matters
- environments that need more ceiling than a generic entry-level volume
- cases where one device is acceptable but the device should be fast

What it is not good for:

- true storage-domain isolation
- keeping `DATA`, `REDO`, and `FRA` from competing with each other under load
- scaling by domain

Measured project conclusion:

- a single UHP volume is much better than an entry-level generic volume
- it can sustain mixed Oracle-style load
- but once all domains are active together, the single device becomes the contention point

The strongest evidence is Sprint 8: the guest kept the same visible layout as the separated Oracle model, but because everything sat on one underlying UHP volume, `DATA` and `REDO` performance dropped materially versus the multi-volume design.

For OCI, this is the layout where UHP-specific documentation matters most:

- UHP performance characteristics:
  <a href="https://docs.oracle.com/iaas/Content/Block/Concepts/blockvolumeultrahighperformance.htm" target="_blank" rel="noopener noreferrer">Ultra High Performance</a>
- multipath-enabled UHP attachments:
  <a href="https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/configuringmultipathattachments.htm" target="_blank" rel="noopener noreferrer">Configuring Attachments to Ultra High Performance Volumes</a>
- working with multipath-enabled iSCSI volumes:
  <a href="https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/connectingtouhpvolumes.htm" target="_blank" rel="noopener noreferrer">Working with Multipath-Enabled iSCSI-Attached Volumes</a>

### 3. Multiple Volumes With Storage-Domain Separation

This is the practical Oracle layout. The validated project version is Sprint 5:

- striped `DATA`
- separate `REDO`
- separate `FRA`
- valid per-job fio reporting

Practical references:

- analysis: [progress/sprint_5/fio-analysis-oracle-integration.md](../sprint_5/fio-analysis-oracle-integration.md)
- fio job: [progress/sprint_5/oracle-layout.fio](../sprint_5/oracle-layout.fio)
- runner: [tools/run_bv_fio_oracle_sprint5.sh](../../tools/run_bv_fio_oracle_sprint5.sh)

What it is good for:

- serious production systems
- systems with daytime backup and archive activity
- systems where commit-path stability matters
- systems expected to grow in different ways across `DATA`, `REDO`, and `FRA`

What it is not:

- the simplest layout
- the cheapest layout
- necessarily the final top-end architecture for every Oracle system

Measured project conclusion:

- this is the first layout in the project that behaves like an Oracle storage architecture rather than a single-disk benchmark
- it preserves domain separation under concurrent load
- it gives the clearest path for scaling and troubleshooting

For OCI, this layout also depends on instance-side block volume limits and attachment behavior, not just volume sizing:
<a href="https://docs.oracle.com/iaas/Content/Block/Concepts/blockvolumeelasticperformance.htm" target="_blank" rel="noopener noreferrer">Block Volume Performance</a>,
<a href="https://docs.oracle.com/iaas/Content/Block/Tasks/attachingavolume.htm" target="_blank" rel="noopener noreferrer">Attaching a Block Volume to an Instance</a>.

## Measured Comparison

The project now supports a direct three-step reading.

### Entry-Level Block Volume

- baseline only
- valid for simple environments
- weakest performance profile
- no domain isolation

### Single UHP Volume

- stronger single-device performance
- simple operational model
- still one contention domain underneath
- better than entry-level, but not a replacement for storage separation

### Multiple Volumes With Storage-Domain Separation

- strongest Oracle-style result
- `DATA`, `REDO`, and `FRA` remain independently visible
- best operational clarity
- best foundation for growth by domain

### Direct Sprint 5 vs Sprint 8 comparison

This is the most useful comparison in the repository because the fio job, compute shape, filesystem layout, and LVM structure were kept the same. Only the underlying block volume topology changed.

Sprint 5, separated volumes:

- `data-8k` worker: about `12730` read IOPS / `99 MB/s` read and `5454` write IOPS / `43 MB/s` write per worker
- `redo`: about `1532` write IOPS / `0.75 MiB/s`
- `fra-1m`: about `24` read IOPS / `24 MB/s` read and `23` write IOPS / `23 MB/s` write on the balanced FRA volume

Sprint 8, single UHP volume:

- `data-8k` worker: about `4770` read IOPS / `37 MB/s` read and `2044` write IOPS / `16 MB/s` write per worker
- `redo`: about `292` write IOPS / `0.14 MiB/s`
- `fra-1m`: about `120` read IOPS / `120 MB/s` read and `120` write IOPS / `120 MB/s` write

Interpretation:

- Sprint 8 lets FRA run much faster because FRA moved from a balanced volume to a UHP-backed partition
- but that gain is paid for by sharing the same UHP device with `DATA` and `REDO`
- Sprint 5 keeps FRA slower, but it protects `DATA` and `REDO` from FRA traffic

That is the central lesson of the project so far.

## What To Choose

Use entry-level block volume when:

- the database is tiny
- the environment is non-critical
- simplicity is more important than tuning discipline

Use a single UHP volume when:

- the database is still relatively small
- more headroom is needed than the entry-level layout can provide
- operator simplicity is still a strong requirement
- some cross-domain interference is acceptable

Use multiple volumes with storage-domain separation when:

- the database is real production
- RMAN and archive activity can run during active hours
- commit-path behavior matters
- the system is expected to scale
- you want a layout that behaves like Oracle rather than like one fast shared disk

## RMAN and FRA During Production

Running RMAN backup while the database is open is normal Oracle practice:
<a href="https://docs.oracle.com/en/database/oracle/oracle-database/21/bradv/getting-started-rman.html" target="_blank" rel="noopener noreferrer">Getting Started with RMAN</a>.

The practical storage question is where the backup traffic goes.

- entry-level block volume: backup traffic competes with everything else immediately
- single UHP volume: backup traffic has more raw capacity available, but still shares one contention domain
- multiple separated volumes: `FRA` can absorb backup and archive activity without directly becoming the same device as `DATA` and `REDO`

Oracle also documents that archived redo logs can be directed into the Fast Recovery Area:
<a href="https://docs.oracle.com/en/database/oracle/oracle-database/23/admin/managing-archived-redo-log-files.html" target="_blank" rel="noopener noreferrer">Managing Archived Redo Log Files</a>.

That is why `FRA` matters even when the conversation starts as “just storage for backups”.

## FIO Testing Model Used By This Project

The project used three practical fio model families that map directly to the three layouts above.

### Entry-level baseline

- analysis: [progress/sprint_1/fio_analysis.md](../sprint_1/fio_analysis.md)
- runner: [tools/run_bv_fio.sh](../../tools/run_bv_fio.sh)

### Single-volume performance

- analysis: [progress/sprint_2/fio_analysis.md](../sprint_2/fio_analysis.md)
- runner: [tools/run_bv_fio_perf.sh](../../tools/run_bv_fio_perf.sh)

### Oracle-style concurrent workload

- separated-volume result: [progress/sprint_5/fio-analysis-oracle-integration.md](../sprint_5/fio-analysis-oracle-integration.md)
- single-UHP result: [progress/sprint_8/fio-analysis-oracle-integration.md](../sprint_8/fio-analysis-oracle-integration.md)
- fio job: [progress/sprint_5/oracle-layout.fio](../sprint_5/oracle-layout.fio)

This is enough to support the current practical recommendation set. More benchmark variety is possible, but it is not required to explain the main storage decision.

## Official OCI References

- <a href="https://docs.oracle.com/iaas/Content/Block/Concepts/blockvolumeelasticperformance.htm" target="_blank" rel="noopener noreferrer">OCI Block Volume Performance</a>
- <a href="https://docs.oracle.com/iaas/Content/Block/Concepts/blockvolumeultrahighperformance.htm" target="_blank" rel="noopener noreferrer">OCI Ultra High Performance Block Volumes</a>
- <a href="https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/configuringmultipathattachments.htm" target="_blank" rel="noopener noreferrer">OCI Configuring Attachments to Ultra High Performance Volumes</a>
- <a href="https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/connectingtouhpvolumes.htm" target="_blank" rel="noopener noreferrer">OCI Working with Multipath-Enabled iSCSI-Attached Volumes</a>
- <a href="https://docs.oracle.com/iaas/Content/Block/Tasks/attachingavolume.htm" target="_blank" rel="noopener noreferrer">OCI Attaching a Block Volume to an Instance</a>
- <a href="https://docs.oracle.com/iaas/Content/Block/Tasks/connectingtoavolume.htm" target="_blank" rel="noopener noreferrer">OCI Connecting to a Block Volume</a>
- <a href="https://docs.oracle.com/iaas/Content/Block/Tasks/enablingblockvolumemanagementplugin.htm" target="_blank" rel="noopener noreferrer">OCI Enabling the Block Volume Management Plugin</a>
- <a href="https://docs.oracle.com/iaas/Content/Block/Tasks/changingvolumeperformance.htm" target="_blank" rel="noopener noreferrer">OCI Changing the Performance of a Volume</a>
- <a href="https://docs.oracle.com/iaas/Content/Block/Tasks/autotunevolumeperformance.htm" target="_blank" rel="noopener noreferrer">OCI Dynamic Performance Scaling</a>

## Official Oracle References

- <a href="https://docs.oracle.com/database/121/TGDBA/pfgrf_iodesign.htm" target="_blank" rel="noopener noreferrer">Oracle Database Performance Tuning Guide: I/O Configuration and Design</a>
- <a href="https://docs.oracle.com/html/E25494_01/onlineredo002.htm" target="_blank" rel="noopener noreferrer">Oracle Database Administrator's Guide: Planning the Redo Log</a>
- <a href="https://docs.oracle.com/en/database/oracle/oracle-database/23/admin/managing-the-redo-log.html" target="_blank" rel="noopener noreferrer">Oracle Database: Managing the Redo Log</a>
- <a href="https://docs.oracle.com/html/E10642_06/rcmconfb.htm" target="_blank" rel="noopener noreferrer">Oracle Database Backup and Recovery User's Guide: Configuring the RMAN Environment</a>
- <a href="https://docs.oracle.com/en/database/oracle/oracle-database/21/bradv/getting-started-rman.html" target="_blank" rel="noopener noreferrer">Oracle Database Backup and Recovery User's Guide: Getting Started with RMAN</a>
- <a href="https://docs.oracle.com/en/database/oracle/oracle-database/23/admin/managing-archived-redo-log-files.html" target="_blank" rel="noopener noreferrer">Oracle Database: Managing Archived Redo Log Files</a>
