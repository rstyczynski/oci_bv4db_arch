#!/usr/bin/env bash
# run_oracle_workload.sh — Automated Oracle Database workload execution
#
# This script runs a simple OLTP-style workload against Oracle Database Free.
# It creates a benchmark schema, populates test data, and runs mixed operations.
#
# Prerequisites:
# - Oracle Database Free running with FREEPDB1 open
# - Run as oracle user or with sudo access
#
# Usage: run_oracle_workload.sh [duration_seconds]

set -euo pipefail

WORKLOAD_DURATION="${1:-300}"  # Default 5 minutes
ORACLE_SID="${ORACLE_SID:-FREE}"
ORACLE_PDB="${ORACLE_PDB:-FREEPDB1}"
ORACLE_PWD="${ORACLE_PWD:-BenchmarkPwd123}"
LOG_FILE="${LOG_FILE:-/tmp/workload_results.log}"
BATCH_SIZE="${BATCH_SIZE:-100}"
NUM_WORKERS="${NUM_WORKERS:-4}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Ensure we're running as oracle or can sudo to oracle
run_sql() {
    local sql="$1"
    local connect_string="${2:-}"

    if [ -n "$connect_string" ]; then
        sqlplus -S "$connect_string" <<EOF
SET ECHO OFF
SET FEEDBACK OFF
SET HEADING OFF
SET PAGESIZE 0
SET LINESIZE 1000
SET TRIMSPOOL ON
$sql
EOF
    else
        sqlplus -S / as sysdba <<EOF
SET ECHO OFF
SET FEEDBACK OFF
SET HEADING OFF
SET PAGESIZE 0
SET LINESIZE 1000
SET TRIMSPOOL ON
$sql
EOF
    fi
}

log "=== Oracle Database Workload Execution ==="
log "Duration: ${WORKLOAD_DURATION} seconds"
log "Target PDB: ${ORACLE_PDB}"
log "Batch size: ${BATCH_SIZE}"
log "Workers: ${NUM_WORKERS}"

# Set Oracle environment if not already set
if [ -z "${ORACLE_HOME:-}" ]; then
    export ORACLE_BASE=/opt/oracle
    export ORACLE_HOME=/opt/oracle/product/23ai/dbhomeFree
    export ORACLE_SID=$ORACLE_SID
    export PATH=$ORACLE_HOME/bin:$PATH
    export LD_LIBRARY_PATH=$ORACLE_HOME/lib:${LD_LIBRARY_PATH:-}
fi

# Verify database is accessible
log "Verifying database connection..."
DB_STATUS=$(run_sql "SELECT status FROM v\$instance;" | tr -d '[:space:]')
if [ "$DB_STATUS" != "OPEN" ]; then
    log "ERROR: Database is not OPEN (status: $DB_STATUS)"
    exit 1
fi
log "Database status: $DB_STATUS"

# Verify PDB is open
PDB_STATUS=$(run_sql "SELECT open_mode FROM v\$pdbs WHERE name = UPPER('$ORACLE_PDB');" | tr -d '[:space:]')
if [ "$PDB_STATUS" != "READWRITE" ]; then
    log "Opening PDB $ORACLE_PDB..."
    run_sql "ALTER PLUGGABLE DATABASE $ORACLE_PDB OPEN;"
    sleep 2
fi
log "PDB $ORACLE_PDB status: READ WRITE"

# Create benchmark schema and objects
log "Creating benchmark schema..."
run_sql "
ALTER SESSION SET CONTAINER = $ORACLE_PDB;

-- Drop existing benchmark user if exists
BEGIN
    EXECUTE IMMEDIATE 'DROP USER benchmark CASCADE';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -1918 THEN RAISE; END IF;
END;
/

-- Create benchmark user
CREATE USER benchmark IDENTIFIED BY benchmark123
    DEFAULT TABLESPACE USERS
    TEMPORARY TABLESPACE TEMP
    QUOTA UNLIMITED ON USERS;

GRANT CREATE SESSION, CREATE TABLE, CREATE PROCEDURE, CREATE SEQUENCE TO benchmark;
GRANT SELECT ANY DICTIONARY TO benchmark;

-- Connect as benchmark user and create objects
CONNECT benchmark/benchmark123@localhost:1521/$ORACLE_PDB

-- Create orders table (OLTP-style)
CREATE TABLE orders (
    order_id NUMBER PRIMARY KEY,
    customer_id NUMBER NOT NULL,
    order_date DATE DEFAULT SYSDATE,
    status VARCHAR2(20) DEFAULT 'NEW',
    total_amount NUMBER(12,2),
    shipping_address VARCHAR2(200),
    notes VARCHAR2(500),
    created_at TIMESTAMP DEFAULT SYSTIMESTAMP,
    updated_at TIMESTAMP DEFAULT SYSTIMESTAMP
);

-- Create sequence for order IDs
CREATE SEQUENCE order_seq START WITH 1 INCREMENT BY 1 CACHE 1000;

-- Create index for common queries
CREATE INDEX idx_orders_customer ON orders(customer_id);
CREATE INDEX idx_orders_date ON orders(order_date);
CREATE INDEX idx_orders_status ON orders(status);

-- Populate initial data
BEGIN
    FOR i IN 1..10000 LOOP
        INSERT INTO orders (order_id, customer_id, total_amount, status, shipping_address, notes)
        VALUES (
            order_seq.NEXTVAL,
            MOD(i, 1000) + 1,
            ROUND(DBMS_RANDOM.VALUE(10, 1000), 2),
            CASE MOD(i, 4)
                WHEN 0 THEN 'NEW'
                WHEN 1 THEN 'PROCESSING'
                WHEN 2 THEN 'SHIPPED'
                ELSE 'DELIVERED'
            END,
            'Address ' || i || ', City ' || MOD(i, 100),
            'Order notes for order ' || i
        );
        IF MOD(i, 1000) = 0 THEN
            COMMIT;
        END IF;
    END LOOP;
    COMMIT;
END;
/

-- Gather statistics
EXEC DBMS_STATS.GATHER_TABLE_STATS('BENCHMARK', 'ORDERS');
"

log "Benchmark schema created with 10,000 initial orders"

# Create workload procedure
log "Creating workload procedure..."
run_sql "
CONNECT benchmark/benchmark123@localhost:1521/$ORACLE_PDB

CREATE OR REPLACE PROCEDURE run_workload(
    p_duration_sec IN NUMBER,
    p_batch_size IN NUMBER DEFAULT 100
) AS
    v_start_time TIMESTAMP := SYSTIMESTAMP;
    v_end_time TIMESTAMP;
    v_elapsed_sec NUMBER := 0;
    v_insert_count NUMBER := 0;
    v_update_count NUMBER := 0;
    v_select_count NUMBER := 0;
    v_iter NUMBER := 0;
    v_random_id NUMBER;
    v_dummy NUMBER;
    v_max_id NUMBER;
BEGIN
    -- Get current max order_id
    SELECT NVL(MAX(order_id), 0) INTO v_max_id FROM orders;

    WHILE v_elapsed_sec < p_duration_sec LOOP
        v_iter := v_iter + 1;

        -- Batch INSERT operations (30% of workload)
        FOR i IN 1..CEIL(p_batch_size * 0.3) LOOP
            INSERT INTO orders (order_id, customer_id, total_amount, status, shipping_address, notes)
            VALUES (
                order_seq.NEXTVAL,
                CEIL(DBMS_RANDOM.VALUE(1, 1000)),
                ROUND(DBMS_RANDOM.VALUE(10, 1000), 2),
                'NEW',
                'Address ' || v_iter || '-' || i,
                'Workload order ' || v_iter || '-' || i
            );
            v_insert_count := v_insert_count + 1;
        END LOOP;

        -- Batch UPDATE operations (20% of workload)
        FOR i IN 1..CEIL(p_batch_size * 0.2) LOOP
            v_random_id := CEIL(DBMS_RANDOM.VALUE(1, v_max_id));
            UPDATE orders
            SET status = CASE MOD(v_random_id, 4)
                    WHEN 0 THEN 'PROCESSING'
                    WHEN 1 THEN 'SHIPPED'
                    WHEN 2 THEN 'DELIVERED'
                    ELSE 'CANCELLED'
                END,
                total_amount = total_amount + ROUND(DBMS_RANDOM.VALUE(-10, 10), 2),
                updated_at = SYSTIMESTAMP
            WHERE order_id = v_random_id;
            v_update_count := v_update_count + 1;
        END LOOP;

        -- Batch SELECT operations (50% of workload)
        FOR i IN 1..CEIL(p_batch_size * 0.5) LOOP
            v_random_id := CEIL(DBMS_RANDOM.VALUE(1, 1000));
            SELECT COUNT(*) INTO v_dummy
            FROM orders
            WHERE customer_id = v_random_id;
            v_select_count := v_select_count + 1;
        END LOOP;

        COMMIT;

        -- Update elapsed time
        v_elapsed_sec := EXTRACT(SECOND FROM (SYSTIMESTAMP - v_start_time)) +
                         EXTRACT(MINUTE FROM (SYSTIMESTAMP - v_start_time)) * 60 +
                         EXTRACT(HOUR FROM (SYSTIMESTAMP - v_start_time)) * 3600;

        -- Progress update every 100 iterations
        IF MOD(v_iter, 100) = 0 THEN
            DBMS_OUTPUT.PUT_LINE('Iteration ' || v_iter || ': ' ||
                                 'Inserts=' || v_insert_count ||
                                 ', Updates=' || v_update_count ||
                                 ', Selects=' || v_select_count ||
                                 ', Elapsed=' || ROUND(v_elapsed_sec) || 's');
        END IF;
    END LOOP;

    v_end_time := SYSTIMESTAMP;

    DBMS_OUTPUT.PUT_LINE('=== Workload Complete ===');
    DBMS_OUTPUT.PUT_LINE('Duration: ' || ROUND(v_elapsed_sec) || ' seconds');
    DBMS_OUTPUT.PUT_LINE('Iterations: ' || v_iter);
    DBMS_OUTPUT.PUT_LINE('Total Inserts: ' || v_insert_count);
    DBMS_OUTPUT.PUT_LINE('Total Updates: ' || v_update_count);
    DBMS_OUTPUT.PUT_LINE('Total Selects: ' || v_select_count);
    DBMS_OUTPUT.PUT_LINE('Operations/sec: ' || ROUND((v_insert_count + v_update_count + v_select_count) / v_elapsed_sec, 2));
END;
/
"

log "Workload procedure created"

# Run the workload
log "Starting workload execution (${WORKLOAD_DURATION} seconds)..."
WORKLOAD_START=$(date +%s)

sqlplus -S benchmark/benchmark123@localhost:1521/$ORACLE_PDB <<EOF | tee -a "$LOG_FILE"
SET SERVEROUTPUT ON SIZE UNLIMITED
SET TIMING ON
SET ECHO OFF

DECLARE
    v_start TIMESTAMP := SYSTIMESTAMP;
    v_end TIMESTAMP;
BEGIN
    DBMS_OUTPUT.PUT_LINE('Workload started at: ' || TO_CHAR(v_start, 'YYYY-MM-DD HH24:MI:SS'));
    run_workload($WORKLOAD_DURATION, $BATCH_SIZE);
    v_end := SYSTIMESTAMP;
    DBMS_OUTPUT.PUT_LINE('Workload ended at: ' || TO_CHAR(v_end, 'YYYY-MM-DD HH24:MI:SS'));
END;
/
EOF

WORKLOAD_END=$(date +%s)
ACTUAL_DURATION=$((WORKLOAD_END - WORKLOAD_START))

log "Workload execution completed"
log "Actual duration: ${ACTUAL_DURATION} seconds"

# Get final statistics
log "Collecting final statistics..."
FINAL_COUNT=$(run_sql "
ALTER SESSION SET CONTAINER = $ORACLE_PDB;
SELECT COUNT(*) FROM benchmark.orders;
" | tr -d '[:space:]')

log "Final order count: $FINAL_COUNT"

# Summary
log ""
log "=== Workload Execution Summary ==="
log "Target: $ORACLE_PDB"
log "Duration: $ACTUAL_DURATION seconds"
log "Final order count: $FINAL_COUNT"
log "Log file: $LOG_FILE"
log "==================================="
