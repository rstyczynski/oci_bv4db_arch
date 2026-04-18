# Sprint 6 — Tests

## Status: tested

## Smoke Validation Target

- merged `oci_scaffold/oci_bv4db_arch` branch state after syncing from `main`
- `ensure-compute.sh`
- `ensure-blockvolume.sh`
- `teardown-blockvolume.sh`
- scaffold teardown flow

## Success Condition

Sprint 6 passes only if the merged scaffold branch can still create and attach a block volume in this project context and then tear it down cleanly.

## Executed Smoke

- `OCI_REGION=eu-zurich-1 ./tools/run_oci_scaffold_sync_smoke.sh`

## Result

- merged `oci_scaffold/main` into `oci_scaffold/oci_bv4db_arch`
- smoke validation passed for:
  - ephemeral compute creation
  - `ensure-blockvolume.sh` create + attach
  - state recording
  - teardown
- validation script passed:
  - `./tests/integration/test_oci_scaffold_sync.sh`
