# Sprint 18 Implementation

## Implementation summary

Sprint 18 is implemented as a thin wrapper over the hardened Sprint 17 runner.

The wrapper preserves:

1. the Oracle-style multi-volume UHP topology
2. the `fio` phase
3. the Oracle Database Free `Swingbench` phase
4. guest `iostat` capture
5. OCI metrics collection and HTML reporting
6. AWR capture and export

The only intentional behavior change is:

- `FIO_RUNTIME_SEC=900`
- `SWINGBENCH_WORKLOAD_DURATION=900`

Follow-up hardening during execution added:

- database-phase resume controls so Sprint 18 can skip `fio` and, when needed, skip Oracle DB install while reusing the live host
- explicit Oracle Database Free placement enforcement onto `/u02/oradata`, `/u03/redo`, and `/u04/fra`
- boot-volume enrichment for OCI metrics so the report can show both attached block volumes and the instance boot volume in the same evidence set
- live storage correction on the benchmark host so the final database run uses `/u02/oradata` for datafiles and `/u03/redo` for redo members before the final Swingbench execution

## Files introduced

- `tools/run_oracle_db_sprint18.sh`
- `tests/integration/test_oracle_db_sprint18.sh`

## Reused assets

- Sprint 17 consolidated runner and reporting path
- Sprint 15 Swingbench and AWR automation
- existing OCI metrics Markdown and HTML renderer path
