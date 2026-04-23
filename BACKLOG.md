# oci_bv4db_arch

version: 1

OCI Block Volume for Database Architecture project.

## Backlog

Project aim is to deliver all the features listed in a below Backlog. Backlog Items selected for implementation are added to iterations detailed in `PLAN.md`. Full list of Backlog Items presents general direction and aim for this project.

### BV4DB-1. Compartment for all project resources

All OCI resources created in this project must be isolated in a dedicated compartment to simplify cost tracking, access control, and teardown. The compartment is provisioned using oci_scaffold at path `/oci_bv4db_arch` and is created before any other resource in the project.

Test: all project resources are created inside the `/oci_bv4db_arch` compartment.

### BV4DB-2. Public network for compute access over SSH

A reusable OCI network environment is needed to host compute instances accessible directly over SSH without bastion. The network consists of a VCN, internet gateway, route table, public subnet, and security list permitting SSH ingress. It is provisioned once using oci_scaffold and reused across all subsequent sprints without being torn down between them.

Test: an instance placed in the subnet is reachable via SSH on its public IP from the internet.

### BV4DB-3. Shared SSH key stored in OCI Vault for compute access

A single SSH key pair is needed that is shared across all compute instances in the project so that access does not depend on per-instance generated keys. The private key is stored as a secret in a software-defined OCI Vault provisioned by oci_scaffold, and retrieved at instance creation time to avoid storing key material on disk long-term.

Test: an instance is reachable via SSH using the key retrieved from the vault secret.

### BV4DB-4. Block volume ensure and teardown scripts in oci_scaffold

oci_scaffold has no support for OCI block volumes, making it impossible to provision and clean up block volumes as part of a scripted cycle. Add `ensure-blockvolume.sh` and `teardown-blockvolume.sh` to oci_scaffold following the same idempotent adopt-or-create pattern used by other ensure scripts. Work is done in a dedicated branch `oci_bv4db_arch` in the oci_scaffold submodule and merged to main when complete.

Test: a block volume is created, attached to a compute instance, and deleted by the teardown script, with state recorded correctly in the state file.

### BV4DB-5. Compute instance with block volume and basic fio test

An AMD64 OCI compute instance with a single attached block volume is needed as the baseline environment for block volume performance research. The instance uses the network from BV4DB-2 and the SSH key from BV4DB-3, is reachable over SSH via a public IP without bastion, and a basic fio benchmark must run against the block volume to confirm it is usable. Compute and block volume are provisioned using oci_scaffold and cleaned up after the test while the network remains intact. Operator may request to keep the infrastructure.

Test: fio completes without error on the attached block volume and the instance is reachable via SSH on its public IP.

### BV4DB-6. fio performance report for block volume

A structured performance report produced by fio is needed as the primary deliverable for block volume benchmarking. The report must cover sequential and random I/O patterns at representative block sizes and capture IOPS, throughput, and latency so that results can be compared across different block volume configurations in later sprints.

Test: fio produces a report file containing IOPS, throughput, and latency metrics for both sequential and random I/O workloads.

### BV4DB-7. Maximum-performance block volume configuration benchmark

A higher-performance benchmark configuration is needed to measure the best block volume performance this architecture can deliver, not just the baseline from Sprint 1. The benchmark must use a compute instance sized for maximum block volume performance, a block volume configured with the maximum supported VPU setting, and the required number of network paths so the storage path is not artificially constrained. For Sprint 2, the fio run uses a 60-second total measurement window and its results must be analyzed into a comparable report. The compute and block volume may be torn down automatically after the benchmark because OCI metrics remain available for terminated resources.

Test: fio completes on the maximum-performance configuration, produces an analyzed report comparable to the Sprint 1 baseline, and tears down the benchmark compute and block volume automatically after the run.

### BV4DB-8. Mixed 8k database-oriented benchmark profile on Sprint 2 topology

A follow-on benchmark is needed that reuses the Sprint 2 maximum-performance compute and block volume configuration but runs fio from a workload profile file instead of embedding the workload in command-line arguments. The fio workload profile must be represented as a file using exactly the following content, with adjustments allowed only where needed for the target instance and block volume environment such as mount point or similar deployment-specific path details:

```ini
[global]
ioengine=libaio
direct=1
time_based=1
runtime=450
ramp_time=30
group_reporting=1

filename=/mnt/bv/testfile-perf
size=64G

# concurrency model
numjobs=4
iodepth=32

# avoid cache / reuse artifacts
invalidate=1
fsync_on_close=1

[mixed-8k]
rw=randrw
rwmixread=70
bs=8k
```

This backlog item requires two execution levels on the same fio profile file: a smoke test for `60` seconds and an integration test for `15` minutes, both producing raw JSON results and an analyzed report while reusing the Sprint 2 compute and block volume sizing.

Test: the mixed `8k` fio profile completes successfully in both `60`-second smoke and `15`-minute integration modes on the Sprint 2 topology, writes raw JSON report artifacts for each mode, and produces analysis that can be compared to the existing Sprint 2 result set.

### BV4DB-9. Minimal Oracle-style block volume layout with concurrent workload validation

A compute instance with five block volumes arranged as three independent storage classes is needed to represent a realistic Oracle Database host: two volumes striped for data files, two volumes striped for redo logs, and one volume for the Fast Recovery Area. Each storage class must be reachable at a dedicated mount point and exercised by a concurrent fio workload to confirm that data, redo, and FRA I/O are isolated to their respective volume groups. The fio job profile covering all three workloads is prescribed in the sprint design and must be committed as a deliverable for result reproducibility. The environment reuses shared infra from Sprint 1 and is torn down after the benchmark.

Test: all three fio workloads execute concurrently, produce JSON output, and device-level utilization confirms I/O is distributed across the correct underlying block volumes for each storage class.

### BV4DB-10. Reexecute Oracle-style layout with corrected fio job reporting

Sprint 4 must be reexecuted with a corrected fio workload profile because `group_reporting=1` invalidated the per-job fio reporting. The reexecution keeps the Sprint 4 infrastructure topology and mount layout, but fio must use exactly the following workload profile content as a committed file:

```ini
[global]
ioengine=libaio
direct=1
time_based=1
runtime=600
ramp_time=60
group_reporting=0
invalidate=1

[data-8k]
filename=/u02/oradata/testfile
size=32G
rw=randrw
rwmixread=70
bs=8k
numjobs=4
iodepth=16

[redo]
filename=/u03/redo/testfile
size=4G
rw=write
bs=512
numjobs=1
iodepth=1
fdatasync=1

[fra-1m]
filename=/u04/fra/testfile
size=16G
rw=readwrite
bs=1M
numjobs=1
iodepth=8
rate=120M
```

Test: the corrected fio profile produces distinct per-job results for `data-8k`, `redo`, and `fra-1m`, and the rerun confirms the intended Oracle-style storage-class isolation with valid raw JSON artifacts and updated analysis.

### BV4DB-11. Sync oci_scaffold branch with upstream main and smoke-validate block volume ensure

The project branch `oci_scaffold/oci_bv4db_arch` must be synchronized with `oci_scaffold/main` because the block volume resource work has been adopted upstream. The sync is performed by merging `main` into the project branch in the submodule, then executing a trivial smoke validation against the merged branch state to confirm that `ensure-blockvolume.sh` still works in this project after the upstream update. After the sync, further scaffold changes for this project continue on the `oci_bv4db_arch` branch.

Test: after merging `oci_scaffold/main` into `oci_scaffold/oci_bv4db_arch`, a smoke run provisions ephemeral compute, successfully runs `ensure-blockvolume.sh`, records an attached block volume in state, and tears the resources down cleanly.

### BV4DB-12. Theoretical Oracle block volume sizing and scalability guide

A documentation-only analysis is needed that explains how OCI block volumes should be configured for Oracle Database at entry-level, mid-level, and top-end deployments. The document is purely theoretical and uses no benchmark runs or live resource execution; its value is to organize the work done so far into practical configuration guidance and explain how sizing and layout change across different scalability scenarios. The outcome is a reference document for planning future implementation work.

Test: a written analysis exists that covers entry-level, mid-level, and top-end Oracle storage layouts and explains scalability tradeoffs for multiple deployment scenarios without requiring any live execution.

### BV4DB-13. Follow-on backlog derived from Oracle storage analysis

The theoretical Oracle storage guide must produce a concrete next-step roadmap rather than remain a standalone document. New backlog items are needed to capture the implementation, validation, and benchmarking work implied by the analysis so that the project can move from guidance into executable follow-up sprints. This backlog expansion is derived from the analysis and ordered as actionable future work.

Test: the Oracle storage analysis results in a series of new backlog items that cover the main follow-on work areas identified by the document.

### BV4DB-14. Analysis of oci_scaffold lifecycle command extensions for managed resources

The project needs a design-level analysis of whether oci_scaffold should grow lifecycle command families beyond `ensure*` and `teardown*`, especially an `operate*` class and possibly `update*` commands for existing resources. The analysis must consider how such commands would behave for resources that are project-created versus adopted, with specific attention to whether update-style behavior should target explicitly created resources more readily than adopted ones. This is still exploratory work and should frame options, constraints, and resulting backlog implications rather than implementation.

Test: a written analysis exists that evaluates `operate*` and `update*` lifecycle command directions for oci_scaffold and distinguishes expectations for created versus adopted resources.

### BV4DB-15. Run the Sprint 5 Oracle fio job on a single UHP block volume

The project needs a direct comparison between the Sprint 5 Oracle fio workload and a simpler layout that uses a single Ultra High Performance block volume instead of separate `DATA`, `REDO`, and `FRA` domains. This benchmark is needed to show what is gained and lost when the Oracle-style fio job is forced onto one high-performance volume, using the same practical workload shape as Sprint 5. The outcome is a benchmark and analysis set that can be compared directly against the Sprint 5 Oracle-style split-volume results.

Test: the Sprint 5 fio job is executed successfully against a single UHP block volume, writes raw result artifacts, and produces an analysis that compares the single-volume result with the Sprint 5 split-domain layout.

### BV4DB-16. Unify and polish Oracle fio testing scripts

The Oracle fio execution path has evolved over multiple sprints and now needs consolidation. The runner and wrapper scripts should absorb the learnings from the executed sprints so that single-volume and multi-volume Oracle-style tests reuse the same stable logic for UHP attachment handling, guest layout creation, fio execution, artifact collection, and teardown. The outcome is a cleaner script set that reduces sprint-specific duplication and makes the next Oracle fio variants easier to execute and compare.

Test: the Oracle fio runner path supports both the separated-volume and single-UHP variants through the same stable execution flow, and the new sprint wrappers use that shared flow successfully.

### BV4DB-17. Single-volume Oracle-style test with 4 KB redo

The project needs the Sprint 8 single-UHP comparison rerun with only one workload change: the redo job uses `4k` block size instead of `512` bytes. Everything else stays the same as Sprint 8: same compute shape, same single UHP volume, same guest filesystem layout, same LVM structure, and the same non-redo fio jobs. The outcome is a direct single-volume Oracle-style result set with a more modern redo block-size proxy.

Test: the single-UHP Oracle-style run completes with the `4k` redo fio profile, writes raw result artifacts, and produces analysis that can be compared with Sprint 8.

### BV4DB-18. Multi-volume Oracle-style test with 4 KB redo

The project needs the Sprint 5 separated-volume Oracle-style test rerun with only one workload change: the redo job uses `4k` block size instead of `512` bytes. Everything else stays the same as Sprint 5: same compute shape, same multi-volume topology, same guest filesystem layout, same LVM structure, and the same non-redo fio jobs. The outcome is a direct separated-volume Oracle-style result set with a `4k` redo profile that can be compared with Sprint 5 and with the single-UHP `4k` redo variant.

Test: the multi-volume Oracle-style run completes with the `4k` redo fio profile, writes raw result artifacts, and produces analysis that can be compared with Sprint 5 and the single-UHP `4k` redo run.

### BV4DB-19. Practical Oracle block volume baseline guide from Sprint 9

The repository needs a current practical guide that uses Sprint 9 as the active Oracle baseline instead of the earlier documentation sprint. This document should summarize only the OCI layouts that matter operationally now: entry-level block volume, single UHP volume, and multiple volumes with storage-domain separation, using the Sprint 9 `4k` redo findings as the primary Oracle comparison point. The outcome is a current-sprint guidance document aligned with the latest validated benchmark baseline.

Test: a Sprint 9 documentation artifact exists that describes the three practical OCI Oracle layouts and compares them using the Sprint 9 single-UHP and separated-volume `4k` redo results.

### BV4DB-20. Size compute CPU to the required block volume performance level

The project needs an explicit analysis and execution rule for sizing compute shape and OCPU count according to the targeted OCI block volume performance level. Current Oracle fio runs use a fixed high-end compute shape, which is useful for isolating storage behavior, but it does not yet show the minimum or appropriate CPU sizing needed to realize the intended performance of Lower Cost, Balanced, Higher Performance, and Ultra High Performance block volume configurations. The outcome is backlog-driven work that treats compute sizing as part of the OCI performance design, not as a constant.

Test: the backlog and future sprint design can state which compute shape and OCPU range is required for a given OCI block volume performance level, rather than assuming one fixed compute profile for all volume tiers.

### BV4DB-21. Single-volume Oracle-style test on Balanced block volume

The project needs the current single-volume Oracle baseline rerun on OCI Balanced block volume performance level. The workload shape should stay aligned with the current Oracle baseline, while the storage tier changes from UHP to Balanced. The outcome is a directly comparable single-volume result for the Balanced tier.

Test: the single-volume Oracle-style fio run completes on the Balanced performance tier, writes raw result artifacts, and produces analysis comparable with the UHP baseline.

### BV4DB-22. Multi-volume Oracle-style test on Balanced block volumes

The project needs the current separated-volume Oracle baseline rerun on OCI Balanced block volume performance level. The workload shape should stay aligned with the current Oracle baseline, while the block volume tier changes from UHP/HP mix to Balanced where applicable for the comparison objective. The outcome is a directly comparable separated-volume result for the Balanced tier.

Test: the multi-volume Oracle-style fio run completes on the Balanced performance tier, writes raw result artifacts, and produces analysis comparable with the current multi-volume baseline.

### BV4DB-23. Single-volume and multi-volume Oracle-style tests on Higher Performance block volumes

The project needs the current Oracle baseline executed on OCI Higher Performance block volume tier in both topologies: single volume and separated volumes. This fills the gap between Balanced and UHP and allows the repository to compare OCI performance levels using the same Oracle workload model.

Test: single-volume and separated-volume Oracle-style fio runs complete on the Higher Performance tier, write raw result artifacts, and produce analysis comparable with the current UHP baseline.

### BV4DB-24. OCI performance-tier comparison analysis for Oracle layouts

The project needs an analysis artifact that compares OCI Lower Cost baseline evidence, Balanced, Higher Performance, and Ultra High Performance runs across both single-volume and separated-volume Oracle layouts. This analysis should explicitly relate observed storage behavior to the OCI performance-tier model and call out when compute shape or OCPU count becomes part of the limiting factor.

Test: a written comparison exists that explains the observed differences between OCI performance tiers for Oracle-style layouts and ties those results to the compute-sizing guidance.

### BV4DB-25. Single-volume Oracle-style test on Lower Cost block volume

The project needs the current single-volume Oracle baseline rerun on OCI Lower Cost block volume performance level. This closes the OCI tier coverage from the Oracle point of view by providing a directly comparable Oracle-style result at the lowest documented OCI performance level. The fio workload shape should stay aligned with the current Oracle baseline, while the storage tier changes from UHP to Lower Cost.

Test: the single-volume Oracle-style fio run completes on the Lower Cost performance tier, writes raw result artifacts, and produces analysis comparable with the UHP, Higher Performance, and Balanced single-volume runs.

### BV4DB-26. Moderate OLTP Oracle-style fio profile

The project needs a lighter Oracle-style fio profile that represents a more moderate OLTP operating point than the current high-stress baseline. This profile should keep the same Oracle storage-domain model (`DATA`, `REDO`, `FRA`) but reduce the `DATA` pressure so the benchmark better represents a system that is busy yet not intentionally overdriven. The outcome is a second reusable Oracle comparison profile for operational sizing and not only for topology stress.

Test: a moderate OLTP Oracle-style fio profile exists, runs successfully on the established single-volume and multi-volume topologies, and produces artifacts that can be compared with the current stress baseline.

### BV4DB-27. Backup-window Oracle-style fio profile

The project needs a benchmark profile that represents a database under active backup or archive load rather than maximal foreground database pressure. This profile should retain Oracle-style concurrency but shift the emphasis toward `FRA` activity so the repository can show how backup-window traffic interacts with `DATA` and `REDO` in single-volume and separated-volume layouts. The outcome is a practical benchmark profile for RMAN/FRA-heavy operating windows.

Test: a backup-window Oracle-style fio profile exists, runs successfully on the established topologies, and produces artifacts that show how `FRA`-heavy load affects `DATA` and `REDO`.

### BV4DB-28. Commit-sensitive Oracle-style fio profile

The project needs a benchmark profile that focuses more explicitly on commit-path sensitivity by keeping `REDO` as the dominant concern while reducing surrounding `DATA` and `FRA` pressure. This profile should help distinguish layouts that are acceptable for commit-sensitive workloads from layouts that collapse mainly under combined background pressure. The outcome is a reusable Oracle-style benchmark profile centered on synchronous redo behavior and commit-path stability.

Test: a commit-sensitive Oracle-style fio profile exists, runs successfully on the established topologies, and produces artifacts that highlight synchronous `REDO` behavior under lighter background load.

### BV4DB-29. Configurable OCI metrics collection and post-test report generation

The project needs a reusable OCI metrics collection capability that runs after benchmark execution for a defined test window and gathers metrics for compute, block volume, and network resources. The collected metrics must be configurable by resource class through a collection definition file so different metric sets can be requested for compute instances, block volumes, and network-facing resources without hardcoding the selection in scripts. The outcome is a generated report in Markdown or HTML, with HTML allowed to be dynamic when built from a normal library stack; Redwood CSS styling aligned with the OCI Console would add extra value if practical.

Test: a configurable metrics collection definition can drive post-test collection for compute, block volume, and network resources over a requested time window, and the collected data is rendered into a Markdown or HTML report artifact.

### BV4DB-30. Introduce operate-* lifecycle commands in oci_scaffold

The project needs an `operate-*` class of commands in `oci_scaffold` for safe runtime actions on existing resources that are neither creation/adoption (`ensure-*`) nor deletion (`teardown-*`). The first target is operational inspection and report generation for metrics, but the command family should be defined cleanly enough to support future read-only or low-risk runtime operations on compute, block volume, and network resources. The outcome is an explicit lifecycle class in `oci_scaffold` with at least one implemented `operate-*` command and usage patterns that fit the existing state-file model.

Test: `oci_scaffold` exposes a working `operate-*` command path for an implemented operational action, and that action can run successfully against resources described in scaffold state without requiring resource creation or teardown.

### BV4DB-31. Refactor operate-metrics into generic shared logic and resource-specific adapters

The current `operate-metrics.sh` proves the `operate-*` model, but it still contains resource-specific knowledge about compute, block volume, and network resources. The project needs that implementation refactored so generic metrics collection, query execution, and report assembly live in shared code, while resource-specific resolution and resource-class behavior are kept in resource-level adapter files. The outcome is a cleaner `operate-*` design that can grow beyond the first metrics implementation without turning one script into a hardcoded dispatcher.

Test: metrics collection still works after the refactor, but resource-specific logic is moved out of the main generic operator into resource-level files or adapters.

### BV4DB-32. Generate charted HTML metrics report with OCI-style presentation

The project needs the metrics reporting capability completed to the originally intended level: a real report, not only a Markdown table dump. The next step is an HTML report with charts for compute, block volume, and network metrics over the selected test window, optionally using a normal client-side charting library and Redwood-style presentation aligned with the OCI Console when practical. The outcome is a visually useful post-test report artifact that lets the operator inspect metric trends rather than only summary tables.

Test: post-test metrics collection produces an HTML report with charts for the selected metrics and resources, and the report renders the collected monitoring data over the requested time window.

### BV4DB-33. Reconcile OCI Monitoring metrics with fio and guest iostat

The current metrics collection proves that OCI Monitoring data can be collected and rendered after a benchmark window, but it does not yet prove that those provider-side metrics quantitatively align with the benchmark-side observations. The project needs an explicit analysis and validation pass that compares OCI Monitoring throughput and operation metrics with fio logical-volume totals and guest `iostat` observations, explains the expected deltas caused by aggregation windows and semantic differences, and defines what level of mismatch is still acceptable. The outcome is a documented reconciliation method that makes the metrics report analytically trustworthy rather than only operationally useful.

Test: a written reconciliation exists for at least one executed benchmark window, comparing OCI Monitoring, fio, and guest `iostat` data and explaining the observed differences with stated acceptance criteria.

### BV4DB-34. Fully automated Oracle Database Free installation on benchmark host

The project needs a repeatable way to prepare a benchmark compute host with Oracle Database Free on the same Oracle Linux platform already used for the storage tests. Manual installation would make database-oriented benchmarking slow to rerun and hard to compare across sprints. The outcome is a host that can be prepared from scratch without interactive steps and then reused for automated database benchmark execution.

Test: a fresh benchmark host can be prepared with Oracle Database Free without interactive prompts, and the database starts successfully after the automated setup completes.

### BV4DB-35. Automated Oracle Database Free storage layout for OCI block volume tests

The project needs the Oracle Database Free environment to place database storage in a controlled layout that matches the OCI block-volume topologies being studied. Without an explicit automated layout, database benchmark results would not be comparable with the single-volume and separated-volume storage experiments already in the repository. The outcome is a repeatable database storage placement that can be recreated for benchmark runs and compared across layouts.

Test: an automated database setup creates a valid Oracle Database Free storage layout on the intended block-volume-backed filesystems, and the database can open and use that layout successfully.

### BV4DB-36. Automated Oracle Database Free performance workload execution

The project needs a database-level benchmark flow that runs automatically against Oracle Database Free and produces durable result artifacts. This is needed to move from synthetic storage-only evidence toward workload evidence that is closer to real database behavior while still remaining repeatable in CI-like execution. The outcome is an automated benchmark run that can be executed repeatedly and compared with existing storage-oriented results.

Test: an Oracle Database Free workload can be started automatically, runs to completion without manual intervention, and produces benchmark artifacts suitable for comparison between OCI storage layouts.

### BV4DB-37. Compare Oracle Database Free benchmark evidence with fio baselines

The repository needs an analysis that explains how Oracle Database Free benchmark observations relate to the existing fio-based OCI storage baselines. Without that comparison, the project would accumulate two independent result streams without a clear statement of what database-level evidence adds beyond storage-level measurements. The outcome is a written comparison that links Oracle Database Free findings to the current fio baselines and explains where they align or diverge.

Test: a written analysis exists that compares Oracle Database Free benchmark results with the current fio baselines and explains the main similarities, differences, and limits of each method.

### BV4DB-38. Automated AWR snapshot window capture for database benchmarks

The project needs an automated way to bracket each Oracle Database Free benchmark run with a defined database diagnostics window. Without explicit snapshot capture around the workload, later performance analysis would rely on approximate timing and would be harder to compare across repeated runs. The outcome is a repeatable benchmark procedure that records the intended diagnostic interval for each database test.

Test: an Oracle Database Free benchmark run records a begin and end diagnostics window automatically, and the captured window is saved as part of the benchmark artifacts.

### BV4DB-39. Automated AWR report export and archival for benchmark runs

The project needs each Oracle Database Free benchmark to produce a durable database-side performance report that can be reviewed after the host is torn down. Without archived AWR evidence, the project would keep workload timing but lose the main database diagnostic artifact needed for later tuning and comparison work. The outcome is a benchmark artifact set that includes an exported AWR report for each captured run.

Test: a completed Oracle Database Free benchmark run produces an archived AWR report artifact that can be opened and reviewed after the benchmark environment is removed.

### BV4DB-40. Correlate AWR evidence with OCI and guest benchmark metrics

The project needs an analysis layer that connects Oracle Database diagnostics with the OCI metrics and guest-level measurements already collected in this repository. Without that correlation, AWR would remain an isolated artifact instead of helping explain storage waits, throughput ceilings, and database-visible bottlenecks. The outcome is a written comparison that ties AWR findings to workload timing, guest measurements, and OCI monitoring evidence for the same run window.

Test: a written analysis exists for at least one database benchmark run that compares AWR findings with OCI metrics and guest-level observations from the same test window.

### BV4DB-41. Swingbench as the standard Oracle Database Free load generator

The project needs one explicit database load tool so Oracle Database Free benchmarks are repeatable across runs and sprints. Swingbench is the primary tool because it is Oracle-focused and better aligned with database-visible performance analysis, while HammerDB remains an acceptable fallback if Swingbench proves unsuitable in the target environment. The outcome is a standard benchmark harness choice that keeps future database tests comparable.

Test: Oracle Database Free benchmark execution uses Swingbench as the standard load generator, or documents and uses HammerDB only when Swingbench is shown unsuitable for the required benchmark scenario.
