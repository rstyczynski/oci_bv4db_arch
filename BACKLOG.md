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
