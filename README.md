# Block Volume test for Database

Validation of various OCI compute instance and block volume configuration to serve for Oracle Database.

## Overview

This project provisions an OCI compute instance with an attached block volume, runs fio I/O benchmarks, and produces a structured performance report. The goal is to establish a repeatable baseline for block volume performance characterisation in OCI.

## Architecture

Two lifecycle scopes are used:

- **Persistent infra** (`tools/setup_infra.sh`): compartment, VCN, subnet, OCI Vault + KMS key, SSH key pair secret. Created once, reused across all benchmark runs.
- **Ephemeral compute** (`tools/run_bv_fio.sh`): compute instance + block volume provisioned per run, torn down after fio completes (unless `KEEP_INFRA=true`).

Block volume is attached via **iSCSI** (operator decision for database host parity).

## Prerequisites

- OCI CLI configured (`oci setup config`)
- `jq` installed
- Appropriate IAM permissions: compute, block volume, VCN, vault, secrets

## Quick Start

```bash
# 1. Provision persistent infra (once)
OCI_REGION=eu-frankfurt-1 ./tools/setup_infra.sh

# 2. Run benchmark (provisions compute, runs fio, tears down)
./tools/run_bv_fio.sh

# 2a. Keep compute running after benchmark for manual inspection
KEEP_INFRA=true ./tools/run_bv_fio.sh
```

fio results are saved to `progress/sprint_1/fio-results.json`.

## Output

```text
=== fio Results Summary ===
Sequential:  read  NNN IOPS  NNN MB/s  lat N.NN ms
             write NNN IOPS  NNN MB/s  lat N.NN ms
Random:      read  NNN IOPS  NNN MB/s  lat N.NN ms
             write NNN IOPS  NNN MB/s  lat N.NN ms
```

## Project Structure

```text
tools/
  setup_infra.sh          # Persistent infra provisioning
  run_bv_fio.sh           # Compute + BV + fio benchmark
tests/
  integration/
    test_bv4db.sh         # Integration tests IT-1 through IT-4
progress/
  sprint_1/
    state-bv4db.json      # Infra state (created at runtime)
    state-bv4db-run.json  # Compute state (created at runtime)
    fio-results.json      # fio output (created at runtime)
oci_scaffold/             # Submodule: idempotent OCI provisioning scripts
RUPStrikesBack/           # Submodule: RUP methodology
```

## Running Integration Tests

```bash
# IT-1 and IT-4 (file-based, no live compute needed)
./tests/integration/test_bv4db.sh

# Full suite (compute must be running — use KEEP_INFRA=true)
KEEP_INFRA=true ./tools/run_bv_fio.sh
./tests/integration/test_bv4db.sh
```

---

## Recent Updates

### Sprint 1 — Baseline fio Benchmark

**Status:** implemented

**Backlog Items Implemented:**

- **BV4DB-1**: Compartment `/oci_bv4db_arch` for all project resources — implemented
- **BV4DB-2**: Public VCN + subnet for SSH access — implemented
- **BV4DB-3**: Shared SSH key in OCI Vault (software-protected) — implemented
- **BV4DB-4**: `ensure-blockvolume` / `teardown-blockvolume` scaffold scripts — implemented (oci_scaffold branch `oci_bv4db_arch`)
- **BV4DB-5**: Compute instance + iSCSI block volume provisioning — implemented
- **BV4DB-6**: fio sequential + random benchmark with JSON report — implemented

**Documentation:**

- Setup/Analysis: `progress/sprint_1/sprint_1_setup.md`
- Design: `progress/sprint_1/sprint_1_design.md`
- Implementation: `progress/sprint_1/sprint_1_implementation.md`
- Tests: `progress/sprint_1/sprint_1_tests.md`
