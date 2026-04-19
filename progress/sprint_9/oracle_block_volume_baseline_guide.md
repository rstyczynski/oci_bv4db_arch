# Oracle Database on OCI Block Volumes: Sprint 9 Practical Baseline

## Table of Contents

- [Scope](#scope)
- [The Three OCI Layouts That Matter](#the-three-oci-layouts-that-matter)
  - [1. Entry-Level Block Volume](#1-entry-level-block-volume)
  - [2. Single UHP Volume](#2-single-uhp-volume)
  - [3. Multiple Volumes With Storage-Domain Separation](#3-multiple-volumes-with-storage-domain-separation)
- [Sprint 9 Baseline Comparison](#sprint-9-baseline-comparison)
- [What To Use In Practice](#what-to-use-in-practice)
- [OCI References](#oci-references)
- [Oracle References](#oracle-references)

## Scope

This is the current practical Oracle block volume guide for this repository. It replaces older benchmark baselines with the latest validated Oracle-style baseline from Sprint 9.

The guide intentionally limits itself to the three OCI layouts that matter operationally:

1. entry-level block volume
2. single UHP volume
3. multiple volumes with storage-domain separation

The active Oracle comparison point is now the Sprint 9 `4k` redo workload, executed on both:

- one single UHP volume
- a separated-volume Oracle layout

## The Three OCI Layouts That Matter

### 1. Entry-Level Block Volume

This is the functional starting point. It is represented by Sprint 1 and is enough for simple development, proof of concept, and very small non-critical databases.

Practical references:

- baseline analysis: [progress/sprint_1/fio_analysis.md](../sprint_1/fio_analysis.md)
- runner: [tools/run_bv_fio.sh](../../tools/run_bv_fio.sh)

Use it when:

- the database is tiny
- production discipline is not the goal
- the main requirement is simplicity

Do not use it as the main production Oracle pattern.

### 2. Single UHP Volume

This is the one-fast-device option. In the current Oracle baseline, it is represented by the Sprint 9 single-UHP run, which keeps the same Oracle-style guest layout but backs all domains with one UHP volume.

Practical references:

- Sprint 9 single-UHP analysis: [progress/sprint_9/fio-analysis-oracle-single-4k-redo-integration.md](fio-analysis-oracle-single-4k-redo-integration.md)
- fio job: [progress/sprint_9/oracle-layout-4k-redo.fio](oracle-layout-4k-redo.fio)
- runner: [tools/run_bv_fio_oracle_sprint9_single.sh](../../tools/run_bv_fio_oracle_sprint9_single.sh)

Use it when:

- operator simplicity still matters
- the database is relatively small
- one shared contention domain is acceptable

The limit is structural: `DATA`, `REDO`, and `FRA` still converge on one underlying device.

### 3. Multiple Volumes With Storage-Domain Separation

This is the current practical Oracle baseline for this repository. In Sprint 9 it uses:

- striped `DATA`
- separated `REDO`
- separated `FRA`
- `4k` synchronous redo writes

Practical references:

- Sprint 9 multi-volume analysis: [progress/sprint_9/fio-analysis-oracle-multi-4k-redo-integration.md](fio-analysis-oracle-multi-4k-redo-integration.md)
- fio job: [progress/sprint_9/oracle-layout-4k-redo.fio](oracle-layout-4k-redo.fio)
- runner: [tools/run_bv_fio_oracle_sprint9_multi.sh](../../tools/run_bv_fio_oracle_sprint9_multi.sh)

Use it when:

- the system is real production
- `REDO` behavior matters
- RMAN and archive activity matter
- the layout should scale by storage domain

## Sprint 9 Baseline Comparison

The strongest direct comparison in the repository is now Sprint 9 single-UHP versus Sprint 9 multi-volume, because both runs used the same `4k` redo fio profile.

### Single UHP

- `DATA`: about `18606` read IOPS / `145 MB/s` read and `7969` write IOPS / `62 MB/s` write
- `redo`: about `131` write IOPS / `1 MiB/s`
- `fra-1m`: about `120` read IOPS / `120 MB/s` read and `120` write IOPS / `120 MB/s` write

### Multiple volumes

- `DATA`: about `55137` read IOPS / `431 MB/s` read and `23622` write IOPS / `185 MB/s` write
- `redo`: about `791` write IOPS / `3 MiB/s`
- `fra-1m`: about `24` read IOPS / `24 MB/s` read and `23` write IOPS / `23 MB/s` write

Interpretation:

- the single-UHP layout gives FRA much more raw throughput
- but that is paid for by forcing `DATA`, `REDO`, and `FRA` onto the same UHP device
- the separated-volume layout remains much stronger for Oracle behavior because the storage domains stay isolated
- the `REDO` job is synchronous (`iodepth=1`, `fdatasync=1`, `bs=4k`), so redo should be read primarily through synchronous write rate and latency, not through large throughput numbers

This is the current repository baseline.

## What To Use In Practice

Use entry-level block volume when:

- the database is tiny
- the environment is non-critical
- simplicity matters more than production behavior

Use single UHP volume when:

- the database is still relatively small
- a one-device model is preferred
- better performance than entry-level BV is needed
- cross-domain interference is acceptable

Use multiple separated volumes when:

- the database is a real Oracle production system
- you want `DATA`, `REDO`, and `FRA` to remain operationally distinct
- you expect growth
- backup and archive activity must not become the same hot path as foreground data and redo

## OCI References

- <a href="https://docs.oracle.com/iaas/Content/Block/Concepts/blockvolumeelasticperformance.htm" target="_blank" rel="noopener noreferrer">OCI Block Volume Performance</a>
- <a href="https://docs.oracle.com/iaas/Content/Block/Concepts/blockvolumeultrahighperformance.htm" target="_blank" rel="noopener noreferrer">OCI Ultra High Performance Block Volumes</a>
- <a href="https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/configuringmultipathattachments.htm" target="_blank" rel="noopener noreferrer">OCI Configuring Attachments to Ultra High Performance Volumes</a>
- <a href="https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/connectingtouhpvolumes.htm" target="_blank" rel="noopener noreferrer">OCI Working with Multipath-Enabled iSCSI-Attached Volumes</a>
- <a href="https://docs.oracle.com/iaas/Content/Block/Tasks/attachingavolume.htm" target="_blank" rel="noopener noreferrer">OCI Attaching a Block Volume to an Instance</a>
- <a href="https://docs.oracle.com/iaas/Content/Block/Tasks/enablingblockvolumemanagementplugin.htm" target="_blank" rel="noopener noreferrer">OCI Enabling the Block Volume Management Plugin</a>

## Oracle References

- <a href="https://docs.oracle.com/database/121/TGDBA/pfgrf_iodesign.htm" target="_blank" rel="noopener noreferrer">Oracle Database Performance Tuning Guide: I/O Configuration and Design</a>
- <a href="https://docs.oracle.com/html/E25494_01/onlineredo002.htm" target="_blank" rel="noopener noreferrer">Oracle Database Administrator's Guide: Planning the Redo Log</a>
- <a href="https://docs.oracle.com/html/E10642_06/rcmconfb.htm" target="_blank" rel="noopener noreferrer">Oracle Database Backup and Recovery User's Guide: Configuring the RMAN Environment</a>
- <a href="https://docs.oracle.com/en/database/oracle/oracle-database/21/bradv/getting-started-rman.html" target="_blank" rel="noopener noreferrer">Oracle Database Backup and Recovery User's Guide: Getting Started with RMAN</a>
