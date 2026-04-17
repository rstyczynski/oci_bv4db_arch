# Development plan

OCI Block Volume for Database Architecture project.

Instruction for the operator: keep the development sprint by sprint by changing `Status` label from Planned via Progress to Done. To achieve simplicity each iteration contains exactly one feature. You may add more backlog Items in `BACKLOG.md` file, referring them in this plan.

Instruction for the implementor: keep analysis, design and implementation as simple as possible to achieve goals presented as Backlog Items. Remove each not required feature sticking to the Backlog Items definitions.

## Sprint 1 - Network and compute with block volume fio test

Status: Progress
Mode: YOLO
Test: integration
Regression: none

Compartment, network, and vault are provisioned together and tracked in a single shared oci_scaffold state file that persists across sprints. Compute instance and block volume use a separate oci_scaffold state file that is created and torn down per test run.

Backlog Items:

* BV4DB-1. Compartment for all project resources
* BV4DB-2. Public network for compute access over SSH
* BV4DB-3. Shared SSH key stored in OCI Vault for compute access
* BV4DB-4. Compute instance with block volume and basic fio test
* BV4DB-5. fio performance report for block volume
