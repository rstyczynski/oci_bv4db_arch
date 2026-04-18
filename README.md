# OCI Block Volume for Oracle Database Architecture

Practical guidance and benchmark-backed exploration of how to configure OCI Block Volumes for Oracle Database across different scale levels.

This repository started as a benchmarking project and has grown into two things:

- a set of executable sprints that validate OCI compute and block volume layouts
- a practical design guide for Oracle `DATA`, `REDO`, and `FRA` storage domains on OCI

## Table of Contents

- [Project Scope](#project-scope)
- [What Has Been Achieved](#what-has-been-achieved)
- [Current Automation Scope](#current-automation-scope)
- [Repository Structure](#repository-structure)
- [Oracle Storage Domains](#oracle-storage-domains)
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
- [Limits](#limits)

## Project Scope

The project validates OCI block volume layouts for Oracle Database and turns those results into practical operator guidance. It is not only a benchmark repository anymore. It is also a design reference for deciding when a simple single-volume layout is acceptable, when three-domain separation is required, and how to scale from small deployments to larger Oracle environments.

The central architectural idea is that Oracle storage should be treated as three different domains:

- `DATA`
- `REDO`
- `FRA`

Those domains do not behave the same way, do not scale the same way, and should not be treated as one generic disk bucket once the database becomes a real production system.

## What Has Been Achieved

The project already completed a sequence of practical sprints:

- Sprint 1: baseline compute and block volume benchmark, plus foundational OCI networking, vault, SSH, and scaffold work
  - design: [progress/sprint_1/sprint_1_design.md](/Users/rstyczynski/projects/oci_bv4db_arch/progress/sprint_1/sprint_1_design.md)
  - tests: [progress/sprint_1/sprint_1_tests.md](/Users/rstyczynski/projects/oci_bv4db_arch/progress/sprint_1/sprint_1_tests.md)
  - analysis: [progress/sprint_1/fio_analysis.md](/Users/rstyczynski/projects/oci_bv4db_arch/progress/sprint_1/fio_analysis.md)
- Sprint 2: maximum-performance single-volume benchmark
  - design: [progress/sprint_2/sprint_2_design.md](/Users/rstyczynski/projects/oci_bv4db_arch/progress/sprint_2/sprint_2_design.md)
  - tests: [progress/sprint_2/sprint_2_tests.md](/Users/rstyczynski/projects/oci_bv4db_arch/progress/sprint_2/sprint_2_tests.md)
  - analysis: [progress/sprint_2/fio_analysis.md](/Users/rstyczynski/projects/oci_bv4db_arch/progress/sprint_2/fio_analysis.md)
- Sprint 3: mixed `8k` database-oriented fio profile
  - design: [progress/sprint_3/sprint_3_design.md](/Users/rstyczynski/projects/oci_bv4db_arch/progress/sprint_3/sprint_3_design.md)
  - tests: [progress/sprint_3/sprint_3_tests.md](/Users/rstyczynski/projects/oci_bv4db_arch/progress/sprint_3/sprint_3_tests.md)
- Sprint 4: first Oracle-style multi-domain layout, later marked failed because fio grouped reporting hid per-job behavior
  - design: [progress/sprint_4/sprint_4_design.md](/Users/rstyczynski/projects/oci_bv4db_arch/progress/sprint_4/sprint_4_design.md)
  - tests: [progress/sprint_4/sprint_4_tests.md](/Users/rstyczynski/projects/oci_bv4db_arch/progress/sprint_4/sprint_4_tests.md)
- Sprint 5: corrected Oracle-style rerun with valid per-job reporting for `DATA`, `REDO`, and `FRA`
  - design: [progress/sprint_5/sprint_5_design.md](/Users/rstyczynski/projects/oci_bv4db_arch/progress/sprint_5/sprint_5_design.md)
  - tests: [progress/sprint_5/sprint_5_tests.md](/Users/rstyczynski/projects/oci_bv4db_arch/progress/sprint_5/sprint_5_tests.md)
  - integration analysis: [progress/sprint_5/fio-analysis-oracle-integration.md](/Users/rstyczynski/projects/oci_bv4db_arch/progress/sprint_5/fio-analysis-oracle-integration.md)
- Sprint 6: `oci_scaffold` branch sync with upstream `main` and smoke validation of block volume ensure behavior
  - design: [progress/sprint_6/sprint_6_design.md](/Users/rstyczynski/projects/oci_bv4db_arch/progress/sprint_6/sprint_6_design.md)
  - tests: [progress/sprint_6/sprint_6_tests.md](/Users/rstyczynski/projects/oci_bv4db_arch/progress/sprint_6/sprint_6_tests.md)
- Sprint 7: documentation-only Oracle sizing and scalability guide
  - guide: [progress/sprint_7/oracle_block_volume_sizing_guide.md](/Users/rstyczynski/projects/oci_bv4db_arch/progress/sprint_7/oracle_block_volume_sizing_guide.md)

Status tracking lives in:

- [PLAN.md](/Users/rstyczynski/projects/oci_bv4db_arch/PLAN.md)
- [PROGRESS_BOARD.md](/Users/rstyczynski/projects/oci_bv4db_arch/PROGRESS_BOARD.md)
- [BACKLOG.md](/Users/rstyczynski/projects/oci_bv4db_arch/BACKLOG.md)

## Current Automation Scope

The repository includes executable automation for OCI provisioning and benchmark runs.

Main scope:

- shared infrastructure provisioning
- ephemeral compute and block volume benchmark runs
- Oracle-style multi-volume benchmark layouts
- integration and smoke validation around those flows
- `oci_scaffold` extension work for OCI block volume lifecycle management

Primary scripts:

- [tools/setup_infra.sh](/Users/rstyczynski/projects/oci_bv4db_arch/tools/setup_infra.sh)
- [tools/run_bv_fio.sh](/Users/rstyczynski/projects/oci_bv4db_arch/tools/run_bv_fio.sh)
- [tools/run_bv_fio_perf.sh](/Users/rstyczynski/projects/oci_bv4db_arch/tools/run_bv_fio_perf.sh)
- [tools/run_bv_fio_mixed8k.sh](/Users/rstyczynski/projects/oci_bv4db_arch/tools/run_bv_fio_mixed8k.sh)
- [tools/run_bv_fio_oracle.sh](/Users/rstyczynski/projects/oci_bv4db_arch/tools/run_bv_fio_oracle.sh)
- [tools/run_bv_fio_oracle_sprint5.sh](/Users/rstyczynski/projects/oci_bv4db_arch/tools/run_bv_fio_oracle_sprint5.sh)

This README does not try to preserve outdated quick-start examples from the earliest project state. The repository evolved significantly beyond Sprint 1, including a move away from the original region example and toward richer Oracle-style storage layouts.

## Repository Structure

```text
tools/                  OCI provisioning and benchmark execution scripts
tests/                  smoke and integration validation
progress/               sprint-by-sprint artifacts, results, and analyses
model/                  drawio architecture diagrams
oci_scaffold/           submodule for idempotent OCI resource lifecycle scripts
RUPStrikesBack/         read-only methodology/rules submodule
PLAN.md                 sprint roadmap
BACKLOG.md              product backlog
PROGRESS_BOARD.md       execution status board
```

## Oracle Storage Domains

### DATA

`DATA` usually carries the largest blended read/write load and is the first place where throughput and aggregate IOPS matter. This domain benefits most from striping or from moving to higher-performance block volume classes because many Oracle datafile operations parallelize well enough to use that extra bandwidth.

### REDO

`REDO` is different. It is much smaller in capacity terms, but much more sensitive to write latency and write consistency. Practical layouts should keep redo isolated from large random data workloads and recovery-area traffic. Redo rarely needs the largest capacity footprint, but it does need predictable write behavior.

### FRA

`FRA` is often dominated by archivelogs, backup-related activity, and recovery-oriented background traffic. It can become large before it becomes fast. In smaller environments it can live on a simpler layout, but in larger environments it should still remain isolated so that backup or recovery traffic does not distort foreground database behavior.

## Entry-Level Oracle Database

An entry-level Oracle Database is the smallest serious deployment that still respects Oracle storage domains. It is meant for development, testing, small internal systems, and low-concurrency production cases where cost and simplicity matter more than extracting every last IOPS.

A single block volume is acceptable for a very small, non-critical database such as a disposable lab system, a proof of concept, or a lightweight development environment. In that case, simplicity can matter more than storage-domain separation. The tradeoff is that `DATA`, `REDO`, and `FRA` are no longer isolated, so diagnosis, growth, and operational discipline become weaker.

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

Sprint 5 is the most useful practical reference here because it produced valid per-job Oracle-style results with separate `DATA`, `REDO`, and `FRA` workloads:

- [progress/sprint_5/fio-analysis-oracle-integration.md](/Users/rstyczynski/projects/oci_bv4db_arch/progress/sprint_5/fio-analysis-oracle-integration.md)

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

This work suggests two possible future directions:

- an `operate*` class for operational actions on already managed resources
- an `update*` class for controlled mutation of existing resources

The most important constraint is resource ownership. Update-style operations are easier to justify for resources that were explicitly created by the project than for resources merely adopted into state. Created resources imply stronger ownership and lower ambiguity. Adopted resources imply higher risk because the project may not be the only controller of their desired state.

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

## Limits

This README is practical but not normative. It does not claim that one exact Oracle volume count, one exact VPU setting, or one exact OCI shape is universally correct. It also does not replace workload-specific measurement. It summarizes the project’s current evidence and turns it into design guidance.

The next useful step after this README is to continue turning the scaling paths and lifecycle questions into new backlog items and follow-on sprints.
