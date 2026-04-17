# Sprint 1 - Setup

## Contract

### Project Overview

OCI Block Volume for Database Architecture — provisions OCI compute with block volume and runs fio benchmarks. Primary output is a structured fio performance report.

### Rules Confirmed

- GENERAL_RULES.md: understood — PLAN.md and BACKLOG.md are read-only; design owned by implementor; feedback via proposedchanges/openquestions files
- GIT_RULES.md: understood — semantic commits with format `type: (sprint-N) message`; push after every commit
- backlog_item_definition.md: understood — items are what/why only, no design details
- sprint_definition.md: understood — Test/Regression fields required; Sprint 1 is YOLO, Test: integration, Regression: none
- Submodule rule: `oci_scaffold/` and `RUPStrikesBack/` are read-only — never modify; stop and alert user if a change is needed

### Responsibilities

- MAY edit: progress/sprint_1/* files, tests/*, PROGRESS_BOARD.md, README.md
- MUST NOT edit: PLAN.md, BACKLOG.md, AGENTS.md, anything in oci_scaffold/ or RUPStrikesBack/
- Propose changes via: progress/sprint_1/sprint_1_proposedchanges.md
- Ask questions via: progress/sprint_1/sprint_1_openquestions.md

### Constraints

- No new test cases in Phase 3 — tests are fully specified in Phase 2
- No exit commands in copy-paste examples
- Block volume has no oci_scaffold script — custom OCI CLI implementation required (see Analysis)

### Status

Contracting complete — ready for Inception.

---

## Analysis

### Sprint Overview

Sprint 1 delivers the full baseline environment: compartment, network, vault+SSH key, compute+block volume, and fio benchmark report. Two oci_scaffold state files are used — `state-infra.json` for persistent resources (compartment, network, vault) and `state-compute.json` for ephemeral resources (compute, block volume).

### BV4DB-1 — Compartment for all project resources

**Requirement:** OCI compartment at path `/oci_bv4db_arch`.

**Technical approach:** `ensure-compartment.sh` from oci_scaffold with `.inputs.compartment_path = '/oci_bv4db_arch'`. Writes OCID to shared state file.

**Dependencies:** OCI tenancy access, compartment creation permission.

**Risks:** None — oci_scaffold handles idempotency.

### BV4DB-2 — Public network for compute access over SSH

**Requirement:** VCN, internet gateway, route table, public subnet, security list permitting SSH from 0.0.0.0/0.

**Technical approach:** `ensure-vcn.sh`, `ensure-igw.sh`, `ensure-rt.sh`, `ensure-subnet.sh`, `ensure-sl.sh` from oci_scaffold. Public subnet with `subnet_prohibit_public_ip=false` and `sl_ingress_cidr=0.0.0.0/0`. Written to shared state file alongside BV4DB-1.

**Dependencies:** BV4DB-1 compartment OCID.

**Risks:** None — all scripts available in oci_scaffold.

### BV4DB-3 — Shared SSH key stored in OCI Vault

**Requirement:** RSA SSH key pair in a software-defined OCI Vault secret, reused across all compute instances.

**Technical approach:** `ensure-vault.sh` (DEFAULT vault type = software-protected), `ensure-key.sh`, `ensure-secret.sh` from oci_scaffold. Generate RSA key pair locally, store private key as secret value. Written to shared state file.

**Dependencies:** BV4DB-1 compartment, BV4DB-2 (none direct — vault is independent of network).

**Risks:** Secret retrieval at instance creation time requires OCI CLI; private key must not be written to disk long-term — handled by shell variable.

### BV4DB-4 — Compute instance with block volume

**Requirement:** AMD64 compute (VM.Standard.E4.Flex) with one block volume, accessible via SSH.

**Technical approach:**
- Compute: `ensure-compute.sh` from oci_scaffold with `compute_shape=VM.Standard.E4.Flex`, SSH public key from BV4DB-3 vault secret
- Block volume: **no oci_scaffold script exists** — implemented directly via OCI CLI (`oci bv volume create`, `oci compute volume-attachment attach --type paravirtualized`)
- Written to compute state file (`state-compute.json`)

**YOLO Decision — Block volume via raw OCI CLI:**
- Issue: oci_scaffold has no ensure-block-volume.sh
- Decision: implement directly with OCI CLI in the cycle script
- Rationale: straightforward OCI CLI commands, well-documented API
- Risk: Low — block volume attach/detach is a standard OCI operation

**Dependencies:** BV4DB-1 (compartment), BV4DB-2 (subnet), BV4DB-3 (SSH key).

**Risks:** Block volume device name on instance (`/dev/oracleoci/oraclevdb`) must be confirmed at attach time.

### BV4DB-5 — fio performance report

**Requirement:** Structured fio report with IOPS, throughput, latency for sequential and random I/O.

**Technical approach:** Install `fio` via `sudo dnf install -y fio` on OracleLinux instance. Run two jobs (sequential 1M rw, random 4k randrw) with `--output-format=json`, save to `progress/sprint_1/fio-results.json`. Parse and print summary.

**Dependencies:** BV4DB-4 (compute + mounted block volume).

**Risks:** fio test runtime ~5 min; JSON output is deterministic.

### Overall Assessment

**Feasibility:** High — all oci_scaffold primitives exist except block volume (mitigated by direct OCI CLI).

**Complexity:** Moderate — two state files, custom block volume handling, SSH key lifecycle.

**Prerequisites met:** OCI CLI configured with tenancy access required at runtime.

**Open Questions:** None.

### YOLO Mode Decisions

No additional decisions beyond block volume approach documented in BV4DB-4 analysis above.

### Readiness for Design Phase

Confirmed ready.
