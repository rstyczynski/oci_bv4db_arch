# Oracle Database on OCI Block Volumes: Practical Sizing and Scalability Guide

## Table of Contents

- [Introduction](#introduction)
- [What The Project Already Proved](#what-the-project-already-proved)
- [Storage Domains](#storage-domains)
  - [DATA](#data)
  - [REDO](#redo)
  - [FRA](#fra)
- [Entry-Level Oracle Database](#entry-level-oracle-database)
- [Mid-Level Oracle Database](#mid-level-oracle-database)
- [Top-End Oracle Database](#top-end-oracle-database)
- [Scalability Scenarios](#scalability-scenarios)
  - [Scenario 1: Capacity Growth Without Major Throughput Growth](#scenario-1-capacity-growth-without-major-throughput-growth)
  - [Scenario 2: OLTP Growth With Commit Pressure](#scenario-2-oltp-growth-with-commit-pressure)
  - [Scenario 3: Recovery and Backup Growth](#scenario-3-recovery-and-backup-growth)
  - [Scenario 4: Mixed Growth](#scenario-4-mixed-growth)
- [RMAN Backup During Production Time](#rman-backup-during-production-time)
- [Recommended Decision Model](#recommended-decision-model)
- [What This Means For oci_scaffold](#what-this-means-for-oci_scaffold)
- [Practical Recommendations](#practical-recommendations)
  - [Entry-Level](#entry-level)
  - [Mid-Level](#mid-level)
  - [Top-End](#top-end)
- [Limits Of This Document](#limits-of-this-document)
- [Official Oracle References](#official-oracle-references)

## Introduction

This document summarizes the work completed so far in the OCI Block Volume for Database Architecture project and turns it into practical guidance for Oracle Database storage design on OCI Block Volumes. It is intentionally theoretical: it does not introduce new benchmark runs, live infrastructure, or new automation. Instead, it uses the already completed sprints as evidence for how to think about Oracle storage domains and how to scale them.

The main conclusion from the project so far is simple: Oracle storage should be treated as three different domains with different performance behavior and different scaling paths.

- `DATA` is the dominant throughput and IOPS domain.
- `REDO` is the lowest-latency and most serialization-sensitive domain.
- `FRA` is the recovery and background I/O domain, usually capacity-led but still able to interfere with the rest of the database if placed badly.

The most important practical rule is therefore separation first, optimization second. A simple separated layout is usually more valuable than an advanced but mixed layout.

## What The Project Already Proved

Sprint 1 established a basic single-volume baseline and showed that a minimal attached block volume is sufficient for functional database-style fio execution, but not a strong performance profile. Sprint 2 showed how a maximum-performance single-volume configuration improves the ceiling, but still represents only one storage class. Sprint 4 and Sprint 5 are the most useful for Oracle layout decisions because they exercised separate `DATA`, `REDO`, and `FRA` domains concurrently and demonstrated that workload isolation is visible in both fio and device-level metrics.

The practical reading of those sprints is:

- one generic block volume is enough to start, but it is not a good long-term Oracle layout
- performance-oriented single-volume tuning helps, but does not replace storage-class separation
- Oracle-style layouts become much more meaningful when `DATA`, `REDO`, and `FRA` are isolated
- per-job reporting matters because aggregate numbers can hide whether the layout is actually behaving as intended

## Storage Domains

### DATA

`DATA` usually carries the largest blended read/write load and is the first place where throughput and aggregate IOPS matter. This domain benefits most from striping or from moving to higher-performance block volume classes because many Oracle datafile operations parallelize well enough to use that extra bandwidth.

### REDO

`REDO` is different. It is much smaller in capacity terms, but much more sensitive to write latency and write consistency. Practical layouts should keep redo isolated from large random data workloads and recovery-area traffic. Redo rarely needs the largest capacity footprint, but it does need predictable write behavior.

Oracle directly supports separating redo from datafiles to reduce contention and recommends placing multiplexed redo members on different disks:
<a href="https://docs.oracle.com/html/E25494_01/onlineredo002.htm" target="_blank" rel="noopener noreferrer">Planning the Redo Log</a>.

### FRA

`FRA` is often dominated by archivelogs, backup-related activity, and recovery-oriented background traffic. It can become large before it becomes fast. In smaller environments it can live on a simpler layout, but in larger environments it should still remain isolated so that backup or recovery traffic does not distort foreground database behavior.

Oracle recommends placing the recovery area on a separate disk from the active database area:
<a href="https://docs.oracle.com/html/E10642_06/rcmconfb.htm" target="_blank" rel="noopener noreferrer">Configuring the RMAN Environment</a>.

## Entry-Level Oracle Database

An entry-level Oracle Database is the smallest serious deployment that still respects Oracle storage domains. It is meant for development, testing, small internal systems, and low-concurrency production cases where cost and simplicity matter more than extracting every last IOPS.

A single block volume is acceptable for a very small, non-critical database such as a disposable lab system, a proof of concept, or a lightweight development environment. In that case, simplicity can matter more than storage-domain separation. The tradeoff is that `DATA`, `REDO`, and `FRA` are no longer isolated, so diagnosis, growth, and operational discipline become weaker.

This is also consistent with Oracle's broader I/O design guidance, which says a single striped volume can provide adequate performance in many situations when manageability is the priority:
<a href="https://docs.oracle.com/database/121/TGDBA/pfgrf_iodesign.htm" target="_blank" rel="noopener noreferrer">I/O Configuration and Design</a>.

Practical target characteristics:

- small database size
- limited concurrent users or sessions
- moderate growth expectations
- low operational complexity requirement

Recommended layout:

- one volume for `DATA`
- one volume for `REDO`
- one volume for `FRA`

Why this is enough:

- the biggest operational mistake at small scale is mixing everything together
- even when performance demand is modest, isolation keeps behavior understandable
- this layout is easy to operate, easy to reason about, and easy to grow later

What not to do:

- do not start with a single shared volume unless the environment is truly disposable
- do not over-engineer with too many striped components if the database is small and the operator maturity is low

Practical exception:

- a single BV is acceptable for tiny non-critical databases
- once the database is a real production system or expected to grow, separate `DATA`, `REDO`, and `FRA`

Scalability path:

- first raise performance on the `DATA` volume
- keep `REDO` isolated rather than making it larger without reason
- enlarge `FRA` primarily for retention and recovery needs

## Mid-Level Oracle Database

A mid-level Oracle Database is the point where storage design should become explicitly performance-aware. This is the common transactional production tier: meaningful concurrency, real growth, and visible contention if domains are mixed.

Practical target characteristics:

- sustained production workload
- noticeable random I/O pressure
- real redo generation rate
- growing recovery footprint

Recommended layout:

- striped `DATA` built from multiple block volumes
- isolated `REDO`, either on a dedicated single high-performing volume or a small dedicated stripe when justified
- dedicated `FRA` volume or volume set sized for retention and recovery operations

Why this layout is the practical middle ground:

- data is the easiest domain to scale horizontally through striping
- redo should be optimized for predictability, not just size
- FRA should remain separate because backup and archive activity is operationally bursty

Operational guidance:

- grow `DATA` first when throughput or IOPS ceilings appear
- tune `REDO` for latency stability rather than headline throughput
- treat `FRA` as both a capacity and interference-control domain

This is also the level where the Sprint 4 and Sprint 5 findings matter most. The project already showed that separate storage classes behave differently under concurrent load. That means a mid-level deployment should assume separation as a baseline architectural rule, not an optional refinement.

## Top-End Oracle Database

A top-end Oracle Database is a deployment where storage layout is driven by predictable performance engineering rather than by convenience. This includes very large OLTP systems, mixed high-throughput and high-recovery environments, and systems where storage bottlenecks directly translate into business risk.

Practical target characteristics:

- very high concurrency
- sustained large data-domain pressure
- strong sensitivity to write-latency spikes in redo
- large and active recovery area
- expectation of capacity and performance growth over time

Recommended layout:

- multi-volume striped `DATA` domain sized for the target throughput and IOPS envelope
- dedicated high-performance `REDO` domain, isolated from all other activity
- dedicated `FRA` domain sized independently for recovery policy, backup cadence, and archive generation
- explicit attention to pathing, attachment model, and per-domain performance ceilings

At this scale, the architecture should assume that each domain has an independent growth path:

- `DATA` grows with database size, query complexity, and concurrency
- `REDO` grows with transaction intensity and commit behavior
- `FRA` grows with retention, backup design, and recovery objectives

The top-end lesson from the project so far is not that one exact volume count has been proved optimal. The useful lesson is that domain isolation and per-domain observability are prerequisites before deeper tuning becomes meaningful.

## Scalability Scenarios

### Scenario 1: Capacity Growth Without Major Throughput Growth

This is common in systems where the database becomes larger but user concurrency does not change much.

Practical response:

- add capacity primarily to `DATA` and `FRA`
- preserve the same domain split
- avoid redesign unless service levels are changing

### Scenario 2: OLTP Growth With Commit Pressure

This is the classic transactional scaling problem: more sessions, more random I/O, and more sensitivity to commit latency.

Practical response:

- scale `DATA` for aggregate IOPS and throughput
- keep `REDO` isolated and watch latency before throughput
- do not let `FRA` activity share the same hot path

### Scenario 3: Recovery and Backup Growth

Some systems stay operationally stable in foreground workload but grow heavily in backup and archive demands.

Practical response:

- scale `FRA` independently
- keep backup-oriented load away from `DATA` and `REDO`
- treat retention policy and archive rate as first-class sizing inputs

### Scenario 4: Mixed Growth

This is the most realistic enterprise path: data gets larger, concurrency rises, and recovery requirements become stricter at the same time.

Practical response:

- scale each domain independently
- avoid any design that assumes one block volume profile is suitable for all three domains
- increase observability before increasing complexity

## RMAN Backup During Production Time

Running RMAN backup while the database is open and serving production workload is normal practice. The important design question is not whether RMAN can run online, but how backup I/O interacts with foreground database I/O.

Oracle explicitly states that if the database runs in `ARCHIVELOG` mode, then it can be backed up while open:
<a href="https://docs.oracle.com/en/database/oracle/oracle-database/21/bradv/getting-started-rman.html" target="_blank" rel="noopener noreferrer">Getting Started with RMAN</a>.

Practical effects of RMAN during production:

- RMAN increases read pressure on `DATA`
- RMAN increases write pressure on the backup target, often `FRA`
- RMAN can increase archive-related activity and therefore raise indirect pressure around `REDO` handling

This means backup traffic should be treated as a real sizing and isolation factor:

- on a single-BV layout, RMAN may be acceptable for very small non-critical systems, but backup traffic can interfere directly with foreground workload
- on a separated layout, `FRA` absorbs backup and recovery-oriented traffic much more cleanly
- on mid-level and top-end systems, daytime backup activity is a strong reason to keep `FRA` isolated from active `DATA` and `REDO` paths

Practical guidance:

- if production backups run during business hours, do not treat `FRA` as an optional storage domain
- if the database is small, one BV may still work, but backup windows will be less predictable
- if backup activity is frequent or heavy, storage separation becomes operationally important even before the database reaches high-end scale

Oracle also documents that archived redo logs can be directed into the Fast Recovery Area by using `USE_DB_RECOVERY_FILE_DEST`:
<a href="https://docs.oracle.com/en/database/oracle/oracle-database/23/admin/managing-archived-redo-log-files.html" target="_blank" rel="noopener noreferrer">Managing Archived Redo Log Files</a>.

## Recommended Decision Model

When deciding how to configure OCI block volumes for Oracle Database, the operator should make decisions in this order:

1. Separate `DATA`, `REDO`, and `FRA`.
2. Decide which domain is the first real performance risk.
3. Scale `DATA` horizontally before overcomplicating smaller domains.
4. Keep `REDO` optimized for stable write behavior.
5. Size `FRA` for recovery policy and isolation, not only for spare capacity.
6. Add complexity only when a clear bottleneck justifies it.

This keeps the design practical. It prevents premature optimization at the low end and prevents false simplicity at the high end.

## What This Means For oci_scaffold

The current project automation is strongest at the `ensure*` and `teardown*` level. That is enough for provisioning benchmark layouts, but not yet enough for broader operational lifecycle management of richer Oracle storage environments.

This work suggests two possible future directions for scaffold evolution:

- an `operate*` class for operational actions on already managed resources
- an `update*` class for controlled mutation of existing resources

The most important constraint is resource ownership. Update-style operations are easier to justify for resources that were explicitly created by the project than for resources merely adopted into state. Created resources imply stronger ownership and lower ambiguity. Adopted resources imply higher risk because the project may not be the only controller of their desired state.

This does not mean the command model is already decided. It means the Oracle storage analysis strengthens the case for treating lifecycle operations separately from provisioning operations.

## Practical Recommendations

### Entry-Level

- use three domains even when each domain is only one volume
- optimize for clarity and clean separation
- grow `DATA` first if pressure appears

### Mid-Level

- stripe `DATA`
- keep `REDO` isolated and performance-aware
- give `FRA` its own independent sizing path

### Top-End

- assume each domain needs its own performance model
- scale domains independently
- insist on per-domain observability before trusting aggregate benchmark numbers

## Limits Of This Document

This guide is intentionally practical but theoretical. It does not claim that one exact Oracle volume count, one exact VPU setting, or one exact shape is universally correct. It also does not replace workload-specific measurement. What it does provide is a grounded design model based on the results already collected in this project.

The next value from this document is not more prose. The next value is turning the identified scaling paths and lifecycle questions into follow-on backlog items and future sprints.

## Official Oracle References

The practical guidance in this document is supported by Oracle Database documentation in the following areas:

- General Oracle I/O and storage layout design:
  - <a href="https://docs.oracle.com/database/121/TGDBA/pfgrf_iodesign.htm" target="_blank" rel="noopener noreferrer">Oracle Database Performance Tuning Guide: I/O Configuration and Design</a>
- Redo log management and placement:
  - <a href="https://docs.oracle.com/en/database/oracle/oracle-database/23/admin/managing-the-redo-log.html" target="_blank" rel="noopener noreferrer">Oracle Database 23ai: Managing the Redo Log</a>
- Redo planning, sizing, and placing redo on different disks from datafiles:
  - <a href="https://docs.oracle.com/html/E25494_01/onlineredo002.htm" target="_blank" rel="noopener noreferrer">Oracle Database Administrator's Guide: Planning the Redo Log</a>
- Fast Recovery Area overview and sizing:
  - <a href="https://docs.oracle.com/en/database/oracle/oracle-database/19/ntdbi/about-fast-recovery-area-and-fast-recovery-area-disk-group.html" target="_blank" rel="noopener noreferrer">Oracle Database 19c: About the Fast Recovery Area and Fast Recovery Area Disk Group</a>
- RMAN configuration guidance, including the recommendation to keep the recovery area separate from active database files:
  - <a href="https://docs.oracle.com/html/E10642_06/rcmconfb.htm" target="_blank" rel="noopener noreferrer">Oracle Database Backup and Recovery User's Guide: Configuring the RMAN Environment</a>
- Archived redo log behavior when Fast Recovery Area is configured:
  - <a href="https://docs.oracle.com/en/database/oracle/oracle-database/23/admin/managing-archived-redo-log-files.html" target="_blank" rel="noopener noreferrer">Oracle Database 23ai: Managing Archived Redo Log Files</a>
- RMAN guidance for backing up an open database:
  - <a href="https://docs.oracle.com/en/database/oracle/oracle-database/21/bradv/getting-started-rman.html" target="_blank" rel="noopener noreferrer">Oracle Database 21c: Getting Started with RMAN</a>
