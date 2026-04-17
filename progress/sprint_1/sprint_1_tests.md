# Sprint 1 — Tests

## Test Environment

**Prerequisites:**
- OCI CLI configured (`oci setup config` completed, `~/.oci/config` present)
- `jq` installed (`brew install jq` or `dnf install -y jq`)
- `setup_infra.sh` completed — `progress/sprint_1/state-bv4db.json` must exist
- For IT-2, IT-3: `run_bv_fio.sh` must be run with `KEEP_INFRA=true` and compute must still be running
- For IT-4: `run_bv_fio.sh` completed (with or without teardown)

**State files:**
- Infra: `progress/sprint_1/state-bv4db.json`
- Compute: `progress/sprint_1/state-bv4db-run.json`
- fio results: `progress/sprint_1/fio-results.json`

---

## Test Sequences

### Provision infra (prerequisite for all tests)

```bash
OCI_REGION=eu-zurich-1 ./tools/setup_infra.sh
```

Expected output (abbreviated):
```
  [INFO] SSH key pair generated
  [INFO] SSH private key stored in vault secret
  State : progress/sprint_1/state-bv4db.json
  Pubkey: progress/sprint_1/bv4db-key.pub
```

### Provision compute + block volume + run fio (prerequisite for IT-2/IT-3)

```bash
KEEP_INFRA=true OCI_REGION=eu-zurich-1 OCI_CLI_REGION=eu-zurich-1 ./tools/run_bv_fio.sh
```

Expected output (abbreviated):
```
  [INFO] Waiting for SSH on <PUBLIC_IP> ...
  [INFO] Connecting block volume via iSCSI ...
  [INFO] Formatting and mounting block volume ...
  [INFO] Block volume mounted at /mnt/bv
  [INFO] Installing fio ...
  [INFO] Running fio sequential (1M rw) ...
  [INFO] Running fio random (4k randrw, 4 jobs) ...
  [INFO] Results saved: progress/sprint_1/fio-results.json
  KEEP_INFRA=true — skipping teardown
```

---

## IT-1: Infrastructure provisioned

**Backlog items:** BV4DB-1, BV4DB-2, BV4DB-3

**What it checks:** `state-bv4db.json` contains OCIDs for compartment, subnet, and vault secret; `bv4db-key.pub` exists.

```bash
OCI_REGION=eu-zurich-1 OCI_CLI_REGION=eu-zurich-1 ./tests/integration/test_bv4db.sh
```

Expected output:
```
=== IT-1: Infrastructure provisioned ===
  [PASS] IT-1: infra state complete (compartment, subnet, secret, pubkey)
```

Manual verification:
```bash
jq '{compartment: .compartment.ocid, subnet: .subnet.ocid, secret: .secret.ocid}' \
  progress/sprint_1/state-bv4db.json
```

Expected: all three fields non-null, non-empty strings starting with `ocid1.`.

**Test status:** passed in `eu-zurich-1`

---

## IT-2: SSH access using key from vault

**Backlog items:** BV4DB-3, BV4DB-5

**What it checks:** Retrieves private SSH key from vault secret, opens SSH session to compute instance using that key.

**Requires:** compute running (`KEEP_INFRA=true`)

```bash
OCI_REGION=eu-zurich-1 OCI_CLI_REGION=eu-zurich-1 ./tests/integration/test_bv4db.sh
```

Expected output (IT-2 section):
```
=== IT-2: SSH access using key from vault ===
  [PASS] IT-2: SSH successful via vault key to <PUBLIC_IP>
```

Manual verification:
```bash
SECRET_OCID=$(jq -r '.secret.ocid' progress/sprint_1/state-bv4db.json)
PUBLIC_IP=$(jq -r '.compute.public_ip' progress/sprint_1/state-bv4db-run.json)
TMPKEY=$(mktemp) && chmod 600 "$TMPKEY"
oci secrets secret-bundle get --secret-id "$SECRET_OCID" \
  --query 'data."secret-bundle-content".content' --raw-output \
  | base64 --decode > "$TMPKEY"
ssh -i "$TMPKEY" -o StrictHostKeyChecking=no "opc@${PUBLIC_IP}" "echo ok"
rm -f "$TMPKEY"
```

Expected: `ok`

**Test status:** passed in `eu-zurich-1` against public IP `140.86.212.210`

---

## IT-3: Block volume mounted at /mnt/bv

**Backlog items:** BV4DB-4, BV4DB-5

**What it checks:** SSH to instance, verify `/mnt/bv` is an active mount point.

**Requires:** compute running (`KEEP_INFRA=true`)

```bash
OCI_REGION=eu-zurich-1 OCI_CLI_REGION=eu-zurich-1 ./tests/integration/test_bv4db.sh
```

Expected output (IT-3 section):
```
=== IT-3: Block volume mounted at /mnt/bv ===
  [PASS] IT-3: /mnt/bv is mounted on <PUBLIC_IP>
```

Manual verification (after setting `TMPKEY` and `PUBLIC_IP` as above):
```bash
ssh -i "$TMPKEY" -o StrictHostKeyChecking=no "opc@${PUBLIC_IP}" \
  "df -h /mnt/bv && lsblk /dev/sdb"
```

Expected: df shows `/mnt/bv` with ~50 GB capacity; lsblk shows `/dev/sdb` mounted at `/mnt/bv`.

**Test status:** passed in `eu-zurich-1` against public IP `140.86.212.210`

---

## IT-4: fio performance report produced

**Backlog item:** BV4DB-6

**What it checks:** `fio-results.json` exists, is valid JSON, contains `.sequential.jobs[0]` and `.random.jobs[0]` with IOPS fields.

```bash
OCI_REGION=eu-zurich-1 OCI_CLI_REGION=eu-zurich-1 ./tests/integration/test_bv4db.sh
```

Expected output (IT-4 section):
```
=== IT-4: fio performance report produced ===
  [PASS] IT-4: fio-results.json valid — seq read <N> IOPS <N> MB/s, rand read <N> IOPS <N> MB/s
```

Manual verification:
```bash
jq '{
  seq_read_iops:  (.sequential.jobs[0].read.iops | round),
  seq_write_iops: (.sequential.jobs[0].write.iops | round),
  rand_read_iops: (.random.jobs[0].read.iops | round),
  rand_write_iops:(.random.jobs[0].write.iops | round)
}' progress/sprint_1/fio-results.json
```

Expected: object with four positive integer fields.

**Test status:** passed in `eu-zurich-1` with `seq read 11 IOPS 11 MB/s` and `rand read 1520 IOPS 6 MB/s`

### fio Result Interpretation

- This Sprint 1 fio run is a valid baseline for `eu-zurich-1`, not a tuned performance target.
- Sequential `1M` throughput was low at about `11-12 MB/s`, which is enough for architecture verification but weak for throughput-heavy database operations.
- Random `4k` performance reached about `1520` read IOPS and `1520` write IOPS, proving the volume path works end to end under concurrent load.
- Random write latency was the main weakness: about `68 ms` mean, `132 ms` p95, and `198 ms` p99, with higher tail outliers.
- fio reported `~100%` disk utilization in both workloads, so the storage path, not the VM, appears to be the limiting component in this run.

Detailed analysis is recorded in `progress/sprint_1/fio_analysis.md`.

---

## Test Summary

| Test | Backlog Items | Requires Live Compute | Status |
| ---- | ------------- | --------------------- | ------ |
| IT-1 | BV4DB-1,2,3 | No | passed |
| IT-2 | BV4DB-3,5 | Yes (KEEP_INFRA=true) | passed |
| IT-3 | BV4DB-4,5 | Yes (KEEP_INFRA=true) | passed |
| IT-4 | BV4DB-6 | No | passed |

All Sprint 1 integration tests passed against the live OCI tenancy in `eu-zurich-1`. Shared infra remains in Zurich; the ephemeral compute and block volume were torn down after verification.
