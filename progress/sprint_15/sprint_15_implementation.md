# Sprint 15 Implementation

## Managed Decisions

1. **Standard load generator**: `Swingbench` is the only automated load path in Sprint 15, because this sprint is about standardization rather than running two benchmark harnesses in parallel.
2. **Fallback scope**: `HammerDB` is prepared as a documented installer and operator fallback boundary, but not turned into a second automated benchmark path until a real scenario requires it.
3. **Artifact set**: Sprint 15 archives both `Swingbench` files and the latest `BENCHMARK_RESULTS` row so later sprints can compare runs without re-parsing raw console output.

## Execution Summary

Sprint 15 standardizes Oracle Database Free load generation by replacing the temporary SQL workload from Sprint 14 with an Oracle-focused `Swingbench` flow:

1. install `Swingbench` on the benchmark host with Java 17
2. build a repeatable SOE schema with `oewizard`
3. run CLI load generation with `charbench`
4. preserve the Sprint 14 AWR begin/end snapshot and export workflow
5. render a standalone HTML dashboard from the archived Swingbench result set
6. archive `Swingbench` XML, HTML, database-exported JSON, and AWR artifacts for later scenario comparisons

## Executed Run

The Sprint 15 benchmark was rerun successfully on `2026-04-23` against Oracle Database Free `FREEPDB1` with the project-owned config file `config/swingbench/SOE_Server_Side_V2.xml` and:

- `Swingbench` `2.7.0.1561`
- `charbench` runtime `300` seconds
- `4` users
- SOE scale `1`
- AWR snapshot window `1 -> 2`

Observed outcome from the archived Swingbench XML:

- benchmark: `"Order Entry (PLSQL) V2"`
- total run time: `0:05:00`
- completed transactions: `449863`
- failed transactions: `0`
- average transactions per second: `1499.54`
- maximum transaction rate: `93291`

## Fixes Applied During Live Execution

Two script defects were found and corrected during the live run:

1. `capture_awr_snapshot.sh` needed `SET SERVEROUTPUT ON` so the created snapshot ID could be read back reliably.
2. `run_oracle_swingbench.sh` needed Oracle dynamic performance view SQL protected from shell expansion under `set -u`.

One artifact-handling issue was also corrected:

3. `run_oracle_db_sprint15.sh` now normalizes remote file permissions before copying `Swingbench` and AWR artifacts back to the repository.

One reporting enhancement was added after the successful run:

4. `render_swingbench_report_html.sh` now converts Swingbench XML and runtime log output into a standalone HTML dashboard artifact.

One reproducibility improvement was added for project ownership:

5. the active Swingbench config now lives in `config/swingbench/SOE_Server_Side_V2.xml` and the sprint runner archives it as `progress/sprint_15/swingbench_config.xml`.

The live rerun confirmed that this repo-owned file is now the effective benchmark definition used by the OCI execution path.

## Scripts Created

- `tools/install_swingbench.sh` - installs the current public `Swingbench` build
- `tools/install_hammerdb.sh` - installs the documented HammerDB fallback
- `tools/run_oracle_swingbench.sh` - builds and runs the standardized `Swingbench` workload
- `tools/run_oracle_db_sprint15.sh` - complete Sprint 15 execution wrapper
- `tools/render_swingbench_report_html.sh` - renders an HTML dashboard from archived Swingbench artifacts
- `config/swingbench/SOE_Server_Side_V2.xml` - project-owned Swingbench workload definition

## User Documentation

See [sprint15_manual.md](sprint15_manual.md) for:

- automatic Sprint 15 execution
- manual `Swingbench` installation and workload commands
- artifact locations
- `HammerDB` fallback guidance
