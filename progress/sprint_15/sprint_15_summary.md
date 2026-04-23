# Sprint 15 Summary

## Standard Load Generator

- Primary tool: `Swingbench`
- Fallback tool: `HammerDB`

Sprint 15 completed the transition from the temporary SQL-only workload in Sprint 14 to a standardized `Swingbench` Oracle benchmark path and reran the benchmark with the repository-owned Swingbench configuration file.

## Benchmark Window

- Start: `2026-04-23T14:15:28Z`
- End: `2026-04-23T14:29:14Z`
- AWR begin snapshot: `1`
- AWR end snapshot: `2`

## Swingbench Result

- Benchmark: `"Order Entry (PLSQL) V2"`
- Users: `4`
- Runtime: `0:05:00`
- Config file: `config/swingbench/SOE_Server_Side_V2.xml`
- Completed transactions: `449863`
- Failed transactions: `0`
- Average TPS: `1499.54`
- Maximum transaction rate: `93291`

## Artifact Set

- `swingbench_charbench.log`
- `swingbench_config.xml`
- `swingbench_results.xml`
- `swingbench_report.html`
- `swingbench_results_db.json`
- `awr_begin_snap_id.txt`
- `awr_end_snap_id.txt`
- `awr_report.html`
- `db-install.log`
- `db-status.log`
- `install-swingbench.log`
- `storage-layout.log`

## Infrastructure Outcome

- Compute instance terminated after artifact collection
- Block volume deleted after artifact collection
- Archived state files retained in `progress/sprint_15`
