# Sprint 14 - Database Workload & AWR Operator Manual

This manual explains how to run database workloads and capture AWR reports on Oracle Database Free 23ai.

## Prerequisites

Before starting, ensure you have:

1. **OCI CLI configured** with valid credentials
2. **SSH key pair** stored in OCI Vault (from Sprint 1 setup)
3. **Shared infrastructure** provisioned (compartment, network, vault from Sprint 1)
4. Oracle Database Free 23ai installed (Sprint 13 or this sprint's automation)

## Option 1: Automated Execution

Run the complete Sprint 14 workflow automatically:

```bash
# Navigate to repository root
cd /path/to/oci_bv4db_arch

# Execute Sprint 14 (provisions, runs workload, captures AWR, tears down)
./tools/run_oracle_db_sprint14.sh

# Custom workload duration (10 minutes):
WORKLOAD_DURATION=600 ./tools/run_oracle_db_sprint14.sh

# Keep infrastructure running after completion:
KEEP_INFRA=true ./tools/run_oracle_db_sprint14.sh
```

## Option 2: Manual Step-by-Step Execution

### Step 1: Provision Infrastructure

Follow Sprint 13 manual for infrastructure provisioning, or use:

```bash
cd /path/to/oci_bv4db_arch
KEEP_INFRA=true ./tools/run_oracle_db_sprint13.sh
```

### Step 2: SSH to Database Host

```bash
# Get SSH key from vault
SECRET_OCID=$(jq -r '.secret.ocid' progress/sprint_1/state-bv4db.json)
TMPKEY=$(mktemp)
chmod 600 "$TMPKEY"
oci secrets secret-bundle get \
  --secret-id "$SECRET_OCID" \
  --query 'data."secret-bundle-content".content' --raw-output \
  | base64 --decode > "$TMPKEY"

# Get public IP from state
PUBLIC_IP=$(jq -r '.compute.public_ip' progress/sprint_14/state-bv4db-oracle-wkld.json)

# Connect
ssh -i "$TMPKEY" -o StrictHostKeyChecking=no opc@$PUBLIC_IP
```

### Step 3: Capture AWR Begin Snapshot

```bash
# On the database host, as oracle user
sudo su - oracle

# Capture begin snapshot
sqlplus / as sysdba <<'EOF'
SET SERVEROUTPUT ON
DECLARE
    v_snap_id NUMBER;
BEGIN
    v_snap_id := DBMS_WORKLOAD_REPOSITORY.CREATE_SNAPSHOT();
    DBMS_OUTPUT.PUT_LINE('Begin Snapshot ID: ' || v_snap_id);
END;
/
EOF
```

Record the snapshot ID (e.g., `BEGIN_SNAP_ID=123`).

### Step 4: Run Database Workload

#### Option A: Use Provided Workload Script

```bash
# Copy script to host (from local machine)
scp -i "$TMPKEY" tools/run_oracle_workload.sh opc@$PUBLIC_IP:/tmp/

# Run workload (5 minutes default)
ssh -i "$TMPKEY" opc@$PUBLIC_IP "sudo su - oracle -c '/tmp/run_oracle_workload.sh 300'"
```

#### Option B: Manual Workload

```bash
# On database host as oracle user
sudo su - oracle
sqlplus / as sysdba
```

```sql
-- Switch to PDB
ALTER SESSION SET CONTAINER = FREEPDB1;

-- Create test schema
CREATE USER benchmark IDENTIFIED BY benchmark123
    DEFAULT TABLESPACE USERS QUOTA UNLIMITED ON USERS;
GRANT CREATE SESSION, CREATE TABLE, CREATE PROCEDURE TO benchmark;

-- Connect as benchmark user
CONNECT benchmark/benchmark123@localhost:1521/FREEPDB1

-- Create test table
CREATE TABLE orders (
    order_id NUMBER PRIMARY KEY,
    customer_id NUMBER,
    order_date DATE DEFAULT SYSDATE,
    total_amount NUMBER(12,2)
);

CREATE SEQUENCE order_seq;

-- Run some workload
BEGIN
    FOR i IN 1..10000 LOOP
        INSERT INTO orders VALUES (order_seq.NEXTVAL, MOD(i, 100), SYSDATE, i * 1.5);
        IF MOD(i, 100) = 0 THEN COMMIT; END IF;
    END LOOP;
    COMMIT;
END;
/

-- Run queries
SELECT COUNT(*) FROM orders;
SELECT customer_id, SUM(total_amount) FROM orders GROUP BY customer_id;
```

### Step 5: Capture AWR End Snapshot

```bash
# As oracle user
sqlplus / as sysdba <<'EOF'
SET SERVEROUTPUT ON
DECLARE
    v_snap_id NUMBER;
BEGIN
    v_snap_id := DBMS_WORKLOAD_REPOSITORY.CREATE_SNAPSHOT();
    DBMS_OUTPUT.PUT_LINE('End Snapshot ID: ' || v_snap_id);
END;
/
EOF
```

Record the snapshot ID (e.g., `END_SNAP_ID=124`).

### Step 6: Generate AWR Report

```bash
# As oracle user
# Replace BEGIN_SNAP_ID and END_SNAP_ID with actual values

sqlplus / as sysdba <<'EOF'
SET ECHO OFF
SET FEEDBACK OFF
SET LINESIZE 8000
SET PAGESIZE 0
SET LONG 1000000
SET LONGCHUNKSIZE 1000000
SET TRIMSPOOL ON

-- Get DBID and instance number
COLUMN dbid NEW_VALUE v_dbid
COLUMN inst_num NEW_VALUE v_inst_num
SELECT dbid FROM v$database;
SELECT instance_number AS inst_num FROM v$instance;

SPOOL /tmp/awr_report.html

SELECT output
FROM TABLE(DBMS_WORKLOAD_REPOSITORY.AWR_REPORT_HTML(
    l_dbid => &v_dbid,
    l_inst_num => &v_inst_num,
    l_bid => 123,  -- Replace with BEGIN_SNAP_ID
    l_eid => 124   -- Replace with END_SNAP_ID
));

SPOOL OFF
EXIT;
EOF
```

### Step 7: Collect Artifacts

```bash
# From local machine
scp -i "$TMPKEY" opc@$PUBLIC_IP:/tmp/awr_report.html ./progress/sprint_14/
scp -i "$TMPKEY" opc@$PUBLIC_IP:/tmp/workload_results.log ./progress/sprint_14/
```

## AWR Report Interpretation

### Key Sections to Review

| Section | What to Look For |
|---------|------------------|
| **Load Profile** | DB Time, Redo size, Logical/Physical reads per second |
| **Top 5 Timed Events** | Where database is spending time (I/O waits, CPU, etc.) |
| **SQL Statistics** | Top SQL by elapsed time, CPU, I/O |
| **Instance Efficiency** | Buffer cache hit ratio, library cache hit ratio |
| **I/O Statistics** | Read/Write throughput by tablespace and datafile |
| **Wait Events** | Detailed breakdown of wait times |

### Common Wait Events

| Event | Meaning |
|-------|---------|
| `db file sequential read` | Single block reads (index lookups) |
| `db file scattered read` | Multi-block reads (full table scans) |
| `log file sync` | Commit wait for redo write |
| `log file parallel write` | LGWR writing redo to disk |
| `direct path read/write` | Direct I/O bypassing buffer cache |

## Workload Script Parameters

The `run_oracle_workload.sh` script accepts these environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `WORKLOAD_DURATION` | 300 | Duration in seconds |
| `BATCH_SIZE` | 100 | Operations per iteration |
| `NUM_WORKERS` | 4 | Concurrent threads (future) |
| `ORACLE_PDB` | FREEPDB1 | Target PDB |
| `LOG_FILE` | /tmp/workload_results.log | Output log |

Example:

```bash
WORKLOAD_DURATION=600 BATCH_SIZE=200 ./run_oracle_workload.sh
```

## AWR Snapshot Management

### List Recent Snapshots

```sql
SELECT snap_id,
       TO_CHAR(begin_interval_time, 'YYYY-MM-DD HH24:MI') AS begin_time,
       TO_CHAR(end_interval_time, 'YYYY-MM-DD HH24:MI') AS end_time
FROM dba_hist_snapshot
ORDER BY snap_id DESC
FETCH FIRST 10 ROWS ONLY;
```

### Manual Snapshot

```sql
-- Create immediate snapshot
EXEC DBMS_WORKLOAD_REPOSITORY.CREATE_SNAPSHOT();

-- Create snapshot with flush level
EXEC DBMS_WORKLOAD_REPOSITORY.CREATE_SNAPSHOT('ALL');
```

### Modify Snapshot Retention

```sql
-- Check current settings
SELECT * FROM dba_hist_wr_control;

-- Modify retention (days) and interval (minutes)
EXEC DBMS_WORKLOAD_REPOSITORY.MODIFY_SNAPSHOT_SETTINGS(
    retention => 10080,  -- 7 days in minutes
    interval  => 30      -- snapshot every 30 minutes
);
```

### Delete Old Snapshots

```sql
-- Delete snapshots in range
EXEC DBMS_WORKLOAD_REPOSITORY.DROP_SNAPSHOT_RANGE(
    low_snap_id  => 100,
    high_snap_id => 110
);
```

## Troubleshooting

### AWR Report Generation Fails

```sql
-- Check if AWR is enabled
SELECT * FROM dba_hist_wr_control;

-- Verify snapshots exist
SELECT COUNT(*) FROM dba_hist_snapshot;

-- Check for space issues
SELECT tablespace_name, bytes/1024/1024 AS mb_used
FROM dba_segments
WHERE owner = 'SYS'
AND segment_name LIKE 'WR%';
```

### Workload Script Errors

```bash
# Check Oracle environment
echo $ORACLE_HOME
echo $ORACLE_SID

# Verify database is open
sqlplus / as sysdba -S <<< "SELECT status FROM v\$instance;"

# Check listener
lsnrctl status
```

### Cannot Connect to PDB

```sql
-- Open PDB if closed
ALTER PLUGGABLE DATABASE FREEPDB1 OPEN;

-- Save state for automatic open
ALTER PLUGGABLE DATABASE FREEPDB1 SAVE STATE;

-- Check PDB status
SELECT name, open_mode FROM v$pdbs;
```

## Artifacts Reference

| File | Description |
|------|-------------|
| `awr_report.html` | AWR HTML report for benchmark window |
| `workload_results.log` | Workload execution output and statistics |
| `awr_begin_snap_id.txt` | Starting snapshot ID |
| `awr_end_snap_id.txt` | Ending snapshot ID |
| `db-status.log` | Database status after workload |
| `db-install.log` | Database installation log |
| `storage-layout.log` | Storage configuration log |

## Quick Reference Commands

```bash
# Run full Sprint 14 automation
./tools/run_oracle_db_sprint14.sh

# Run with custom duration (10 minutes)
WORKLOAD_DURATION=600 ./tools/run_oracle_db_sprint14.sh

# Keep infrastructure for manual inspection
KEEP_INFRA=true ./tools/run_oracle_db_sprint14.sh

# Run workload only (on existing database)
ssh opc@<IP> "sudo su - oracle -c '/tmp/run_oracle_workload.sh 300'"

# Capture AWR snapshot
ssh opc@<IP> "sudo su - oracle -c '/tmp/capture_awr_snapshot.sh begin'"

# Export AWR report
ssh opc@<IP> "sudo su - oracle -c '/tmp/export_awr_report.sh 123 124 /tmp/awr.html'"
```
