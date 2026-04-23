# Sprint 13 Design

Status: tested

Mode:

- `YOLO`

Scope:

- complete `BV4DB-34` by automating Oracle Database Free installation on benchmark host
- complete `BV4DB-35` by automating Oracle Database Free storage layout for OCI block volume tests
- establish database-level benchmark harness on top of existing Oracle Linux and OCI block volume environment
- use minimal required shape with single block volume at this stage

Design choices:

- use Oracle Database Free 23ai as the database engine (latest free version)
- install Oracle Database Free from Oracle Linux yum repository (oracle-database-free-23ai)
- use preinstall RPM to configure OS prerequisites (oracle-database-preinstall-23ai)
- automate database creation using silent mode with response file
- place database storage on OCI block volume mount points matching project conventions (/u02/oradata, /u03/redo, /u04/fra)
- use single block volume with partitions for initial Sprint 13 implementation (single_uhp layout from Sprint 8)
- keep storage layout compatible with multi-volume approach for later sprints
- configure database with minimal SGA/PGA for benchmark host resource efficiency
- use listener on default port 1521
- create pluggable database (PDB) for benchmark workloads
- store database creation artifacts for reproducibility

Implementation approach:

- reuse existing `run_bv_fio_oracle.sh` patterns for compute and block volume provisioning
- create `install_oracle_db_free.sh` script for database software installation
- create `configure_oracle_storage_layout.sh` script for database file placement
- create `run_oracle_db_sprint13.sh` wrapper for Sprint 13 execution
- verify database starts and PDB opens successfully as acceptance test
