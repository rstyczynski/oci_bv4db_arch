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

The project needs the Oracle Database Free environment to place database storage in a controlled layout that matches the OCI block-volume topologies being studied. Without an explicit automated layout, database benchmark results would not be comparable with the single-volume and separated-volume storage experiments already in the repository. The outcome is a repeatable database storage placement that can be recreated for benchmark runs and compared across layouts. Layout must be compatible with former sprints single / multiple block volumes approach.

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

### BV4DB-42. HTML presentation for Swingbench benchmark results

The project needs a durable human-readable HTML report for Swingbench benchmark runs so the result can be reviewed quickly without reading raw XML, log output, or JSON exports. Without this presentation layer, Sprint 15 still produces technically complete artifacts but leaves the operator with low-level files instead of an immediately usable benchmark dashboard. The outcome is a standalone HTML artifact that summarizes benchmark outcome, transaction mix, and runtime behavior from the archived Swingbench result set.

Test: a completed Swingbench benchmark run produces an HTML report artifact that summarizes the benchmark and can be opened locally after the benchmark environment is removed.

### BV4DB-43. Project-level Swingbench workload configuration file

The project needs the active Swingbench workload configuration to live in the repository instead of relying on the packaged default file inside the installed Swingbench distribution. Without a project-owned configuration file, the benchmark definition can drift with upstream Swingbench releases and the exact load shape is harder to review, version, and test as part of the project itself. The outcome is a committed Swingbench configuration artifact that is uploaded and used during benchmark execution.

Test: the Sprint 15 benchmark runner uses a Swingbench configuration XML file stored in the project repository and archives that same file with the benchmark artifacts.

### BV4DB-44. Consolidated Oracle multi-volume UHP benchmark with FIO and Swingbench evidence

The project needs one backlog item that deliberately consolidates the major technical achievements reached so far into a single Oracle-oriented benchmark flow on a higher-end topology: Oracle Database Free running on a UHP-sized compute instance with multiple OCI block volumes arranged in the established Oracle storage layout. This is not only another benchmark variant. It is the first summary benchmark that is meant to exercise the storage-only path, the database path, the guest-observability path, and the OCI-observability path together on one repeatable topology so the repository can present a coherent end-to-end evidence set instead of isolated sprint results.

The benchmark must reuse the multi-volume Oracle layout principles already proven in the fio sprints, the Oracle Database Free automation already established in Sprint 13 onward, the AWR-capable database benchmarking path from Sprint 14 and Sprint 15, and the OCI metrics collection and reporting pipeline already built for Markdown and HTML reporting. The topology should use a UHP-oriented compute profile sized so that the storage path is not artificially capped by an undersized instance, and it should use multiple block volumes so `DATA`, `REDO`, and `FRA` style domains remain observable separately rather than being collapsed into one shared device.

This backlog item has two explicit benchmark phases on the same general environment and both phases must collect their own full evidence set:

1. `FIO` phase on the multi-volume Oracle-style layout:
   The project must run the established Oracle-style fio workload on the UHP multi-volume topology and collect:
   - fio result artifacts
   - guest `iostat` evidence for the fio phase
   - OCI Monitoring metrics for the fio phase

2. `Swingbench` phase on Oracle Database Free on the same multi-volume UHP topology:
   The project must run the standardized Oracle Database Free Swingbench workload on that topology and collect:
   - Swingbench result artifacts
   - guest `iostat` evidence for the Swingbench phase
   - OCI Monitoring metrics for the Swingbench phase
   - the existing AWR begin/end snapshot and report artifacts already established for database-level runs

This backlog item must explicitly reuse existing project assets rather than creating parallel one-off tooling. In particular, it should reuse the established Oracle storage-layout scripting, the standardized Swingbench runner and config handling, the OCI metrics collection path, and the existing Markdown plus HTML reporting approach so the new benchmark produces a summary result set instead of another disconnected implementation branch. The expected outcome is a single sprint-scale benchmark package that can be used as the repository's strongest integrated demonstration so far: storage stress, database stress, guest evidence, provider metrics, and human-readable reporting all aligned on the same benchmark story.

Test: a consolidated benchmark run completes on a multi-volume UHP Oracle topology and produces two correlated evidence packages, one for the fio phase and one for the Swingbench phase, each with benchmark artifacts, guest `iostat`, OCI metrics, and Markdown/HTML reports, while the Swingbench phase also archives AWR artifacts for the same run window.

### BV4DB-45. Integrated benchmark summary report for the project baseline

The project needs one top-level summary artifact that explains, in one place, what the consolidated benchmark sprint proved and how it relates to the repository's journey so far. The raw benchmark artifacts, OCI metrics reports, Swingbench dashboard, and AWR report are all valuable individually, but by this stage the repository also needs an operator-facing summary that ties those outputs together into one benchmark narrative: storage-only stress versus database-level stress, guest-level observations versus provider-side OCI Monitoring, and the practical meaning of the Oracle-style multi-volume UHP topology in the context of the work already completed in earlier sprints.

This summary artifact should not replace the detailed reports. It should sit above them and reference them. The expected content is a concise integrated explanation of the benchmark topology, the two benchmark phases, the key observations from each phase, the location of the detailed HTML reports, and the practical conclusions the operator should take away from the project at this point. The aim is to make the repository understandable as a complete benchmark story rather than only as a sequence of individual sprint artifacts.

Test: the consolidated benchmark sprint produces a top-level summary artifact that links the FIO HTML report, the Swingbench HTML report, the AWR report, and the OCI metrics outputs, and explains the main benchmark conclusions in operator-facing form.

### BV4DB-46. Nine-hundred-second mirror rerun of the Sprint 17 consolidated benchmark

The project needs one follow-up benchmark that is deliberately not a redesign, not a new scenario, and not another analysis-only sprint. It is an exact mirror rerun of Sprint 17 on the same Oracle-style multi-volume UHP benchmark path, with only one intentional change: both benchmark phases must run long enough to produce provider-side monitoring evidence that is analytically strong at OCI Monitoring resolution. The purpose of this item is to convert the already validated Sprint 17 automation path into a benchmark-quality evidence run, not to explore a new topology.

This backlog item must therefore preserve the Sprint 17 architecture and artifact contract:

- same Oracle-style multi-volume topology
- same UHP-oriented compute intent and the same capacity-fallback behavior if OCI capacity requires it
- same FIO phase followed by the same Oracle Database Free Swingbench phase
- same guest `iostat` capture model
- same OCI Monitoring collection and Markdown/HTML reporting path
- same Swingbench HTML report and AWR export path
- same integrated summary style

The only required scope difference relative to Sprint 17 is duration:

- `fio` must run for `900` seconds
- `Swingbench` must run for `900` seconds

That longer runtime is required so the benchmark produces real block-volume OCI Monitoring evidence for the database phase instead of a mostly empty provider-side view caused by a too-short benchmark window. The sprint is therefore a benchmark-quality mirror run of Sprint 17 whose main purpose is stronger observability, not new functionality.

Test: a Sprint 17 mirror benchmark completes with both `fio` and `Swingbench` running for `900` seconds, produces the same report set as Sprint 17, and the Swingbench-phase OCI Monitoring report contains non-trivial block-volume evidence suitable for comparison with guest `iostat`, Swingbench results, and AWR.

### BV4DB-47. Force Oracle Database Free file placement onto the project block-volume layout

Sprint 18 exposed a structural defect in the current Oracle Database Free automation: the benchmark host prepares the intended Oracle-style block-volume layout at `/u02/oradata`, `/u03/redo`, and `/u04/fra`, but the database creation path still allows Oracle Database Free to create the real database under `/opt/oracle/oradata` on the boot volume. That behavior invalidates the storage-to-database correlation goal for the consolidated benchmark because `fio` stresses the attached block volumes while `Swingbench` can end up driving boot-volume I/O instead of the project-managed data, redo, and FRA devices.

This backlog item is therefore not a reporting tweak. It is a placement-correctness fix for the benchmark itself. The project must harden the Oracle Database Free installation and creation path so that database datafiles, redo logs, and recovery area are verifiably created on the project-managed block-volume mount points and not silently left on the boot volume by the Oracle Free configure helper. The resulting automation must prove the final placement from artifacts, not only from intended environment variables.

Expected implementation scope:

- replace or constrain the Oracle Database Free creation path so it cannot silently fall back to `/opt/oracle/oradata`
- ensure the final database uses `/u02/oradata` for datafiles, `/u03/redo` for redo placement, and `/u04/fra` for the recovery area
- archive evidence of actual file placement in sprint artifacts
- make placement validation part of integration coverage so future consolidated runs fail fast if the database lands on the boot volume again

Test: an Oracle Database Free benchmark run completes and the archived installation/status evidence proves that database files are placed on `/u02/oradata`, `/u03/redo`, and `/u04/fra`, while the boot-volume default path `/opt/oracle/oradata` is not the active location for the benchmark database workload.

### BV4DB-48. Analyze benchmark and test outcomes for evidence quality, contradictions, and conclusions

The project needs one explicit backlog item focused on analytical quality control across the benchmark evidence already produced by the repository. The repository now contains multiple layers of outputs for the same benchmark stories: raw benchmark results, guest `iostat`, OCI Monitoring metrics, AWR reports, HTML dashboards, summaries, regression logs, and sprint-level conclusions. That breadth is valuable, but it also creates risk: a sprint can appear complete while its conclusions are not actually supported by the data, or while different observation layers contradict each other in ways that should have blocked acceptance.

This item is therefore about outcome analysis rather than another benchmark execution. Its purpose is to examine completed sprint outputs and validate whether the resulting conclusions are defensible, sufficiently correlated, and evidence-complete. The work should look specifically for mismatches such as:

- guest `iostat` activity not matching the intended storage topology
- OCI Monitoring evidence contradicting the expected active resources
- benchmark summaries that overclaim beyond what the raw artifacts justify
- gaps between test-pass status and actual benchmark-evidence quality
- places where the sprint should have failed or been marked inconclusive rather than accepted

This backlog item should lead to explicit analytical rules for future sprints: what evidence is mandatory, what contradictions are disqualifying, how benchmark-quality correlation is recognized, and when a sprint must be marked failed even if the automation technically completed. The detailed scope, method, and acceptance approach are intentionally left to sprint design so the analysis can be framed carefully rather than hard-coded prematurely here.

Test: a dedicated analysis sprint produces written outcome-validation rules, applies them to selected completed benchmark sprints, and records whether the prior sprint conclusions remain valid, must be revised, or must be failed.

### BV4DB-49. Proper FIO time-series ingestion for correlation (with synthetic fallback)

The correlation pipeline currently uses topology-aligned time series (guest `iostat`, OCI Monitoring) but does not include `fio_*` variables in the **Full Correlation Matrix** because the archived fio artifact (`fio_results.json`) is summary-style. The project needs true fio time-series signals (per job / per mount / per resource group) so that `fio_data_mbps`, `fio_redo_mbps`, `fio_fra_mbps`, etc. can participate in the topology-aware correlation matrix the same way Swingbench TPS does.

Implementation has two tiers:

1. **Real fio time series (preferred)**:
   - Update the fio execution to emit per-interval logs (e.g. bw/iops/lat logs) for each job, with an explicit averaging interval.
   - Add a loader that parses these logs, normalizes units to MB/s, and maps job outputs to topology resources (`boot`, `data`, `redo`, `fra`) based on job name + target directory/mount.
   - Join the fio time series into the aligned correlation frame on timestamps, resampled to the analysis `freq` (primary `1min`, fallback `10s` when runs are too short).

2. **Synthetic fio time series (current-stage workaround)**:
   - Generate a synthetic time series per fio job using the known constant throughput level from fio summaries (`read_bw_kbps`, `write_bw_kbps`, `runtime_s`) and the known phase time window.
   - Produce topology-level synthetic columns (`fio_data_mbps`, `fio_redo_mbps`, `fio_fra_mbps`, …) by summing per-job synthetic series mapped to each resource.
   - Mark synthetic signals explicitly in outputs/metadata so they are not confused with real measured per-interval fio telemetry.

Test: for Sprint 17 and Sprint 18, the FIO phase Full Correlation Matrix includes `fio_*_mbps` topology variables and produces stable, interpretable correlations against `iostat_*_mbps` and `oci_*_mbps` under the same alignment methodology used for Swingbench.

### BV4DB-50. UHP multipath diagnostics sandbox host

Provision a dedicated compute instance with a single **Ultra High Performance** block volume attached via **iSCSI multipath** and expose a stable mapper device (`/dev/mapper/mpath*`). The goal is to evaluate and document multipath utilities and diagnostic evidence in a controlled environment, independent of database workloads.

Test: the sandbox host can be created on demand, multipath is active with multiple paths, a stable `/dev/mapper/mpath*` device exists, and diagnostics artifacts are archived under the sprint progress folder.

### BV4DB-51. FIO benchmark: multipath vs single-path iSCSI on UHP

Run the same fio workload twice on the same UHP block volume tier to quantify the difference between a **multipath-enabled iSCSI** configuration and an intentionally limited **single-path iSCSI** configuration. Keep the workload identical across both runs and archive the resulting evidence and a short comparison summary.

Test: both runs complete successfully, fio JSON outputs exist for both modes, and the sprint produces a comparison summary showing the observed throughput/IOPS/latency difference.

### BV4DB-52. Persist block-volume mount in /etc/fstab with _netdev,nofail

When operators keep infrastructure (`KEEP_INFRA=true`) or plan to reboot the instance, the non-root block volume mount should be made persistent using an `/etc/fstab` entry that follows Oracle guidance for consistent device paths. Specifically, use `_netdev` (so iSCSI initiator comes up before mount) and `nofail` (so boot is not blocked if volume is unavailable), as documented by Oracle.

Expected implementation scope:

- Ensure scripts (or an operator command) can add/update an `/etc/fstab` entry for the Sprint mountpoint using the consistent device path (for example `/dev/oracleoci/oraclevdb` when available).
- Use mount options: `defaults,_netdev,nofail`.
- Provide a safe way to disable/remove the entry during teardown or when switching between multipath and single-path modes.

Test: after adding the entry, `mount -a` succeeds and a reboot leaves the instance reachable while the block volume is mounted (or skipped without boot failure when intentionally absent), using `_netdev,nofail` options.

### BV4DB-53. Configure dm-multipath load balancing policy (round-robin) for UHP iSCSI multipath

The project currently validates **HA multipath correctness** (multiple iSCSI paths aggregated and used via `/dev/mapper/mpath*`), but observed behavior can still be effectively single-path because default dm-multipath policies can be sticky (for example `service-time` selection or priority-based path groups).

This backlog item introduces an explicit, operator-visible **load-balancing policy** for dm-multipath (for example round-robin across all active paths), documents the exact configuration applied (multipath.conf knobs), and archives evidence that I/O distribution is occurring across multiple paths during the benchmark window.

Expected implementation scope:

- Add an explicit dm-multipath policy configuration step (for example `path_selector "round-robin 0"`, `path_grouping_policy multibus`, `rr_min_io_rq` tuning).
- Provide an operator toggle to enable/disable the load-balancing configuration without breaking the HA baseline.
- Archive “before/after” evidence of the active policy and the observed per-path distribution (from `multipath -ll`, `multipathd show config`, `multipathd show paths`, and any available path-stat counters on the target OS).

Test: with load-balancing enabled, diagnostics demonstrate that multiple active paths carry I/O during the benchmark window (not only one hot path), and the applied dm-multipath configuration is captured in artifacts.

### BUG-S22-1. Sprint 22 teardown.sh fails when run from repo root

**Severity:** Critical
**Sprint:** 22
**Status:** Open

**Description:**
When running `NAME_PREFIX=bv4db-s22-mpath teardown.sh` from the repository root, teardown fails because oci_scaffold always sets `STATE_FILE="${PWD}/state-${NAME_PREFIX}.json"` when NAME_PREFIX is set (oci_scaffold.sh:12-16). This ignores any exported STATE_FILE and looks in the wrong directory.

Sprint 22 scripts write state to `progress/sprint_22/state-bv4db-s22-mpath.json` but teardown.sh looks for `./state-bv4db-s22-mpath.json` in repo root.

**Root cause:**
oci_scaffold.sh intentionally overrides STATE_FILE when NAME_PREFIX is set to prevent stale exports. Sprint 22 scripts run from repo root but write state to progress/sprint_22/.

**Fix required:**
Sprint 22 scripts must either:
1. Run from progress/sprint_22/ directory, OR
2. Provide a teardown wrapper that cd's to the correct directory

**Test:** `NAME_PREFIX=bv4db-s22-mpath ./tools/teardown_sprint22.sh` from repo root must successfully teardown Sprint 22 resources

### BUG-S22-2. Block volume not deleted when attachment fails before being stored in state

**Severity:** Medium
**Sprint:** 22
**Status:** Fixed (ensure-blockvolume.sh now adds BV to creation_order immediately after creation)

**Description:**
When a multipath attachment fails (e.g., OCI API returns `isMultipath: null` despite request), the script detaches and retries. If all retries fail, the block volume is created and recorded in state but the attachment is never stored. On teardown, oci_scaffold deletes only the compute instance because the block volume entry in state has no attachment to detach first, causing the BV to be orphaned.

**Root cause:**
The Sprint 20 multipath diagnostics script only stores attachment info in state AFTER successful multipath verification. When multipath never enables, the attachment is detached but the BV remains in state without attachment info. Teardown then skips BV deletion.

**Observed behavior:**
- State file has `blockvolume.created: true` and `blockvolume.ocid` but no attachment
- Teardown deletes compute but not the BV
- Orphan BV remains billable in OCI

**Fix required:**
Either:
1. Store BV attachment in state immediately after attach succeeds (before multipath check), OR
2. Make teardown delete BV even when no attachment is recorded, OR
3. Delete BV in the cleanup path when multipath fails

**Test:** After multipath attachment failure and teardown, `oci bv volume get --volume-id <ocid>` should return 404/TERMINATED, not AVAILABLE
