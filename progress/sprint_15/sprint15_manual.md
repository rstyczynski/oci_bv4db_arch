# Sprint 15 - Swingbench Load Generation Manual

This manual explains how to run Oracle Database Free load generation with `Swingbench`, which is the standard load generator from Sprint 15 onward.

Compatibility note:

- `sprint15_manual.md` is the canonical file
- `sprint_manual.md` is provided as a short alias in the same directory

## Prerequisites

Before starting, ensure you have:

1. OCI CLI configured with valid credentials
2. SSH key pair stored in OCI Vault from Sprint 1
3. Shared infrastructure from Sprint 1
4. Oracle Database Free 23ai reachable on the benchmark host

## Standard Tool Choice

- Primary load generator: `Swingbench`
- Fallback load generator: `HammerDB`

Use `HammerDB` only if `Swingbench` is shown unsuitable for the required scenario. Sprint 15 automates `Swingbench` and provides a fallback installer for `HammerDB`.

## Project-Owned Config File

The active Swingbench workload definition is stored in the repository at:

`config/swingbench/SOE_Server_Side_V2.xml`

Sprint 15 uploads that file to the benchmark host and uses it as the `charbench` configuration source. This keeps the benchmark definition versioned at project level instead of relying on the packaged Swingbench default config.

This repo-owned config was validated in a live Sprint 15 rerun on `2026-04-23`.

## Expected Duration

This operation is not short. For the validated live rerun on `2026-04-23`, the full automated flow took about `25 minutes` end to end.

Approximate duration by phase:

- compute provisioning and SSH readiness: `2-3 minutes`
- block volume provisioning, attach, and storage layout: `3-4 minutes`
- Oracle Database Free install and database creation: `7-10 minutes`
- Swingbench install: `1 minute`
- AWR begin snapshot: `<1 minute`
- SOE schema rebuild with `oewizard`: `2-3 minutes`
- `charbench` runtime: `5 minutes` for the default configuration
- AWR end snapshot and AWR HTML export: `1-2 minutes`
- artifact copy-back and local HTML rendering: `1-2 minutes`

Timing depends on OCI provisioning speed, package download speed, and whether you keep the infrastructure running after the test.

## Option 1: Automated Sprint 15 Execution

Run the complete Sprint 15 workflow automatically:

```bash
cd /path/to/oci_bv4db_arch
./tools/run_oracle_db_sprint15.sh
```

Common overrides:

```bash
# 10 minute run
WORKLOAD_DURATION=600 ./tools/run_oracle_db_sprint15.sh

# More Swingbench users
SWINGBENCH_USERS=8 ./tools/run_oracle_db_sprint15.sh

# Keep the benchmark host after the run
KEEP_INFRA=true ./tools/run_oracle_db_sprint15.sh
```

Operator expectation:

- default end-to-end runtime: about `25 minutes`
- the script can appear quiet for several minutes during Oracle database creation and during the Swingbench schema build
- if you set `WORKLOAD_DURATION=600`, add about `5` extra minutes to the total run time

## Option 2: Manual Step-by-Step Swingbench Run

### Step 1: Provision the Oracle benchmark host

Approximate time: `10-15 minutes` if the host is not already available and Sprint 13 provisioning must install Oracle Database Free and create the database.

Use the Sprint 13 automation if the host is not already running:

```bash
cd /path/to/oci_bv4db_arch
KEEP_INFRA=true PROGRESS_DIR="$PWD/progress/sprint_15" ./tools/run_oracle_db_sprint13.sh
```

### Step 2: Connect to the benchmark host

Approximate time: `<1 minute`

```bash
SECRET_OCID=$(jq -r '.secret.ocid' progress/sprint_1/state-bv4db.json)
TMPKEY=$(mktemp)
chmod 600 "$TMPKEY"
oci secrets secret-bundle get \
  --secret-id "$SECRET_OCID" \
  --query 'data."secret-bundle-content".content' --raw-output \
  | base64 --decode > "$TMPKEY"

PUBLIC_IP=$(jq -r '.compute.public_ip' progress/sprint_15/state-bv4db-oracle-db.json)
ssh -i "$TMPKEY" -o StrictHostKeyChecking=no opc@$PUBLIC_IP
```

If Sprint 15 automation created the host, read the IP from `progress/sprint_15/state-bv4db-oracle-sb.json` instead.

### Step 3: Install Swingbench

Approximate time: `1 minute`

From the local machine:

```bash
scp -i "$TMPKEY" tools/install_swingbench.sh opc@$PUBLIC_IP:/tmp/
ssh -i "$TMPKEY" opc@$PUBLIC_IP \
  "chmod +x /tmp/install_swingbench.sh && \
   sudo INSTALL_DIR=/opt/swingbench INSTALL_OWNER=oracle:oinstall /tmp/install_swingbench.sh"
```

### Step 4: Capture an AWR begin snapshot

Approximate time: `<1 minute`

```bash
scp -i "$TMPKEY" tools/capture_awr_snapshot.sh opc@$PUBLIC_IP:/tmp/
ssh -i "$TMPKEY" opc@$PUBLIC_IP \
  "chmod +x /tmp/capture_awr_snapshot.sh && \
   sudo su - oracle -c '/tmp/capture_awr_snapshot.sh begin /tmp/awr_begin_snap_id.txt'"
```

### Step 5: Run Swingbench load generation

Approximate time: `7-8 minutes` with default settings.

Breakdown for the default configuration:

- SOE schema drop and rebuild with `oewizard`: about `2-3 minutes`
- `charbench` runtime: `5 minutes`

From the local machine:

```bash
scp -i "$TMPKEY" tools/run_oracle_swingbench.sh opc@$PUBLIC_IP:/tmp/
scp -i "$TMPKEY" config/swingbench/SOE_Server_Side_V2.xml opc@$PUBLIC_IP:/tmp/
ssh -i "$TMPKEY" opc@$PUBLIC_IP \
  "chmod +x /tmp/run_oracle_swingbench.sh && \
   sudo su - oracle -c 'ORACLE_PWD=BenchmarkPwd123 \
     WORKLOAD_DURATION=300 \
     SWINGBENCH_USERS=4 \
     SWINGBENCH_SCALE=1 \
     SWINGBENCH_BUILD_THREADS=4 \
     SWINGBENCH_HOME=/opt/swingbench \
     RESULTS_DIR=/tmp/swingbench \
     CONFIG_FILE=/tmp/SOE_Server_Side_V2.xml \
     /tmp/run_oracle_swingbench.sh 300'"
```

The script:

- recreates the `SOE` schema with `oewizard`
- runs `charbench` against `FREEPDB1`
- writes XML results and latest `BENCHMARK_RESULTS` JSON to `/tmp/swingbench`
- uses the uploaded project-owned Swingbench config file from `config/swingbench/SOE_Server_Side_V2.xml`

### Step 6: Capture the AWR end snapshot

Approximate time: `<1 minute`

```bash
ssh -i "$TMPKEY" opc@$PUBLIC_IP \
  "sudo su - oracle -c '/tmp/capture_awr_snapshot.sh end /tmp/awr_end_snap_id.txt'"
```

### Step 7: Export the AWR report

Approximate time: `1 minute`

```bash
scp -i "$TMPKEY" tools/export_awr_report.sh opc@$PUBLIC_IP:/tmp/
ssh -i "$TMPKEY" opc@$PUBLIC_IP \
  "chmod +x /tmp/export_awr_report.sh && \
   sudo su - oracle -c '/tmp/export_awr_report.sh \
     \$(cat /tmp/awr_begin_snap_id.txt) \
     \$(cat /tmp/awr_end_snap_id.txt) \
     /tmp/awr_report.html'"
```

### Step 8: Collect artifacts

Approximate time: `1 minute`

```bash
scp -i "$TMPKEY" opc@$PUBLIC_IP:/tmp/swingbench/charbench.log ./progress/sprint_15/swingbench_charbench.log
scp -i "$TMPKEY" opc@$PUBLIC_IP:/tmp/swingbench/results.xml ./progress/sprint_15/swingbench_results.xml
scp -i "$TMPKEY" opc@$PUBLIC_IP:/tmp/swingbench/results_db.json ./progress/sprint_15/swingbench_results_db.json
scp -i "$TMPKEY" opc@$PUBLIC_IP:/tmp/awr_report.html ./progress/sprint_15/awr_report.html
cp config/swingbench/SOE_Server_Side_V2.xml ./progress/sprint_15/swingbench_config.xml
```

### Step 9: Render the local HTML dashboard

Approximate time: `<1 minute`

```bash
./tools/render_swingbench_report_html.sh \
  ./progress/sprint_15/swingbench_results.xml \
  ./progress/sprint_15/swingbench_charbench.log \
  ./progress/sprint_15/swingbench_results_db.json \
  ./progress/sprint_15/swingbench_report.html
```

## Key Parameters

`run_oracle_swingbench.sh` accepts:

| Variable | Default | Description |
|----------|---------|-------------|
| `WORKLOAD_DURATION` | `300` | Run time in seconds |
| `SWINGBENCH_USERS` | `4` | Number of `charbench` users |
| `SWINGBENCH_SCALE` | `1` | SOE schema scale factor |
| `SWINGBENCH_BUILD_THREADS` | `4` | Threads used by `oewizard` |
| `SWINGBENCH_HOME` | `/opt/swingbench` | Swingbench installation path |
| `ORACLE_PDB` | `FREEPDB1` | Target PDB |

## HammerDB Fallback

Install the fallback tool only if `Swingbench` is unsuitable for the benchmark scenario:

```bash
scp -i "$TMPKEY" tools/install_hammerdb.sh opc@$PUBLIC_IP:/tmp/
ssh -i "$TMPKEY" opc@$PUBLIC_IP \
  "chmod +x /tmp/install_hammerdb.sh && \
   sudo INSTALL_DIR=/opt/hammerdb INSTALL_OWNER=oracle:oinstall /tmp/install_hammerdb.sh"
```

Sprint 15 does not automate a `HammerDB` Oracle workload yet. The fallback boundary is explicit so a later sprint can switch only when there is a real scenario that `Swingbench` cannot represent.

## Expected Artifacts

- `install-swingbench.log`
- `swingbench_charbench.log`
- `swingbench_config.xml`
- `swingbench_results.xml`
- `swingbench_report.html`
- `swingbench_results_db.json`
- `awr_begin_snap_id.txt`
- `awr_end_snap_id.txt`
- `awr_report.html`

## Latest Validated Run

- Date: `2026-04-23`
- Config source: `config/swingbench/SOE_Server_Side_V2.xml`
- Runtime: `0:05:00`
- Users: `4`
- Completed transactions: `449863`
- Failed transactions: `0`
- Average TPS: `1499.54`
- AWR snapshots: `1 -> 2`
