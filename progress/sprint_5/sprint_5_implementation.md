# Sprint 5 — Implementation

## Status: tested

## Intent

Sprint 5 is the corrective rerun of Sprint 4.

The infrastructure topology remains the same as Sprint 4. The primary change is the fio workload description, which is replaced with the corrected profile in `progress/sprint_5/oracle-layout.fio` so that per-job reporting is preserved.

## Reuse Strategy

- reuse Sprint 4 runner logic
- reuse Sprint 4 storage layout and OCI resource configuration
- reuse Sprint 4 analysis method and test structure
- only change the fio workload definition file and any minimal runner wiring needed to point to Sprint 5 artifacts

## Planned Deliverables

- corrected fio profile file
- rerun script adjustments if needed to point to Sprint 5 artifacts
- raw fio JSON result with distinct jobs
- raw `iostat` JSON result
- updated analysis based on valid per-job fio output

## Outcome

- reusable Oracle runner logic updated to support Sprint-specific artifact directories and labels
- Sprint 5 wrapper created at `tools/run_bv_fio_oracle_sprint5.sh`
- Sprint 5 smoke and integration runs completed successfully
- corrected fio output preserved workload-level reporting with four `data-8k` worker records plus `redo` and `fra-1m`
- automatic teardown completed for compute and all five block volumes
