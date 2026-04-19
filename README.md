# OCI Block Volume for Oracle Database Architecture

Practical OCI block volume guidance for Oracle Database, backed by executed sprint results in this repository.

This repository now focuses on one practical baseline:

1. entry-level block volume
2. single UHP volume
3. multiple volumes with Oracle-style storage-domain separation

## Table of Contents

- [What This Repository Proves](#what-this-repository-proves)
- [The Three Layouts](#the-three-layouts)
  - [1. Entry-Level Block Volume](#1-entry-level-block-volume)
  - [2. Single UHP Volume](#2-single-uhp-volume)
  - [3. Multiple Volumes With Storage-Domain Separation](#3-multiple-volumes-with-storage-domain-separation)
- [Direct Comparison](#direct-comparison)
- [What To Use In Practice](#what-to-use-in-practice)
- [RMAN and FRA During Production](#rman-and-fra-during-production)
- [Relevant Project Artifacts](#relevant-project-artifacts)
- [Official OCI References](#official-oci-references)
- [Official Oracle References](#official-oracle-references)

## What This Repository Proves

The project has already executed enough work to support a simple practical conclusion:

- one ordinary block volume is enough to start
- one UHP volume is enough to go faster, but it is still one shared contention domain
- multiple volumes mapped to Oracle storage domains are the strongest practical layout for real production behavior

The active Oracle baseline in this repository is now Sprint 9, which uses the `4k` redo profile on both:

- single UHP topology
- separated-volume topology

The Oracle domains that matter are still:

- `DATA`
- `REDO`
- `FRA`

Oracle directly supports separating redo from datafiles to reduce contention:
<a href="https://docs.oracle.com/html/E25494_01/onlineredo002.htm" target="_blank" rel="noopener noreferrer">Planning the Redo Log</a>.

Oracle also recommends placing the Fast Recovery Area on separate storage from the active database area:
<a href="https://docs.oracle.com/html/E10642_06/rcmconfb.htm" target="_blank" rel="noopener noreferrer">Configuring the RMAN Environment</a>.

Because this repository is specifically about OCI, the practical conclusions also depend on OCI block volume performance levels, UHP attachment behavior, multipath, and instance-side block volume limits.

## The Three Layouts

### 1. Entry-Level Block Volume

This is the Sprint 1 baseline. It is a simple attached block volume with basic fio validation.

Use it for:

- labs
- development
- proof of concept
- very small non-critical databases

Do not treat it as a strong Oracle production layout.

Practical references:

- analysis: [progress/sprint_1/fio_analysis.md](progress/sprint_1/fio_analysis.md)
- runner: [tools/run_bv_fio.sh](tools/run_bv_fio.sh)

Relevant OCI reference:

- <a href="https://docs.oracle.com/iaas/Content/Block/Concepts/blockvolumeelasticperformance.htm" target="_blank" rel="noopener noreferrer">OCI Block Volume Performance</a>

### 2. Single UHP Volume

This is the “one fast disk” choice. In the current Oracle baseline in this repository, it is represented by Sprint 9 single-UHP: the same Oracle-style guest-visible layout, but all backed by one single UHP volume.

Use it for:

- smaller production systems
- environments where simplicity matters
- cases where more ceiling is needed than the entry-level layout can provide

Its limit is simple: all Oracle activity still converges on one device.

Practical references:

- Sprint 9 single-UHP analysis: [progress/sprint_9/fio-analysis-oracle-single-4k-redo-integration.md](progress/sprint_9/fio-analysis-oracle-single-4k-redo-integration.md)
- fio job reused for the current Oracle baseline: [progress/sprint_9/oracle-layout-4k-redo.fio](progress/sprint_9/oracle-layout-4k-redo.fio)

Current measured result on the Sprint 9 single-UHP baseline:

- `DATA`: about `18606` read IOPS / `145 MB/s` read and `7969` write IOPS / `62 MB/s` write
- `REDO`: about `131` write IOPS / `1 MiB/s`
- `FRA`: about `120 MB/s` read and `120 MB/s` write

Relevant OCI references:

- <a href="https://docs.oracle.com/iaas/Content/Block/Concepts/blockvolumeultrahighperformance.htm" target="_blank" rel="noopener noreferrer">OCI Ultra High Performance Block Volumes</a>
- <a href="https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/configuringmultipathattachments.htm" target="_blank" rel="noopener noreferrer">OCI Configuring Attachments to Ultra High Performance Volumes</a>
- <a href="https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/connectingtouhpvolumes.htm" target="_blank" rel="noopener noreferrer">OCI Working with Multipath-Enabled iSCSI-Attached Volumes</a>
- <a href="https://docs.oracle.com/iaas/Content/Block/Tasks/enablingblockvolumemanagementplugin.htm" target="_blank" rel="noopener noreferrer">OCI Enabling the Block Volume Management Plugin</a>

### 3. Multiple Volumes With Storage-Domain Separation

This is the practical Oracle layout used by the current repository baseline:

- separated `DATA`
- separated `REDO`
- separated `FRA`
- valid per-job fio reporting under concurrent load
- `4k` synchronous redo writes in Sprint 9

Use it for:

- real production systems
- systems with active backup and archive traffic
- systems where commit-path stability matters
- systems expected to scale

Practical references:

- analysis: [progress/sprint_9/fio-analysis-oracle-multi-4k-redo-integration.md](progress/sprint_9/fio-analysis-oracle-multi-4k-redo-integration.md)
- fio job: [progress/sprint_9/oracle-layout-4k-redo.fio](progress/sprint_9/oracle-layout-4k-redo.fio)
- runner: [tools/run_bv_fio_oracle_sprint9_multi.sh](tools/run_bv_fio_oracle_sprint9_multi.sh)

Current measured result on the Sprint 9 multi-volume baseline:

- `DATA`: about `55137` read IOPS / `431 MB/s` read and `23622` write IOPS / `185 MB/s` write
- `REDO`: about `791` write IOPS / `3 MiB/s`
- `FRA`: about `24 MB/s` read and `23 MB/s` write

Relevant OCI references:

- <a href="https://docs.oracle.com/iaas/Content/Block/Concepts/blockvolumeelasticperformance.htm" target="_blank" rel="noopener noreferrer">OCI Block Volume Performance</a>
- <a href="https://docs.oracle.com/iaas/Content/Block/Tasks/attachingavolume.htm" target="_blank" rel="noopener noreferrer">OCI Attaching a Block Volume to an Instance</a>
- <a href="https://docs.oracle.com/iaas/Content/Block/Tasks/connectingtoavolume.htm" target="_blank" rel="noopener noreferrer">OCI Connecting to a Block Volume</a>

## Direct Comparison

The most important comparison in the repository is now Sprint 9 single-UHP versus Sprint 9 multi-volume.

Those two runs kept the same:

- compute shape
- fio job
- filesystem layout
- LVM layout

Only one thing changed:

- Sprint 9 multi-volume used multiple volumes with Oracle-style separation
- Sprint 9 single-UHP used one single UHP volume underneath the same guest-visible layout

Measured result:

| Domain | Single UHP | Multi-volume |
| ------ | ---------- | ------------ |
| `DATA` | `18606` read IOPS / `145 MB/s` read; `7969` write IOPS / `62 MB/s` write | `55137` read IOPS / `431 MB/s` read; `23622` write IOPS / `185 MB/s` write |
| `REDO` | `131` write IOPS / `1 MiB/s` | `791` write IOPS / `3 MiB/s` |
| `FRA` | `120` read IOPS / `120 MB/s` read; `120` write IOPS / `120 MB/s` write | `24` read IOPS / `24 MB/s` read; `23` write IOPS / `23 MB/s` write |

Interpretation:

- the single UHP volume lets FRA run much faster in raw throughput terms
- but that happens because FRA is consuming the same underlying UHP device that must also serve `DATA` and `REDO`
- the separated-volume topology remains much stronger for Oracle behavior because the storage domains stay isolated
- the `REDO` job is intentionally synchronous (`iodepth=1` with `fdatasync=1` and `4k` writes), so the meaningful redo comparison is synchronous write rate and latency behavior, not throughput headlines

That is the central result of this repository.

## What To Use In Practice

Use entry-level block volume when:

- the database is tiny
- the system is non-critical
- simplicity matters more than production discipline

Use single UHP volume when:

- the database is still fairly small
- more headroom is needed than a basic entry-level volume can provide
- one shared contention domain is acceptable

Use multiple separated volumes when:

- the database is a real production system
- RMAN and archive activity matter
- commit-path behavior matters
- growth is expected

In short:

- entry-level BV for starting
- single UHP for one fast simple volume
- multiple volumes for Oracle production behavior

## RMAN and FRA During Production

Oracle allows online RMAN backup while the database is open:
<a href="https://docs.oracle.com/en/database/oracle/oracle-database/21/bradv/getting-started-rman.html" target="_blank" rel="noopener noreferrer">Getting Started with RMAN</a>.

What matters is where that backup traffic goes.

- entry-level block volume: backup traffic interferes with everything else directly
- single UHP volume: more headroom exists, but backup still shares the same device as foreground workload
- multiple separated volumes: `FRA` can absorb backup and archive traffic without becoming the same device as `DATA` and `REDO`

Oracle also documents archived redo handling inside FRA:
<a href="https://docs.oracle.com/en/database/oracle/oracle-database/23/admin/managing-archived-redo-log-files.html" target="_blank" rel="noopener noreferrer">Managing Archived Redo Log Files</a>.

## Relevant Project Artifacts

- plan: [PLAN.md](PLAN.md)
- progress board: [PROGRESS_BOARD.md](PROGRESS_BOARD.md)
- backlog: [BACKLOG.md](BACKLOG.md)
- current baseline guide: [progress/sprint_9/oracle_block_volume_baseline_guide.md](progress/sprint_9/oracle_block_volume_baseline_guide.md)
- Sprint 9 single-UHP comparison: [progress/sprint_9/fio-analysis-oracle-single-4k-redo-integration.md](progress/sprint_9/fio-analysis-oracle-single-4k-redo-integration.md)
- Sprint 9 multi-volume comparison: [progress/sprint_9/fio-analysis-oracle-multi-4k-redo-integration.md](progress/sprint_9/fio-analysis-oracle-multi-4k-redo-integration.md)

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
