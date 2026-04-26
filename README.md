# OCI Block Volume for Oracle Database Architecture

Practical OCI block volume guidance for Oracle Database, backed by executed sprint results in this repository.

This repository now focuses on practical OCI Oracle layouts across OCI block volume performance tiers:

1. entry-level / Lower Cost single volume
2. single-volume OCI tiers from Balanced to UHP
3. multi-volume OCI tiers with Oracle-style storage-domain separation

![Architecture Diagram](model/storage_view.svg)

## Table of Contents

- [What This Repository Proves](#what-this-repository-proves)
- [The Three Layouts](#the-three-layouts)
  - [1. Entry-Level Block Volume](#1-entry-level-block-volume)
  - [2. Single-Volume OCI Tiers](#2-single-volume-oci-tiers)
  - [3. Multiple Volumes With Storage-Domain Separation](#3-multiple-volumes-with-storage-domain-separation)
- [UHP iSCSI multipath evidence (Sprints 22 and 23)](#uhp-iscsi-multipath-evidence-sprints-22-and-23)
- [Direct Comparison](#direct-comparison)
- [What To Use In Practice](#what-to-use-in-practice)
- [RMAN and FRA During Production](#rman-and-fra-during-production)
- [Relevant Project Artifacts](#relevant-project-artifacts)
- [Official OCI References](#official-oci-references)
- [Official Oracle References](#official-oracle-references)

## What This Repository Proves

The project has already executed enough work to support a simple practical conclusion:

- one ordinary block volume is enough to start
- one faster OCI block volume tier goes further, but it is still one shared contention domain
- multiple volumes mapped to Oracle storage domains are the strongest practical layout for real production behavior

The active Oracle tier comparison in this repository is now Sprint 10, which keeps the Sprint 9 `4k` redo Oracle workload and extends it across OCI tiers:

- Lower Cost single-volume
- Balanced single-volume
- Balanced multi-volume
- Higher Performance single-volume
- Higher Performance multi-volume

Sprint 9 remains the UHP reference for:

- single-volume UHP
- multi-volume UHP

The Oracle domains that matter are still:

- `DATA`
- `REDO`
- `FRA`

Oracle directly supports separating redo from datafiles to reduce contention:
<a href="https://docs.oracle.com/html/E25494_01/onlineredo002.htm" target="_blank" rel="noopener noreferrer">Planning the Redo Log</a>.

Oracle also recommends placing the Fast Recovery Area on separate storage from the active database area:
<a href="https://docs.oracle.com/html/E10642_06/rcmconfb.htm" target="_blank" rel="noopener noreferrer">Configuring the RMAN Environment</a>.

Because this repository is specifically about OCI, the practical conclusions also depend on OCI block volume performance levels, UHP attachment behavior, multipath, and instance-side block volume limits.

Sprints **22** and **23** document how this project actually exercises **UHP iSCSI multipath on the instance**: Sprint 22 establishes **HA-correct** multipath (paths aggregated via dm-multipath, mount on the mapper device), optional **`/etc/fstab`** persistence with `_netdev` and `nofail`, and a reproducible **multipath versus single-path** A/B benchmark with **OCI Monitoring** reports and timestamps aligned to fio. Sprint 23 keeps that baseline and adds an **explicit `multipath.conf`** load-balancing policy for the multipath phase (multibus + round-robin intent), richer **before/after configuration** captures, and **bounded `iostat`** during fio so path-level behavior is visible in artifacts. Details and runbooks are in [UHP iSCSI multipath evidence (Sprints 22 and 23)](#uhp-iscsi-multipath-evidence-sprints-22-and-23).

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

Current measured result on the Sprint 1 entry-level baseline:

- sequential `1M`: about `11 MB/s` read and `12 MB/s` write
- random `4k`: about `1520` read IOPS / `6 MB/s` read and `1520` write IOPS / `6 MB/s` write

Relevant OCI reference:

- <a href="https://docs.oracle.com/en-us/iaas/Content/Block/Concepts/blockvolumeperformance.htm" target="_blank" rel="noopener noreferrer">OCI Block Volume Performance</a>

### 2. Single-Volume OCI Tiers

This is the “one fast disk” choice. In the current repository evidence, the same Oracle-style guest-visible layout was exercised on:

- Lower Cost single-volume in Sprint 10
- Balanced single-volume in Sprint 10
- Higher Performance single-volume in Sprint 10
- UHP single-volume in Sprint 9

Use it for:

- smaller production systems
- environments where simplicity matters
- cases where more ceiling is needed than the entry-level layout can provide

Its limit is simple: all Oracle activity still converges on one device.

Practical references:

- Sprint 9 single-UHP analysis: [progress/sprint_9/fio-analysis-oracle-single-4k-redo-integration.md](progress/sprint_9/fio-analysis-oracle-single-4k-redo-integration.md)
- fio job reused for the current Oracle baseline: [progress/sprint_9/oracle-layout-4k-redo.fio](progress/sprint_9/oracle-layout-4k-redo.fio)

Measured result:

| OCI tier | DATA | REDO | FRA |
| ------ | ------ | ------ | ------ |
| Lower Cost single-volume | `754` read IOPS / `5.89 MiB/s` read; `324` write IOPS / `2.53 MiB/s` write | `4` write IOPS / `0.02 MiB/s` | `13` read IOPS / `12.88 MiB/s` read; `12` write IOPS / `12.39 MiB/s` write |
| Balanced single-volume | `6395` read IOPS / `49.96 MiB/s` read; `2742` write IOPS / `21.43 MiB/s` write | `36` write IOPS / `0.14 MiB/s` | `105` read IOPS / `104.77 MiB/s` read; `104` write IOPS / `104.30 MiB/s` write |
| Higher Performance single-volume | `9893` read IOPS / `77.29 MiB/s` read; `4241` write IOPS / `33.13 MiB/s` write | `60` write IOPS / `0.23 MiB/s` | `120` read IOPS / `120.00 MiB/s` read; `120` write IOPS / `120.00 MiB/s` write |
| UHP single-volume reference | `18606` read IOPS / `145.36 MiB/s` read; `7969` write IOPS / `62.26 MiB/s` write | `131` write IOPS / `0.51 MiB/s` | `120` read IOPS / `120.00 MiB/s` read; `120` write IOPS / `120.00 MiB/s` write |

Relevant OCI references:

- <a href="https://docs.oracle.com/iaas/Content/Block/Concepts/blockvolumeultrahighperformance.htm" target="_blank" rel="noopener noreferrer">OCI Ultra High Performance Block Volumes</a>
- <a href="https://docs.oracle.com/en-us/iaas/Content/Block/Concepts/blockvolumeperformance.htm" target="_blank" rel="noopener noreferrer">OCI Block Volume Performance</a>
- <a href="https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/configuringmultipathattachments.htm" target="_blank" rel="noopener noreferrer">OCI Configuring Attachments to Ultra High Performance Volumes</a>
- <a href="https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/connectingtouhpvolumes.htm" target="_blank" rel="noopener noreferrer">OCI Working with Multipath-Enabled iSCSI-Attached Volumes</a>
- <a href="https://docs.oracle.com/iaas/Content/Block/Tasks/enablingblockvolumemanagementplugin.htm" target="_blank" rel="noopener noreferrer">OCI Enabling the Block Volume Management Plugin</a>

The tier numbers above assume a healthy attachment stack on the instance. For **how this repository validates multipath, fstab, single-path fallback, and optional load balancing** on UHP iSCSI, see [UHP iSCSI multipath evidence (Sprints 22 and 23)](#uhp-iscsi-multipath-evidence-sprints-22-and-23).

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

Measured result:

| OCI tier | DATA | REDO | FRA |
| ------ | ------ | ------ | ------ |
| Balanced multi-volume | `16780` read IOPS / `131.09 MiB/s` read; `7187` write IOPS / `56.15 MiB/s` write | `827` write IOPS / `3.23 MiB/s` | `24` read IOPS / `23.57 MiB/s` read; `23` write IOPS / `23.31 MiB/s` write |
| Higher Performance multi-volume | `20979` read IOPS / `163.90 MiB/s` read; `8984` write IOPS / `70.19 MiB/s` write | `769` write IOPS / `3.00 MiB/s` | `29` read IOPS / `29.37 MiB/s` read; `29` write IOPS / `29.22 MiB/s` write |
| UHP multi-volume reference | `55137` read IOPS / `430.76 MiB/s` read; `23622` write IOPS / `184.55 MiB/s` write | `791` write IOPS / `3.09 MiB/s` | `24` read IOPS / `23.57 MiB/s` read; `23` write IOPS / `23.31 MiB/s` write |

Relevant OCI references:

- <a href="https://docs.oracle.com/en-us/iaas/Content/Block/Concepts/blockvolumeperformance.htm" target="_blank" rel="noopener noreferrer">OCI Block Volume Performance</a>
- <a href="https://docs.oracle.com/iaas/Content/Block/Tasks/attachingavolume.htm" target="_blank" rel="noopener noreferrer">OCI Attaching a Block Volume to an Instance</a>
- <a href="https://docs.oracle.com/iaas/Content/Block/Tasks/connectingtoavolume.htm" target="_blank" rel="noopener noreferrer">OCI Connecting to a Block Volume</a>

## Direct Comparison

The most important comparison in the repository is now the OCI tier matrix from Sprint 10, with Sprint 9 retained as the UHP reference.

That matrix varies **OCI tier and volume topology** while holding the Oracle-style fio layout model steady. It does not, by itself, prove how multipathed UHP iSCSI behaves on the Linux instance; for **multipath versus single-path** and **host-side policy** evidence on a database-class guest, use the **UHP iSCSI multipath evidence** section below alongside the tier numbers.

The Sprint 9 and Sprint 10 runs keep the same Oracle fio workload and guest-visible Oracle layout model. The variables are:

- OCI block volume performance tier
- single-volume versus multi-volume topology
- compute sizing used to realize the target OCI tier

Single-volume comparison:

| Tier | DATA | REDO | FRA |
| ------ | ---- | ---- | --- |
| Lower Cost | `754` read IOPS / `5.89 MiB/s` read; `324` write IOPS / `2.53 MiB/s` write | `4` write IOPS / `0.02 MiB/s` | `13` read IOPS / `12.88 MiB/s` read; `12` write IOPS / `12.39 MiB/s` write |
| Balanced | `6395` read IOPS / `49.96 MiB/s` read; `2742` write IOPS / `21.43 MiB/s` write | `36` write IOPS / `0.14 MiB/s` | `105` read IOPS / `104.77 MiB/s` read; `104` write IOPS / `104.30 MiB/s` write |
| Higher Performance | `9893` read IOPS / `77.29 MiB/s` read; `4241` write IOPS / `33.13 MiB/s` write | `60` write IOPS / `0.23 MiB/s` | `120` read IOPS / `120.00 MiB/s` read; `120` write IOPS / `120.00 MiB/s` write |
| UHP reference | `18606` read IOPS / `145.36 MiB/s` read; `7969` write IOPS / `62.26 MiB/s` write | `131` write IOPS / `0.51 MiB/s` | `120` read IOPS / `120.00 MiB/s` read; `120` write IOPS / `120.00 MiB/s` write |

Multi-volume comparison:

| Tier | DATA | REDO | FRA |
| ------ | ---- | ---- | --- |
| Balanced | `16780` read IOPS / `131.09 MiB/s` read; `7187` write IOPS / `56.15 MiB/s` write | `827` write IOPS / `3.23 MiB/s` | `24` read IOPS / `23.57 MiB/s` read; `23` write IOPS / `23.31 MiB/s` write |
| Higher Performance | `20979` read IOPS / `163.90 MiB/s` read; `8984` write IOPS / `70.19 MiB/s` write | `769` write IOPS / `3.00 MiB/s` | `29` read IOPS / `29.37 MiB/s` read; `29` write IOPS / `29.22 MiB/s` write |
| UHP reference | `55137` read IOPS / `430.76 MiB/s` read; `23622` write IOPS / `184.55 MiB/s` write | `791` write IOPS / `3.09 MiB/s` | `24` read IOPS / `23.57 MiB/s` read; `23` write IOPS / `23.31 MiB/s` write |

Interpretation:

- single-volume tiers improve smoothly from Lower Cost to UHP, but they always remain one contention domain
- multi-volume Balanced already keeps `REDO` far stronger than Balanced single-volume because `REDO` is no longer competing with the `FRA` stream on the same device
- Higher Performance multi-volume is the strongest Sprint 10 layout and the best non-UHP Oracle layout proven in this repository
- the UHP multi-volume reference remains the top-end result in the repository
- the `REDO` job is intentionally synchronous (`iodepth=1` with `fdatasync=1` and `4k` writes), so the meaningful redo comparison is synchronous write rate and latency behavior, not throughput headlines

Single-volume safety clarification:

- a single block volume can still be logically safe for Oracle if redo keeps its synchronous durability path
- commit durability depends on redo reaching disk; Oracle does not need to flush `DATA` and `FRA` at the same moment
- this is why a single-volume layout can be crash-safe enough while still being weaker operationally than separated volumes
- the multi-volume recommendation in this repository is about workload isolation and commit-path stability, not about Oracle requiring multiple volumes to function correctly

That is the central OCI Oracle result of this repository.

## UHP iSCSI multipath evidence (Sprints 22 and 23)

Sprint 9 and Sprint 10 focus on **Oracle-visible layout and fio results** across OCI tiers. Sprints **22** and **23** answer a different question that still gates UHP usefulness in production: **is the block volume attached the way we think it is**, and **what changes when we deliberately run single-path instead of multipath** on the same workflow?

### Single-path vs multipath (HA) vs multipath (load balancing)

This is the comparison this repository makes explicit:

- **Single-path (intentional limitation)**: one iSCSI path is logged in and the filesystem is mounted from a single path device. This is used only as a controlled baseline to show what changes when redundancy is removed.
- **Multipath (HA correctness)**: multiple iSCSI sessions/paths are present, dm-multipath aggregates them into a mapper device, and the filesystem is mounted on `/dev/mapper/mpath*` (or WWID) rather than on a raw path device. This is the default “correct attachment” goal.
- **Multipath + load balancing (distribution evidence)**: HA-correct multipath plus an explicit dm-multipath policy (for example round-robin) so I/O distribution across active paths is observable in evidence (for example bounded `iostat -x` during fio).

Direct comparison (attachment mode):

| Mode | Primary intent | Mount source (expected) | Path distribution (expected) | Evidence focus | Where this repo proves it |
| --- | --- | --- | --- | --- | --- |
| Single-path | Controlled baseline (no redundancy) | Single iSCSI path device (by-path) | One path only | “What breaks/changes when redundancy is removed” | Sprint 22 A/B and Sprint 23 A/B (`singlepath` phase artifacts + diagnostics) |
| Multipath (HA) | Correct aggregation + failover | `/dev/mapper/mpath*` (or WWID) | May still look like “one hot path” | Multipath map exists + filesystem uses mapper | Sprint 22 (HA baseline), Sprint 23 (same HA baseline) |
| Multipath (load balancing) | Distribution evidence | `/dev/mapper/mpath*` (or WWID) | Multiple active paths carry I/O during the window | Policy + per-path I/O evidence (bounded `iostat -x`) | Sprint 23 (explicit dm-multipath policy + distribution evidence) |

Important: HA-correct multipath does **not** automatically imply observable path distribution. Default dm-multipath policies can remain effectively “one hot path” while still being HA-safe.

Performance diagram (draw.io “Performance” page):

![Performance Diagram](model/performance_multipath.svg)

### Sprint summary

**Sprint 22 — HA multipath baseline (not load balancing by default).** The sprint separates **HA multipath correctness** from **throughput spread across paths**. It adds optional **fstab** management for the sprint mountpoint, **A/B fio** in multipath mode then again after switching to single-path, **timestamped fio progress**, and **OCI metrics** exports scoped to each run for correlation.

**Sprint 23 — Sprint 22 plus explicit load-balancing configuration.** The same A/B engine and fstab story apply; Sprint 23 additionally writes a documented **`/etc/multipath.conf`** stanza for OCI Block Volume (for example multibus with round-robin intent), archives **pre/post** configuration snapshots around the multipath phase, extends diagnostics (including `multipath -t`, `dmsetup`, and fstab lines in diagnostic bundles), and captures **bounded `iostat -x` during fio** so path activity is visible without an unbounded capture.

Practical references:

- Sprint 22 operator guide: [progress/sprint_22/sprint22_manual.md](progress/sprint_22/sprint22_manual.md)
- Sprint 23 operator guide: [progress/sprint_23/sprint23_manual.md](progress/sprint_23/sprint23_manual.md)
- Sprint 22 design (HA vs load balancing): [progress/sprint_22/sprint_22_design.md](progress/sprint_22/sprint_22_design.md)
- Sprint 23 design (policy and artifacts): [progress/sprint_23/sprint_23_design.md](progress/sprint_23/sprint_23_design.md)
- A/B runners: [tools/run_bv4db_fio_multipath_ab_sprint22.sh](tools/run_bv4db_fio_multipath_ab_sprint22.sh), [tools/run_bv4db_fio_multipath_ab_sprint23.sh](tools/run_bv4db_fio_multipath_ab_sprint23.sh)
- Multipath diagnostics entry points: [tools/run_bv4db_multipath_diag_sprint22.sh](tools/run_bv4db_multipath_diag_sprint22.sh), [tools/run_bv4db_multipath_diag_sprint23.sh](tools/run_bv4db_multipath_diag_sprint23.sh)
- Shared benchmark core (also used by earlier multipath sprints): [tools/run_bv4db_fio_multipath_ab_sprint20.sh](tools/run_bv4db_fio_multipath_ab_sprint20.sh)

## What To Use In Practice

Use entry-level block volume when:

- the database is tiny
- the system is non-critical
- simplicity matters more than production discipline

Use single UHP volume when:

- the database is still fairly small
- more headroom is needed than a basic entry-level volume can provide
- one shared contention domain is acceptable
- you care about **iSCSI multipath on the instance** (HA vs deliberate single-path, and optional load balancing); see **UHP iSCSI multipath evidence (Sprints 22 and 23)** below

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
- OCI tier comparison: [progress/sprint_10/oci_performance_tier_comparison.md](progress/sprint_10/oci_performance_tier_comparison.md)
- Sprint 10 lower-cost single analysis: [progress/sprint_10/fio-analysis-oracle-lower-single-4k-redo-integration.md](progress/sprint_10/fio-analysis-oracle-lower-single-4k-redo-integration.md)
- Sprint 10 balanced single analysis: [progress/sprint_10/fio-analysis-oracle-balanced-single-4k-redo-integration.md](progress/sprint_10/fio-analysis-oracle-balanced-single-4k-redo-integration.md)
- Sprint 10 balanced multi analysis: [progress/sprint_10/fio-analysis-oracle-balanced-multi-4k-redo-integration.md](progress/sprint_10/fio-analysis-oracle-balanced-multi-4k-redo-integration.md)
- Sprint 10 higher-performance single analysis: [progress/sprint_10/fio-analysis-oracle-hp-single-4k-redo-integration.md](progress/sprint_10/fio-analysis-oracle-hp-single-4k-redo-integration.md)
- Sprint 10 higher-performance multi analysis: [progress/sprint_10/fio-analysis-oracle-hp-multi-4k-redo-integration.md](progress/sprint_10/fio-analysis-oracle-hp-multi-4k-redo-integration.md)
- Sprint 9 UHP baseline guide: [progress/sprint_9/oracle_block_volume_baseline_guide.md](progress/sprint_9/oracle_block_volume_baseline_guide.md)
- Sprint 22 UHP iSCSI multipath + fstab + A/B guide: [progress/sprint_22/sprint22_manual.md](progress/sprint_22/sprint22_manual.md)
- Sprint 23 explicit multipath load balancing, deeper diagnostics, and iostat during fio: [progress/sprint_23/sprint23_manual.md](progress/sprint_23/sprint23_manual.md)

## Official OCI References

- <a href="https://docs.oracle.com/en-us/iaas/Content/Block/Concepts/blockvolumeperformance.htm" target="_blank" rel="noopener noreferrer">OCI Block Volume Performance</a>
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
