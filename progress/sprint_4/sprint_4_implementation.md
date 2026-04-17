# Sprint 4 — Implementation

## Status: under_construction

## Planned Implementation

- `progress/sprint_4/oracle-layout.fio` — fio workload profile with 3 concurrent jobs
- `tools/run_bv_fio_oracle.sh` — provisions 5 block volumes, configures LVM, runs fio with iostat
- `tests/integration/test_bv4db_oracle.sh` — validates Sprint 4 artifacts

## Key Design Choices

- **Volume layout:** 5 volumes — 2 UHP (data), 2 HP (redo), 1 Balanced (FRA)
- **LVM striping:** vg_data and vg_redo striped across 2 volumes each; FRA direct mount
- **fio profile:** Per-job concurrency settings matching Oracle workload patterns
- **iostat capture:** JSON output for device-level I/O validation

## Block Volume Configuration

| Volume | Device Path | VPU/GB | Size GB | Mount Point |
|--------|-------------|--------|---------|-------------|
| data1 | /dev/oracleoci/oraclevdb | 120 | 200 | /u02/oradata (LVM) |
| data2 | /dev/oracleoci/oraclevdc | 120 | 200 | /u02/oradata (LVM) |
| redo1 | /dev/oracleoci/oraclevdd | 20 | 50 | /u03/redo (LVM) |
| redo2 | /dev/oracleoci/oraclevde | 20 | 50 | /u03/redo (LVM) |
| fra | /dev/oracleoci/oraclevdf | 10 | 100 | /u04/fra |

## fio Job Characteristics

| Job | I/O Pattern | Block Size | Concurrency | Purpose |
|-----|-------------|------------|-------------|---------|
| data-8k | randrw 70/30 | 8k | numjobs=4, iodepth=32 | OLTP data access |
| redo | seq write, fsync=1 | 256k | numjobs=1, iodepth=1 | Redo log sync writes |
| fra-1m | seq rw | 1M | numjobs=2, iodepth=16 | Backup/archive traffic |

## Artifacts

| Artifact | Path | Status |
|----------|------|--------|
| fio profile | `progress/sprint_4/oracle-layout.fio` | Complete |
| Runner script | `tools/run_bv_fio_oracle.sh` | Complete |
| Integration tests | `tests/integration/test_bv4db_oracle.sh` | Skeleton ready |

## Usage

**Smoke run (60 seconds):**

```bash
OCI_REGION=eu-zurich-1 RUN_LEVEL=smoke FIO_RUNTIME_SEC=60 tools/run_bv_fio_oracle.sh
```

**Integration run (15 minutes):**

```bash
OCI_REGION=eu-zurich-1 RUN_LEVEL=integration FIO_RUNTIME_SEC=900 tools/run_bv_fio_oracle.sh
```

## Expected Output

After successful execution:
- `progress/sprint_4/fio-results-oracle-smoke.json` — fio raw output
- `progress/sprint_4/iostat-oracle-smoke.json` — device utilization
- `progress/sprint_4/fio-analysis-oracle-smoke.md` — summary report

## Current Status

- Implementation complete
- Awaiting smoke run execution for artifact validation
