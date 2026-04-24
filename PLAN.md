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

## Sprint 13 - Oracle Database Free benchmark harness foundation

Status: Done
Mode: YOLO
Test: integration
Regression: integration

Sprint 13 establishes the database-level benchmark harness on top of the existing Oracle Linux and OCI block volume environment. The sprint automates Oracle Database Free installation and prepares a repeatable database storage layout aligned with the project storage topologies, without yet standardizing the long-term workload tool choice. At this stage use minimal required shape with single block volume.

Backlog Items:

* BV4DB-34. Fully automated Oracle Database Free installation on benchmark host
* BV4DB-35. Automated Oracle Database Free storage layout for OCI block volume tests
  
## Sprint 14 - Oracle Database Free workload execution with AWR capture

Status: Done
Mode: yolo
Test: integration
Regression: integration

Sprint 14 turns the prepared Oracle Database Free host into a real benchmark target. The sprint automates the database workload run itself and captures the database diagnostics window and exported AWR artifacts needed for later performance analysis.

Backlog Items:

* BV4DB-36. Automated Oracle Database Free performance workload execution
* BV4DB-38. Automated AWR snapshot window capture for database benchmarks
* BV4DB-39. Automated AWR report export and archival for benchmark runs

## Sprint 15 - Validate FIO and database-level test metrics accuracy

Status: Done
Mode: managed
Test: integration
Regression: integration

Sprint 15 validates that the FIO storage-level metrics and Oracle Database Free workload metrics measure the same underlying block volume behavior accurately. To produce a repeatable and comparable database-side signal, the sprint standardizes Swingbench as the primary database load generator (with HammerDB as the documented fallback), moves the workload definition into a project-owned configuration file, and renders the benchmark result as a standalone HTML artifact. The combination of archived FIO evidence and a standardized Swingbench run with AWR capture provides the two consistent measurement planes needed for cross-level metric validation in later sprints.

Backlog Items:

* BV4DB-41. Swingbench as the standard Oracle Database Free load generator
* BV4DB-42. HTML presentation for Swingbench benchmark results
* BV4DB-43. Project-level Swingbench workload configuration file

## Sprint 16 - Oracle Database benchmark correlation and comparative reporting

Status: Failed
Mode: yolo
Test: integration
Regression: integration

Sprint 16 closes the first database-benchmark loop by comparing Oracle Database Free evidence with the storage-oriented evidence already produced by the repository. The sprint correlates AWR, OCI metrics, guest observations, and the existing fio baselines so the project can explain what database-level benchmarking adds beyond synthetic storage tests.

Retrospective failure note:
Sprint 16 overlooked a workload-level correlation failure that was already visible in the archived Sprint 17 evidence. During Swingbench, guest `iostat` did not sustain the expected data-volume traffic on the attached block volumes, the archived OCI metrics for attached block volumes were nearly all zero, and the boot device showed strong activity. Sprint 16 should have treated that contradiction as invalid correlation evidence instead of accepting the dataset.

Backlog Items:

* BV4DB-37. Compare Oracle Database Free benchmark evidence with fio baselines
* BV4DB-40. Correlate AWR evidence with OCI and guest benchmark metrics

## Sprint 17 - Consolidated Oracle multi-volume UHP benchmark baseline

Status: Done
Mode: YOLO
Test: integration
Regression: integration

Sprint 17 is the first fully automated summary sprint that consolidates the project benchmark path on one stronger end-to-end topology: a UHP-sized compute instance with multiple OCI block volumes arranged in the established Oracle-style layout. The sprint runs two benchmark phases on that topology. Phase 1 executes the Oracle-style `fio` workload and collects `fio`, guest `iostat`, and OCI Monitoring evidence for the storage-stress window. Phase 2 executes the standardized Oracle Database Free `Swingbench` workload and collects Swingbench artifacts, guest `iostat`, OCI Monitoring evidence, and AWR artifacts for the database-stress window. The sprint must reuse the reporting assets already established by the project, including OCI metrics collection plus Markdown and HTML reporting, and it must finish with operator-consumable summary outputs rather than only low-level artifacts.

Expected completion outputs:

* HTML report for the `fio` phase
* HTML report for the `Swingbench` phase
* HTML AWR report for the Swingbench phase
* Markdown/HTML OCI metrics reporting for both phases
* Integrated summary artifact that explains what this consolidated benchmark proves in the context of the project so far

Backlog Items:

* BV4DB-44. Consolidated Oracle multi-volume UHP benchmark with FIO and Swingbench evidence
* BV4DB-45. Integrated benchmark summary report for the project baseline

## Sprint 18 - Nine-hundred-second mirror rerun of Sprint 17

Status: Done
Mode: YOLO
Test: integration
Regression: integration

Sprint 18 is intentionally a mirror rerun of Sprint 17 and must not introduce a new topology, a new workload model, or a new reporting branch. The sprint reuses the same Oracle-style multi-volume UHP benchmark flow, the same `fio` phase, the same Oracle Database Free `Swingbench` phase, the same guest `iostat` capture, the same OCI Monitoring collection, the same HTML report generation, and the same AWR export path. The only intended change is benchmark duration: both phases run for `900` seconds so the result becomes a benchmark-quality evidence set rather than only an automation-validation run.

Expected completion outputs:

* HTML report for the `fio` phase
* HTML report for the `Swingbench` phase
* HTML AWR report for the Swingbench phase
* Markdown/HTML OCI metrics reporting for both phases
* Integrated summary artifact in the same style as Sprint 17
* Swingbench-phase OCI block-volume metrics with non-trivial values

Backlog Items:

* BV4DB-46. Nine-hundred-second mirror rerun of the Sprint 17 consolidated benchmark

## Sprint 19 - Benchmark outcome analysis and acceptance criteria

Status: Done
Mode: managed
Test: integration
Regression: integration

Sprint 19 implemented a data science correlation framework to validate benchmark evidence across observation layers (Guest I/O, OCI Block Volume metrics, Swingbench TPS). The framework applies Pearson/Spearman correlation and Quadrant Correlation Matrix analysis to detect cross-layer inconsistencies and score evidence quality.

Results summary:

* Sprint 17 FIO: 65/100 (C) INCONCLUSIVE - Low correlation due to short test duration
* Sprint 17 Swingbench: 10/100 (F) INCONCLUSIVE - Critical anomaly: OCI metrics show 0 MB/s
* Sprint 18 FIO: 100/100 (A) PASS - Excellent correlation (r=0.926)
* Sprint 18 Swingbench: 75/100 (B) PASS - Acceptable quality despite low correlation

Backlog Items:

* BV4DB-48. Analyze benchmark and test outcomes for evidence quality, contradictions, and conclusions

## Sprint 20 - UHP multipath diagnostics and performance A/B (multipath vs single-path)

Status: Done
Mode: managed
Test: integration
Regression: integration

Sprint 20 provisions a compute instance with a **single UHP block volume** and runs two controlled experiments:

* multipath-enabled iSCSI attachment (baseline best practice)
* single-path iSCSI attachment (intentional limitation)

The sprint focuses on:

* collecting multipath diagnostic evidence and recommended tooling
* measuring performance differences (throughput/IOPS/latency) between the two modes

Backlog Items:

* BV4DB-50. UHP multipath diagnostics sandbox host
* BV4DB-51. FIO benchmark: multipath vs single-path iSCSI on UHP
