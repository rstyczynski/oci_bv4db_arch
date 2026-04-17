# Sprint 2 — Implementation

## Status: tested

## Implemented Flow

Sprint 2 extends the Sprint 1 benchmark flow with a dedicated high-performance path:

- `tools/run_bv_fio_perf.sh` reuses Sprint 1 shared infra and runs the Sprint 2 benchmark
- `oci_scaffold/resource/ensure-blockvolume.sh` accepts Sprint 2 UHP inputs and records the effective attachment properties
- `tests/integration/test_bv4db_perf.sh` validates the archived Sprint 2 run artifacts after automatic teardown
- `tools/run_bv_fio_perf.sh` enables the OCI Block Volume Management plugin, establishes guest iSCSI sessions explicitly, enables multipath, resolves the benchmark device as `/dev/mapper/mpatha`, and executes fio as remote background jobs with explicit completion polling

## Key Design Choices

- Compute shape: `VM.Standard.E5.Flex`
- Compute OCPUs: `40`
- Block volume size: `1500 GB`
- Block volume VPUs/GB: `120`
- Attachment type: `iscsi`
- Consistent device path: `/dev/oracleoci/oraclevdb`
- fio runtime split: `30s` sequential + `30s` random = `60s` total

## Execution Result

- Sprint 2 benchmark completed in `eu-zurich-1`
- Raw result artifact: `progress/sprint_2/fio-results-perf.json`
- Sequential result artifact: `progress/sprint_2/fio-results-perf-sequential.json`
- Random result artifact: `progress/sprint_2/fio-results-perf-random.json`
- Analysis artifact: `progress/sprint_2/fio_analysis.md`
- Archived teardown state: `progress/sprint_2/state-bv4db-perf-run.deleted-20260417T150539.json`
- Integration verification: `tests/integration/test_bv4db_perf.sh` passed `5/5`
