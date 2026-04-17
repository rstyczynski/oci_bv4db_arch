# Sprint 1 - Design

## BV4DB-1. Compartment for all project resources

Status: Proposed

### Requirement Summary

OCI compartment at path `/oci_bv4db_arch` created before any other resource. All project resources live inside it.

### Feasibility Analysis

**API Availability:** `ensure-compartment.sh` in oci_scaffold accepts `.inputs.compartment_path` and creates the full path idempotently. Fully available.

**Technical Constraints:** Compartment creation requires IAM `manage compartments` permission in root tenancy.

**Risk Assessment:**
- Low: oci_scaffold handles existing compartment gracefully (idempotent)

### Design Overview

Script `setup_infra.sh` calls `ensure-compartment.sh` first, writes OCID to shared state file `progress/sprint_1/state-infra.json`.

### Technical Specification

**Inputs to state file:**

| Key | Value |
| --- | --- |
| `.inputs.compartment_path` | `/oci_bv4db_arch` |
| `.inputs.name_prefix` | `bv4db` |
| `.inputs.oci_region` | `$OCI_REGION` |

**Output from state file:** `.compartment.ocid`

---

## BV4DB-2. Public network for compute access over SSH

Status: Proposed

### Requirement Summary

VCN with internet gateway, route table, public subnet, and security list permitting SSH (TCP/22) from `0.0.0.0/0`. Persistent — not torn down between sprints.

### Feasibility Analysis

**API Availability:** All required scripts exist in oci_scaffold: `ensure-vcn.sh`, `ensure-igw.sh`, `ensure-rt.sh`, `ensure-subnet.sh`, `ensure-sl.sh`. Fully available.

**Technical Constraints:** Public subnet requires `subnet_prohibit_public_ip=false`.

**Risk Assessment:**
- Low: all scripts are idempotent; no ordering issue in oci_scaffold flow

### Design Overview

`setup_infra.sh` calls scaffold scripts in sequence after compartment creation. Uses same shared state file.

### Technical Specification

**Inputs to state file:**

| Key | Value |
| --- | --- |
| `.inputs.subnet_prohibit_public_ip` | `false` |
| `.inputs.sl_ingress_cidr` | `0.0.0.0/0` |
| `.inputs.sl_ingress_protocol` | `6` (TCP) |
| `.inputs.sl_ingress_port` | `22` |

**Outputs:** `.vcn.ocid`, `.subnet.ocid`, `.igw.ocid`, `.rt.ocid`, `.sl.ocid`

---

## BV4DB-3. Shared SSH key stored in OCI Vault

Status: Proposed

### Requirement Summary

RSA-4096 SSH key pair generated once. Private key stored as a secret in a software-defined OCI Vault. Public key used at instance launch. Private key retrieved from vault at SSH time, never written to disk as a persistent file.

### Feasibility Analysis

**API Availability:** `ensure-vault.sh` (DEFAULT=software vault), `ensure-key.sh` (AES/SOFTWARE encryption key for secret wrapping), `ensure-secret.sh` (stores base64-encoded secret value). Fully available.

**Technical Constraints:** `ensure-key.sh` creates an AES KMS key that wraps the OCI secret — this is separate from the SSH key itself. The SSH private key is stored as the secret's plaintext value.

**Risk Assessment:**
- Low: standard OCI Vault pattern
- Medium: private key passed via `.inputs.secret_value` in state file — state file contains sensitive data; acceptable for test environment

### Design Overview

`setup_infra.sh` generates RSA-4096 key pair to temp files, provisions vault and KMS key, stores private key as secret value, deletes temp private key file. Public key written to `progress/sprint_1/bv4db-key.pub` for compute launch.

### Technical Specification

**Key generation sequence:**

```bash
ssh-keygen -t rsa -b 4096 -N "" -f /tmp/bv4db-key -C "bv4db"
PRIVATE_KEY=$(cat /tmp/bv4db-key)
PUBLIC_KEY=$(cat /tmp/bv4db-key.pub)
rm -f /tmp/bv4db-key
cp /tmp/bv4db-key.pub progress/sprint_1/bv4db-key.pub
rm -f /tmp/bv4db-key.pub
```

**State inputs:**

| Key | Value |
| --- | --- |
| `.inputs.vault_type` | `DEFAULT` |
| `.inputs.key_algorithm` | `AES` |
| `.inputs.key_protection_mode` | `SOFTWARE` |
| `.inputs.secret_name` | `bv4db-ssh-key` |
| `.inputs.secret_value` | `$PRIVATE_KEY` |

**Outputs:** `.vault.ocid`, `.vault.mgmt_endpoint`, `.key.ocid`, `.secret.ocid`, `.secret.name`

---

## BV4DB-4. Compute instance with block volume

Status: Proposed

### Requirement Summary

AMD64 `VM.Standard.E4.Flex` instance on the public subnet, SSH key from BV4DB-3, with one 50 GB block volume attached as paravirtualized device, formatted ext4, mounted at `/mnt/bv`. Ephemeral — torn down after test.

### Feasibility Analysis

**Compute:** `ensure-compute.sh` supports arbitrary shape via `.inputs.compute_shape`. Fully available.

**Block volume:** No oci_scaffold script — implemented directly via OCI CLI in `run_bv_fio.sh` using `oci bv volume create` and `oci compute volume-attachment attach`.

**Technical Constraints:**
- Block volume availability domain must match compute instance AD
- Device path on OracleLinux: `/dev/oracleoci/oraclevdb` (first paravirtualized BV)
- Compute state file must contain `.subnet.ocid` copied from infra state

**Risk Assessment:**

- Low: paravirtualized attach is the default and simplest attach type
- Low: block volume OCI CLI commands are stable and well-documented

### Design Overview

`run_bv_fio.sh`:

1. Reads infra state — copies compartment and subnet OCIDs into compute state
2. Reads SSH public key from `progress/sprint_1/bv4db-key.pub`
3. Calls `ensure-compute.sh` (VM.Standard.E4.Flex, 2 OCPU, 16 GB RAM)
4. Retrieves SSH private key from vault secret
5. Creates 50 GB block volume in same AD as compute instance
6. Attaches block volume (paravirtualized), waits for ATTACHED state
7. SSHes in: formats ext4, mounts at `/mnt/bv`
8. Runs fio (BV4DB-5)
9. Tears down: detach BV → delete BV → teardown compute via scaffold

### Technical Specification

**Compute state inputs:**

| Key | Value |
| --- | --- |
| `.inputs.compute_shape` | `VM.Standard.E4.Flex` |
| `.inputs.compute_ocpus` | `2` |
| `.inputs.compute_memory_gb` | `16` |
| `.inputs.subnet_prohibit_public_ip` | `false` |
| `.inputs.compute_ssh_authorized_keys_file` | `progress/sprint_1/bv4db-key.pub` |

**State file:** `STATE_FILE=progress/sprint_1/state-compute.json`

**Block volume OCI CLI sequence:**

```bash
AD=$(oci compute instance get --instance-id "$COMPUTE_OCID" \
  --query 'data."availability-domain"' --raw-output)

BV_OCID=$(oci bv volume create \
  --compartment-id "$COMPARTMENT_OCID" \
  --availability-domain "$AD" \
  --display-name "bv4db-bv" \
  --size-in-gbs 50 \
  --wait-for-state AVAILABLE \
  --query 'data.id' --raw-output)

ATTACH_OCID=$(oci compute volume-attachment attach \
  --instance-id "$COMPUTE_OCID" \
  --type paravirtualized \
  --volume-id "$BV_OCID" \
  --wait-for-state ATTACHED \
  --query 'data.id' --raw-output)
```

**On-instance setup:**

```bash
sudo mkfs.ext4 /dev/oracleoci/oraclevdb
sudo mkdir -p /mnt/bv
sudo mount /dev/oracleoci/oraclevdb /mnt/bv
sudo chown opc:opc /mnt/bv
```

---

## BV4DB-5. fio performance report

Status: Proposed

### Requirement Summary

Structured fio benchmark covering sequential and random I/O. Output saved as `progress/sprint_1/fio-results.json`. Summary (IOPS, bandwidth, latency) printed to stdout.

### Feasibility Analysis

**API Availability:** `fio` installable via `sudo dnf install -y fio` on OracleLinux 8/9. JSON output via `--output-format=json`. Fully available.

**Technical Constraints:** fio output file generated on instance; retrieved via `ssh ... cat`.

### Design Overview

`run_bv_fio.sh` after mounting `/mnt/bv`:

1. Install fio: `sudo dnf install -y fio`
2. Run sequential job, capture JSON
3. Run random job, capture JSON
4. Merge into single results file, copy to `progress/sprint_1/fio-results.json`
5. Print summary: job name, IOPS read, IOPS write, bw read MB/s, bw write MB/s, lat mean ms

### Technical Specification

**fio jobs (executed on instance via SSH, output captured):**

```bash
# Sequential 1M rw
ssh opc@$IP "sudo fio --name=seq-rw --rw=rw --bs=1M --size=1G \
  --numjobs=1 --ioengine=libaio --direct=1 --group_reporting \
  --output-format=json --filename=/mnt/bv/testfile" > /tmp/fio-seq.json

# Random 4k randrw
ssh opc@$IP "sudo fio --name=rand-rw --rw=randrw --bs=4k --size=512M \
  --numjobs=4 --iodepth=32 --ioengine=libaio --direct=1 --group_reporting \
  --output-format=json --filename=/mnt/bv/testfile" > /tmp/fio-rand.json
```

**Merge and save:**

```bash
jq -s '{"sequential": .[0], "random": .[1]}' \
  /tmp/fio-seq.json /tmp/fio-rand.json \
  > progress/sprint_1/fio-results.json
```

**Output path:** `progress/sprint_1/fio-results.json`

---

## Design Summary

### Overall Architecture

Two scripts deliver the sprint:

| Script | Scope | State file | Lifecycle |
| --- | --- | --- | --- |
| `setup_infra.sh` | Compartment, network, vault, SSH key | `progress/sprint_1/state-infra.json` | Persistent |
| `run_bv_fio.sh` | Compute, block volume, fio | `progress/sprint_1/state-compute.json` | Ephemeral |

`run_bv_fio.sh` reads infra state for compartment/subnet/SSH key context; does not modify infra state.

### Shared Components

- `oci_scaffold/` submodule scripts (read-only)
- `progress/sprint_1/state-infra.json`
- `progress/sprint_1/bv4db-key.pub`

### Resource Requirements

- OCI CLI configured with tenancy access
- `jq` installed locally
- `fio` installed on instance by `run_bv_fio.sh`

### Testing Strategy

#### Recommended Sprint Parameters

- **Test:** integration — all deliverables are OCI resources and a benchmark; no meaningful unit tests
- **Regression:** none — no prior tests exist

#### Integration Test Scenarios

| Scenario | Infrastructure Dependencies | Expected Outcome | Est. Runtime |
| --- | --- | --- | --- |
| IT-1: infra provisioned | OCI tenancy, IAM perms | compartment + VCN + vault + secret exist in state file | 3 min |
| IT-2: SSH access via vault key | infra state, compute running | `ssh opc@<ip>` succeeds using key retrieved from vault | 4 min |
| IT-3: block volume mounted | compute running, BV attached | `/mnt/bv` visible in `lsblk` on instance | 1 min |
| IT-4: fio report produced | BV mounted, fio installed | `fio-results.json` exists with IOPS/bw/latency fields | 6 min |

#### Smoke Test Candidates

None — integration tests are the minimum viable gate for this sprint.

**Success Criteria:** All four integration tests pass; `fio-results.json` is valid JSON containing both sequential and random job results.

### Design Approval Status

Awaiting Review

---

## Test Specification

Sprint Test Configuration:

- Test: integration
- Mode: managed

### Integration Tests

#### IT-1: Infrastructure provisioned

- **What it verifies:** `setup_infra.sh` completes and all required resources have OCIDs in state file
- **Pass criteria:** `.compartment.ocid`, `.vcn.ocid`, `.subnet.ocid`, `.vault.ocid`, `.secret.ocid` all non-empty in `state-infra.json`; `bv4db-key.pub` exists
- **Target file:** `tests/integration/test_bv4db.sh`

#### IT-2: SSH access using key from vault

- **What it verifies:** compute instance reachable via SSH using private key retrieved from vault secret
- **Preconditions:** IT-1 passed; compute instance running
- **Steps:** retrieve private key from vault secret → write to temp file → `ssh -i tmpkey opc@<public-ip> hostname` → delete temp file
- **Pass criteria:** SSH returns hostname without error
- **Target file:** `tests/integration/test_bv4db.sh`

#### IT-3: Block volume mounted

- **What it verifies:** block volume attached and mounted at `/mnt/bv` on instance
- **Preconditions:** IT-2 passed
- **Steps:** `ssh opc@<ip> lsblk` and check for `/mnt/bv`
- **Pass criteria:** `/mnt/bv` appears in lsblk output
- **Target file:** `tests/integration/test_bv4db.sh`

#### IT-4: fio report produced

- **What it verifies:** fio runs successfully and produces a valid JSON report
- **Preconditions:** IT-3 passed
- **Steps:** check `progress/sprint_1/fio-results.json` exists; validate JSON contains `sequential.jobs` and `random.jobs`
- **Pass criteria:** file exists, `jq '.sequential.jobs, .random.jobs' fio-results.json` returns non-empty arrays
- **Target file:** `tests/integration/test_bv4db.sh`

### Traceability

| Backlog Item | Integration Tests |
| --- | --- |
| BV4DB-1 | IT-1 |
| BV4DB-2 | IT-1, IT-2 |
| BV4DB-3 | IT-2 |
| BV4DB-4 | IT-2, IT-3 |
| BV4DB-5 | IT-4 |
