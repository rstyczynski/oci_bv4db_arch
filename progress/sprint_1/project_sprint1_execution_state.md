---
name: Sprint 1 execution state
description: Current Sprint 1 state after moving shared and ephemeral infra to eu-zurich-1
type: project
originSessionId: 3b7c87ed-c09b-4c61-bf0c-bf59f56b1864
---
## Where we are

Sprint 1 Phase 4 completed successfully in `eu-zurich-1`. Shared infra remains in Zurich; the ephemeral compute stack was torn down after fio and integration test completion.

## Current live state

1. Shared Sprint 1 infra was recreated in `eu-zurich-1`:
   - compartment reused: `ocid1.compartment.oc1..aaaaaaaaoyzrzkwxz3ufozjom4cmxwpwwsir3sccbu6e46wnlwvtmlq7d22a`
   - active state file: `progress/sprint_1/state-bv4db.json`
2. Old Frankfurt state was archived:
   - `progress/sprint_1/state-bv4db.frankfurt-retired-20260417T123601.json`
   - `progress/sprint_1/state-bv4db-run.frankfurt-retired-20260417T123601.json`
3. Frankfurt network resources were torn down. Frankfurt vault, key, and secret are only **scheduled for deletion** by OCI and cannot be removed immediately.
4. Zurich compute launch and fio execution were verified successfully during Phase 4.
   - current ephemeral state is archived, not live
   - latest archived run state: `progress/sprint_1/state-bv4db-run.deleted-20260417T130110.json`

## Fixes applied during move

1. `oci_scaffold/do/oci_scaffold.sh` already syncs `OCI_CLI_REGION` from `OCI_REGION`, so OCI CLI calls follow the requested region.
2. `tools/setup_infra.sh` was fixed for region moves:
   - if the public key file exists but the vault secret does not, the script now rotates the SSH keypair and recreates the secret so both stay consistent
3. OCI CLI 3.63 secret retrieval command was updated across Sprint 1:
   - from `oci vault secret get-secret-bundle`
   - to `oci secrets secret-bundle get`

## Result

1. `tools/run_bv_fio.sh` completed successfully in `eu-zurich-1`.
2. `tests/integration/test_bv4db.sh` passed all four tests in `eu-zurich-1`.
3. The ephemeral compute and block volume were torn down and archived to:
   - `progress/sprint_1/state-bv4db-run.deleted-20260417T130110.json`
4. The active shared infra state is:
   - `progress/sprint_1/state-bv4db.json`

## Resume from here

If another live verification run is needed:

```bash
cd /Users/rstyczynski/projects/oci_bv4db_arch
KEEP_INFRA=true OCI_REGION=eu-zurich-1 OCI_CLI_REGION=eu-zurich-1 ./tools/run_bv_fio.sh
OCI_REGION=eu-zurich-1 OCI_CLI_REGION=eu-zurich-1 ./tests/integration/test_bv4db.sh
OCI_REGION=eu-zurich-1 OCI_CLI_REGION=eu-zurich-1 NAME_PREFIX=bv4db-run ./oci_scaffold/do/teardown.sh
```
