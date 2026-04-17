# Sprint 1 — Implementation

## Status: implemented

## Items Implemented

### BV4DB-1: Compartment /oci_bv4db_arch

Implemented via `tools/setup_infra.sh`. Sets `.inputs.compartment_path = /oci_bv4db_arch` then calls `ensure-compartment.sh`. Compartment OCID stored in `state-bv4db.json` under `.compartment.ocid`.

### BV4DB-2: VCN + network resources

Implemented via `tools/setup_infra.sh`. Calls `ensure-vcn.sh`, `ensure-sl.sh` (TCP/22 from 0.0.0.0/0), `ensure-igw.sh`, `ensure-rt.sh`, `ensure-subnet.sh` in order. All OCIDs stored in `state-bv4db.json`.

### BV4DB-3: Shared SSH key in OCI Vault

Implemented via `tools/setup_infra.sh`. Generates RSA-4096 key pair; private key stored in vault secret (`bv4db-ssh-key`) via `ensure-vault.sh` / `ensure-key.sh` / `ensure-secret.sh`. Public key kept at `progress/sprint_1/bv4db-key.pub`. Private key cleared from state after secret creation.

### BV4DB-4: ensure-blockvolume / teardown-blockvolume scripts

Implemented in `oci_scaffold` submodule on branch `oci_bv4db_arch`:
- `oci_scaffold/resource/ensure-blockvolume.sh` — creates block volume, attaches via iSCSI (operator decision), writes IQN/IPv4/port to state
- `oci_scaffold/resource/teardown-blockvolume.sh` — detaches via `oci compute volume-attachment detach`, deletes via `oci bv volume delete`

### BV4DB-5: Compute instance + block volume provisioning

Implemented via `tools/run_bv_fio.sh`. Uses `NAME_PREFIX=bv4db-run` → `state-bv4db-run.json`. Reads compartment/subnet/secret from `state-bv4db.json`. Calls `ensure-compute.sh` then `ensure-blockvolume.sh`. Performs iSCSI login (`iscsiadm`), formats `/dev/sdb` as ext4, mounts at `/mnt/bv`.

### BV4DB-6: fio block volume benchmark

Implemented in `tools/run_bv_fio.sh` (same script as BV4DB-5). Runs two fio workloads over SSH:
- Sequential: `--rw=rw --bs=1M --size=1G --numjobs=1 --ioengine=libaio --direct=1`
- Random: `--rw=randrw --bs=4k --size=512M --numjobs=4 --iodepth=32 --ioengine=libaio --direct=1`

Results saved to `progress/sprint_1/fio-results.json`. Summary printed to stdout. Teardown skipped when `KEEP_INFRA=true`.

## Implementation Decisions

- **iSCSI attachment** (operator decision, recorded in design): block volume attached via iSCSI, not paravirtualized, to match production database host configurations.
- **Two state lifecycles**: infra (`state-bv4db.json`, `NAME_PREFIX=bv4db`) is persistent; compute+BV (`state-bv4db-run.json`, `NAME_PREFIX=bv4db-run`) is ephemeral.
- **Private key handling**: key retrieved from vault at runtime via `oci secrets secret-bundle get`, written to a temp file with `chmod 600`, removed after use.
- **oci_scaffold branch**: all scaffold additions committed to `oci_scaffold` branch `oci_bv4db_arch`; merge to upstream main is a separate task.

## Files Produced

| File | Purpose |
| ---- | ------- |
| `tools/setup_infra.sh` | Persistent infra provisioning |
| `tools/run_bv_fio.sh` | Compute+BV provisioning + fio benchmark |
| `oci_scaffold/resource/ensure-blockvolume.sh` | Idempotent block volume create+attach |
| `oci_scaffold/resource/teardown-blockvolume.sh` | Block volume detach+delete |
| `tests/integration/test_bv4db.sh` | Integration tests IT-1 through IT-4 |
| `progress/sprint_1/fio-results.json` | fio output (created at runtime) |
| `progress/sprint_1/state-bv4db.json` | Infra state (created at runtime) |
| `progress/sprint_1/state-bv4db-run.json` | Compute state (created at runtime) |
