# Sprint 30 - Agent Work Context

Updated: 2026-08-18

## Current request and approved scope

- BV4DB-72 is a **FIO-only** single-path iSCSI tuning sprint.
- Target compute: `VM.Standard.E5.Flex`, exactly 4 OCPUs / 32 GB, Oracle Linux
  9 pinned image, eight guest vCPUs expected but discovered at runtime.
- Test volume tier: **50 VPUs/GB only**. 30 and 120 are separate future backlog
  items; 45 was replaced after OCI rejected it.
- Layout: DATA 2x200 GB (`oraclevdb/c`), REDO 2x50 GB (`oraclevdd/e`), FRA
  1x100 GB (`oraclevdf`), matching the established Oracle-style project layout.
- No Oracle Database workload or installation.
- The boot volume is excluded from FIO, LVM/filesystem setup, iSCSI mutation,
  candidate tuning, evidence, and teardown.

## OCI authentication and feasibility facts

- `oci` with the `DEFAULT` profile authenticates to the active
  `oci_bv4db_arch` compartment in `eu-zurich-1`.
- A 45-VPU/GB volume create was rejected by OCI with HTTP 400 `InvalidParameter`:
  `vpusPerGB is invalid or incorrectly formatted.`
- Evidence is the ASCII file `oci_45_vpu_feasibility_20260818_120501.log`.
- A direct CLI feasibility probe confirmed OCI accepts 50 VPUs/GB.

## Cleanup completed

All temporary direct-CLI resources have been removed:

- first 4-OCPU probe instance: terminated with boot-volume deletion;
- second temporary 4-OCPU instance: terminated with boot-volume deletion;
- five direct-created 50-VPU Block Volumes: deleted after detaching;
- one unintended 50-GB replacement created during failed adoption: detached and
  deleted.

No guest storage initialization, FIO, tuning setting, or boot-volume change
occurred. No live benchmark resource remains active.

## Mandatory project approach going forward

Use `oci_scaffold` exactly as the project does from Sprint 1 onward:

1. Start from `progress/sprint_1/state-bv4db.json` for the shared compartment,
   subnet, Vault secret, and SSH public key.
2. Create a fresh Sprint 30 output/state directory.
3. Use `oci_scaffold/do/oci_scaffold.sh`, `ensure-compute.sh`, and a separate
   fresh `ensure-blockvolume.sh` state file per DATA/REDO/FRA volume.
4. Set the following scaffold inputs before each volume helper:
   `bv_attach_type=iscsi`, `bv_is_multipath=false`, `bv_vpus_per_gb=50`, exact
   size, and exact `/dev/oracleoci/oraclev*` device path.
5. Let the scaffold own all freshly created resources and use its teardown path.
   Do not create, attach, adopt, or delete benchmark resources with ad-hoc OCI
   CLI commands.

## Repository state

- `progress/sprint_30/sprint_30_design.md` is user accepted, but parts of the
  detailed prose still need a systematic 45-to-50 consistency pass.
- `tools/oci_bv_single_path_tuning.sh` provides a deterministic 50-VPU plan,
  coverage ledger, local preflight fixture validation, and state-fault fixtures.
  It does **not** yet implement the remote guest executor/FIO/report pipeline.
- `tests/integration/test_bv4db_iscsi_tuning.sh` has IT-1--IT-4 passing local
  checks; IT-5--IT-10 deliberately fail until real live evidence exists.
- Initial A3 log: `test_run_A3_integration_20260818_120356.log` (4 passed,
  6 failed for missing live evidence). B3 has not run.
- `tests/manifests/component_iscsi_tuning.manifest` is intentionally the only
  B3 regression group; do not add unrelated historical Oracle/multipath tests.

## Known implementation issue to repair first

`tools/oci_bv_single_path_tuning.sh` contains an experimental
`provision_with_scaffold` adopter. Do not use it as-is. It attempted to adopt
already attached direct-created volumes, while `ensure-blockvolume.sh` requires
a reusable `AVAILABLE` volume and therefore created a replacement. Replace the
adopter with a fresh-resource-only scaffold flow as described above.

## Next work sequence

1. Complete the systematic 50-VPU update in design/test/setup/runner wording.
2. Replace the experimental adopter with a fresh `oci_scaffold` provisioning
   flow modelled on `tools/run_bv_fio_oracle.sh`, but with plugin/multipath
   behavior removed and `bv_is_multipath=false`.
3. Implement the actual remote executor: one iSCSI login per target, guarded
   fresh-empty layout initialization, baseline capture, candidate application,
   FIO, evidence collection, restoration, canaries, reports, and scaffold
   teardown.
4. Fill the existing IT-5--IT-10 skeleton functions to invoke/validate the
   real executor. Do not add new test cases.
5. Run A3 with timestamped ASCII log; only after A3 passes run B3 scoped to
   `iscsi_tuning`. Produce `sprint_30_tests.md` and then documentation phase.
