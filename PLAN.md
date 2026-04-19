# Development plan

OCI Block Volume for Database Architecture project.

Instruction for the operator: keep the development sprint by sprint by changing `Status` label from Planned via Progress to Done. To achieve simplicity each iteration contains exactly one feature. You may add more backlog Items in `BACKLOG.md` file, referring them in this plan.

Instruction for the implementor: keep analysis, design and implementation as simple as possible to achieve goals presented as Backlog Items. Remove each not required feature sticking to the Backlog Items definitions.

## Sprint 1 - Network and compute with block volume fio test

Status: Done
Mode: Managed
Test: integration
Regression: none

Compartment, network, and vault are provisioned together and tracked in a single shared oci_scaffold state file that persists across sprints. Compute instance and block volume use a separate oci_scaffold state file that is created and torn down per test run.

Backlog Items:

* BV4DB-1. Compartment for all project resources
* BV4DB-2. Public network for compute access over SSH
* BV4DB-3. Shared SSH key stored in OCI Vault for compute access
* BV4DB-4. Block volume ensure and teardown scripts in oci_scaffold
* BV4DB-5. Compute instance with block volume and basic fio test
* BV4DB-6. fio performance report for block volume

## Sprint 2 - Maximum-performance block volume benchmark

Status: Done
Mode: managed
Test: integration
Regression: integration

Sprint 2 reuses the shared compartment, network, and vault created in Sprint 1. The benchmark compute instance and block volume remain ephemeral and are torn down automatically after the benchmark run.

Backlog Items:

* BV4DB-7. Maximum-performance block volume configuration benchmark

## Sprint 3 - Mixed 8k fio profile on Sprint 2 topology

Status: Done
Mode: managed
Test: integration
Regression: integration

Sprint 3 reuses the Sprint 2 compute and block volume configuration profile, but executes fio from a workload profile file. The sprint starts with the `60`-second smoke run and keeps the `15`-minute integration run as the second execution level on the same topology.

Backlog Items:

* BV4DB-8. Mixed 8k database-oriented benchmark profile on Sprint 2 topology

## Sprint 4 - Oracle-style block volume layout with concurrent workload

Status: Failed
Mode: managed
Test: integration
Regression: integration

Sprint 4 provisions a compute instance with five block volumes arranged as three storage classes: two UHP volumes striped into a data LV at `/u02/oradata`, two HP volumes striped into a redo LV at `/u03/redo`, and one balanced volume at `/u04/fra`. Guest LVM striping is configured on the instance using the OCI consistent device paths. The sprint supports two execution levels — a `60`-second smoke run and a `15`-minute integration run — using the same prescribed fio profile file.

Backlog Items:

* BV4DB-9. Minimal Oracle-style block volume layout with concurrent workload validation

## Sprint 5 - Oracle-style layout rerun with corrected fio job reporting

Status: Done
Mode: YOLO
Test: integration
Regression: integration

Sprint 5 reexecutes the Sprint 4 Oracle-style storage layout with a corrected fio workload profile that disables grouped reporting and uses the revised workload parameters for data, redo, and FRA jobs. The sprint reuses the Sprint 4 topology, analysis approach, validation approach, and teardown flow, and changes only the fio job description file so the rerun produces valid per-job fio result artifacts.

Backlog Items:

* BV4DB-10. Reexecute Oracle-style layout with corrected fio job reporting

## Sprint 6 - Sync oci_scaffold branch and validate block volume ensure

Status: Done
Mode: YOLO
Test: smoke
Regression: none

Sprint 6 merges `oci_scaffold/main` into the `oci_scaffold/oci_bv4db_arch` branch and runs a minimal smoke validation to confirm that `ensure-blockvolume.sh` still works from the merged scaffold branch state. The smoke is intentionally trivial and validates only ephemeral compute plus block volume ensure/attach/teardown behavior.

Backlog Items:

* BV4DB-11. Sync oci_scaffold branch with upstream main and smoke-validate block volume ensure

## Sprint 7 - Oracle block volume sizing and scalability guide

Status: Done
Mode: YOLO
Test: none
Regression: none

Sprint 7 is documentation-only work. It consolidates the practical outcomes of earlier sprints into an operator-oriented guide for configuring OCI block volumes for Oracle Database at entry-level, mid-level, and top-end scales, without running any live infrastructure or benchmarks.

Backlog Items:

* BV4DB-12. Theoretical Oracle block volume sizing and scalability guide

## Sprint 8 - Sprint 5 fio job on a single UHP block volume

Status: Done
Mode: YOLO
Test: integration
Regression: integration

Sprint 8 reuses the Sprint 5 Oracle fio workload definition, but executes it on a simplified topology built on a single UHP block volume. The goal is to compare a one-volume high-performance layout against the split-domain Oracle-style layout from Sprint 5 using the same workload intent.

Backlog Items:

* BV4DB-15. Run the Sprint 5 Oracle fio job on a single UHP block volume

## Sprint 9 - Oracle fio runner cleanup and 4 KB redo variants

Status: Done
Mode: YOLO
Test: integration
Regression: integration

Sprint 9 consolidates the Oracle fio execution path and then reexecutes the validated Oracle-style workload with one focused workload change: the redo job uses `4k` block size instead of `512` bytes. The sprint runs both topologies already established by the project: the single-UHP variant from Sprint 8 and the separated-volume variant from Sprint 5.

Backlog Items:

* BV4DB-16. Unify and polish Oracle fio testing scripts
* BV4DB-17. Single-volume Oracle-style test with 4 KB redo
* BV4DB-18. Multi-volume Oracle-style test with 4 KB redo
* BV4DB-19. Practical Oracle block volume baseline guide from Sprint 9

## Sprint 10 - OCI performance-tier Oracle comparison

Status: Done
Mode: YOLO
Test: integration
Regression: integration

Sprint 10 extends the current Oracle baseline from UHP into OCI performance-tier comparison work. It covers Balanced and Higher Performance tiers in both single-volume and separated-volume Oracle layouts, and adds explicit compute sizing analysis so CPU shape and OCPU count are matched to the targeted volume performance level.

Backlog Items:

* BV4DB-20. Size compute CPU to the required block volume performance level
* BV4DB-25. Single-volume Oracle-style test on Lower Cost block volume
* BV4DB-21. Single-volume Oracle-style test on Balanced block volume
* BV4DB-22. Multi-volume Oracle-style test on Balanced block volumes
* BV4DB-23. Single-volume and multi-volume Oracle-style tests on Higher Performance block volumes
* BV4DB-24. OCI performance-tier comparison analysis for Oracle layouts

## Sprint 11 - OCI metrics operate command and report

Status: Done
Mode: YOLO
Test: integration
Regression: integration

Sprint 11 introduces an `operate-*` command path in `oci_scaffold` and uses it to collect OCI metrics for compute, block volume, and network resources after a benchmark run over a defined time window. The sprint executes a `5`-minute Oracle-style load to produce real metrics and renders the collected data into a report artifact.

Backlog Items:

* BV4DB-29. Configurable OCI metrics collection and post-test report generation
* BV4DB-30. Introduce operate-* lifecycle commands in oci_scaffold
* BV4DB-31. Refactor operate-metrics into generic shared logic and resource-specific adapters

## Sprint 12 - HTML metrics report on multi-volume benchmark

Status: Done
Mode: YOLO
Test: integration
Regression: integration

Sprint 12 extends the working `operate-*` metrics path from Sprint 11 to generate a real HTML dashboard with charts in addition to the Markdown report. The sprint executes a short Oracle-style multi-volume run so the report is driven by fresh compute, block volume, and network metrics over a benchmark window that includes more than one block volume resource.

Backlog Items:

* BV4DB-32. Generate charted HTML metrics report with OCI-style presentation
