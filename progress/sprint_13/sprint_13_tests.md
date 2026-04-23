# Sprint 13 Tests

## Integration Tests

### IT-13-01: Oracle Database Free Installation

Validates that Oracle Database Free 23ai is installed without interactive prompts.

**Criteria:**
- oracle-database-preinstall-23ai package installed
- oracle-database-free-23ai package installed
- Oracle home exists at /opt/oracle/product/23ai/dbhomeFree
- Database binaries are executable

### IT-13-02: Database Storage Layout

Validates that database storage is placed on OCI block volume mount points.

**Criteria:**
- /u02/oradata mount point exists and is writable by oracle user
- /u03/redo mount point exists and is writable by oracle user
- /u04/fra mount point exists and is writable by oracle user
- Mount points are backed by block volume (not root filesystem)

### IT-13-03: Database Creation and Startup

Validates that database is created and starts successfully.

**Criteria:**
- CDB instance (FREE) is running
- PDB (FREEPDB1) is open in READ WRITE mode
- Listener is running on port 1521
- Database files exist under configured mount points
- Control files, redo logs, and datafiles are accessible

### IT-13-04: Database Connectivity

Validates that database is accessible for benchmark workloads.

**Criteria:**
- SQL*Plus can connect to CDB as SYSDBA
- SQL*Plus can connect to PDB
- Basic SQL operations succeed (SELECT, CREATE TABLE, INSERT)
