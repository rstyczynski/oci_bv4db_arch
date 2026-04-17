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
