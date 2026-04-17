# Sprint 2 - Setup

## Contract

### Sprint Overview

Sprint 2 delivers the maximum-performance benchmark configuration for OCI Block Volume using the shared compartment, network, and vault created in Sprint 1. The benchmark compute instance and block volume remain ephemeral and are torn down automatically after fio completion.

### Rules Confirmed

- `GENERAL_RULES.md`: understood — work only against backlog items assigned to the active sprint, design before construction, feedback via sprint-local artifacts.
- `GIT_RULES.md`: understood — semantic commit format `type: (sprint-N) message`.
- `backlog_item_definition.md`: understood — backlog item defines what/why, not design.
- `sprint_definition.md`: understood — Sprint 2 is `managed`, `Test: integration`, `Regression: integration`.
- `AGENTS.md`: understood — reuse Sprint 1 shared infrastructure, never modify `RUPStrikesBack/`, and any `oci_scaffold` changes stay on its `oci_bv4db_arch` branch.

### Responsibilities

- MAY edit: `progress/sprint_2/*`, `tests/*`, `tools/*`, `PROGRESS_BOARD.md`, `PLAN.md`, `BACKLOG.md`
- MAY edit in submodule branch: `oci_scaffold/*`
- MUST NOT edit: `RUPStrikesBack/*`
- Ask questions via: `progress/sprint_2/sprint_2_openquestions.md`
- Propose scope changes via: `progress/sprint_2/sprint_2_proposedchanges.md`

### Status

Contracting complete — Sprint 2 benchmark implemented and integration-tested.

---

## Analysis

### Backlog Item

**BV4DB-7. Maximum-performance block volume configuration benchmark**

### Requirement Summary

The sprint needs a higher-performance benchmark configuration than Sprint 1, including maximum block volume VPU, required network paths, a 60-second fio measurement window for this sprint, fio result analysis, and automatic teardown after the benchmark run.

### Reuse from Sprint 1

- Shared compartment, public subnet, and vault secret are already available in `progress/sprint_1/state-bv4db.json`.
- Sprint 1 already proved the end-to-end flow for SSH, iSCSI attach, fio execution, and result collection in `eu-zurich-1`.
- The existing benchmark script and integration test provide the baseline structure for Sprint 2.

### Feasibility

- Oracle documents Ultra High Performance (UHP) block volumes up to `120 VPU/GB`, `300,000` IOPS, and `2,680 MB/s` per volume, with multipath required for best performance.
- Oracle documents that current VM shapes with `16` or more OCPUs support UHP, and `VM.Standard.E5.Flex` supports up to `40 Gbps` network bandwidth and up to `4,800 MB/s` block volume throughput per instance.
- Sprint 1 already uses iSCSI attachment successfully, so extending the same path to a multipath-oriented UHP configuration is technically aligned with the existing implementation.

### Risks

- Maximum-performance settings materially increase cost and runtime compared with Sprint 1.
- UHP best performance depends on multipath-related prerequisites that were not needed in Sprint 1.

### Readiness

Ready for managed-mode execution. The sprint was implemented and validated with a 60-second total fio window.
