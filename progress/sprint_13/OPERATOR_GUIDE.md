# Sprint 13 - Oracle Database Free Operator Guide

This guide explains how to manually set up and interact with Oracle Database Free 23ai on an OCI compute instance with block volume storage.

## Prerequisites

Before starting, ensure you have:

1. **OCI CLI configured** with valid credentials
2. **SSH key pair** stored in OCI Vault (from Sprint 1 setup)
3. **Shared infrastructure** provisioned (compartment, network, vault from Sprint 1)
4. Access to the Sprint 1 state file: `progress/sprint_1/state-bv4db.json`

## Option 1: Automated Execution

Run the complete Sprint 13 workflow automatically:

```bash
# Navigate to repository root
cd /path/to/oci_bv4db_arch

# Execute Sprint 13 (provisions, installs, tears down)
./tools/run_oracle_db_sprint13.sh

# To keep infrastructure running after completion:
KEEP_INFRA=true ./tools/run_oracle_db_sprint13.sh
```

## Option 2: Manual Step-by-Step Setup

### Step 1: Provision Compute Instance

```bash
cd /path/to/oci_bv4db_arch
export PATH="$PWD/oci_scaffold/do:$PWD/oci_scaffold/resource:$PATH"
export PROGRESS_DIR="$PWD/progress/sprint_13"
mkdir -p "$PROGRESS_DIR"
cd "$PROGRESS_DIR"

# Load shared infrastructure IDs
INFRA_STATE="../sprint_1/state-bv4db.json"
export COMPARTMENT_OCID=$(jq -r '.compartment.ocid' "$INFRA_STATE")
export SUBNET_OCID=$(jq -r '.subnet.ocid' "$INFRA_STATE")
PUBKEY_FILE="../sprint_1/bv4db-key.pub"

# Configure compute
export NAME_PREFIX="bv4db-oracle-db"
export STATE_FILE="$PROGRESS_DIR/state-${NAME_PREFIX}.json"

# Initialize state
source ../oci_scaffold/do/oci_scaffold.sh
_state_set '.inputs.name_prefix' "$NAME_PREFIX"
_state_set '.inputs.oci_compartment' "$COMPARTMENT_OCID"
_state_set '.subnet.ocid' "$SUBNET_OCID"
_state_set '.inputs.compute_shape' "VM.Standard.E5.Flex"
_state_set '.inputs.compute_ocpus' "2"
_state_set '.inputs.compute_memory_gb' "16"
_state_set '.inputs.subnet_prohibit_public_ip' 'false'
_state_set '.inputs.compute_ssh_authorized_keys_file' "$PUBKEY_FILE"

# Provision
ensure-compute.sh
```

### Step 2: Provision Block Volume

```bash
export NAME_PREFIX="bv-singleuhp"
export STATE_FILE="$PROGRESS_DIR/state-bv-singleuhp.json"
INSTANCE_OCID=$(jq -r '.compute.ocid' "$PROGRESS_DIR/state-bv4db-oracle-db.json")

_state_set '.inputs.name_prefix' "$NAME_PREFIX"
_state_set '.inputs.oci_compartment' "$COMPARTMENT_OCID"
_state_set '.inputs.bv_size_gb' "600"
_state_set '.inputs.bv_vpus_per_gb' "10"
_state_set '.inputs.bv_attach_type' 'iscsi'
_state_set '.inputs.bv_device_path' "/dev/oracleoci/oraclevdb"
_state_set '.compute.ocid' "$INSTANCE_OCID"

ensure-blockvolume.sh
```

### Step 3: Connect via SSH

```bash
# Get SSH key from vault
SECRET_OCID=$(jq -r '.secret.ocid' "../sprint_1/state-bv4db.json")
TMPKEY=$(mktemp)
chmod 600 "$TMPKEY"
oci secrets secret-bundle get \
  --secret-id "$SECRET_OCID" \
  --query 'data."secret-bundle-content".content' --raw-output \
  | base64 --decode > "$TMPKEY"

# Get public IP
PUBLIC_IP=$(jq -r '.compute.public_ip' "$PROGRESS_DIR/state-bv4db-oracle-db.json")

# Connect
ssh -i "$TMPKEY" -o StrictHostKeyChecking=no opc@$PUBLIC_IP
```

### Step 4: Configure Storage Layout (on remote host)

```bash
# Copy and run storage layout script
scp -i "$TMPKEY" tools/configure_oracle_db_layout.sh opc@$PUBLIC_IP:/tmp/
ssh -i "$TMPKEY" opc@$PUBLIC_IP "chmod +x /tmp/configure_oracle_db_layout.sh && \
  sudo STORAGE_LAYOUT_MODE=single_uhp \
       SINGLE_DEV='/dev/oracleoci/oraclevdb' \
       /tmp/configure_oracle_db_layout.sh"
```

### Step 5: Install Oracle Database Free (on remote host)

```bash
# Copy and run installation script
scp -i "$TMPKEY" tools/install_oracle_db_free.sh opc@$PUBLIC_IP:/tmp/
ssh -i "$TMPKEY" opc@$PUBLIC_IP "chmod +x /tmp/install_oracle_db_free.sh && \
  sudo ORACLE_PWD='YourSecurePassword123' \
       /tmp/install_oracle_db_free.sh"
```

## Interacting with Oracle Database

### Connecting via SQL*Plus

SSH to the instance, then:

```bash
# Switch to oracle user
sudo su - oracle

# Set environment (automatically sourced from ~/.bashrc)
source ~/.oracle_env

# Connect to CDB as SYSDBA
sqlplus / as sysdba

# Connect to PDB
sqlplus sys/YourSecurePassword123@localhost:1521/FREEPDB1 as sysdba
```

### Database Connection Details

| Parameter | Value |
|-----------|-------|
| Oracle Home | `/opt/oracle/product/23ai/dbhomeFree` |
| SID | `FREE` |
| PDB Name | `FREEPDB1` |
| Listener Port | `1521` |
| Character Set | `AL32UTF8` |
| SYS Password | (set during installation) |

### Common SQL*Plus Commands

```sql
-- Check instance status
SELECT instance_name, status, database_status FROM v$instance;

-- Check PDB status
SELECT name, open_mode FROM v$pdbs;

-- Open PDB if closed
ALTER PLUGGABLE DATABASE FREEPDB1 OPEN;

-- Switch to PDB
ALTER SESSION SET CONTAINER = FREEPDB1;

-- Show database files
SELECT name FROM v$datafile;

-- Show redo logs
SELECT member FROM v$logfile;

-- Show database parameters
SHOW PARAMETER sga_target;
SHOW PARAMETER pga_aggregate_target;
SHOW PARAMETER db_create_file_dest;

-- Create test table
CREATE TABLE test_table (id NUMBER, name VARCHAR2(100));
INSERT INTO test_table VALUES (1, 'Test Record');
COMMIT;
SELECT * FROM test_table;

-- Exit SQL*Plus
EXIT;
```

### Listener Management

```bash
# As oracle user
source ~/.oracle_env

# Check listener status
lsnrctl status

# Start listener
lsnrctl start

# Stop listener
lsnrctl stop
```

### Database Startup/Shutdown

```bash
# As oracle user
source ~/.oracle_env
sqlplus / as sysdba
```

```sql
-- Shutdown database
SHUTDOWN IMMEDIATE;

-- Startup database
STARTUP;

-- Open all PDBs
ALTER PLUGGABLE DATABASE ALL OPEN;

-- Save PDB state (auto-open on startup)
ALTER PLUGGABLE DATABASE FREEPDB1 SAVE STATE;
```

## Mount Points and Storage

| Mount Point | Purpose | Filesystem |
|-------------|---------|------------|
| `/u02/oradata` | Oracle Data Files | LVM striped ext4 |
| `/u03/redo` | Redo Logs | LVM striped ext4 |
| `/u04/fra` | Fast Recovery Area | ext4 |

To verify storage layout:

```bash
df -h /u02/oradata /u03/redo /u04/fra
lsblk
sudo vgs
sudo lvs
```

## Teardown

### Manual Teardown

```bash
cd /path/to/oci_bv4db_arch/progress/sprint_13
export PATH="../oci_scaffold/do:../oci_scaffold/resource:$PATH"

# Teardown block volume
NAME_PREFIX="bv-singleuhp" STATE_FILE="state-bv-singleuhp.json" teardown.sh

# Teardown compute
NAME_PREFIX="bv4db-oracle-db" STATE_FILE="state-bv4db-oracle-db.json" teardown.sh
```

## Troubleshooting

### Database Won't Start

```bash
# Check alert log
sudo su - oracle
tail -100 $ORACLE_BASE/diag/rdbms/free/FREE/trace/alert_FREE.log
```

### Listener Not Running

```bash
sudo su - oracle
source ~/.oracle_env
lsnrctl start
```

### PDB Won't Open

```sql
-- Connect as SYSDBA
sqlplus / as sysdba

-- Check PDB violations
SELECT name, cause, message FROM pdb_plug_in_violations WHERE status='PENDING';

-- Force open
ALTER PLUGGABLE DATABASE FREEPDB1 OPEN FORCE;
```

### Storage Mount Issues

```bash
# Verify LVM is active
sudo vgchange -ay

# Remount if needed
sudo mount /dev/vg_data/lv_oradata /u02/oradata
sudo mount /dev/vg_redo/lv_redo /u03/redo
# FRA partition - find correct device
sudo mount /dev/sdb5 /u04/fra  # adjust device as needed
```
