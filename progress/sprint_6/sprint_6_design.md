# Sprint 6 - Design

## BV4DB-11. Sync oci_scaffold branch with upstream main and smoke-validate block volume ensure

Status: Accepted

## Execution Mode

- Sprint 6 runs in `YOLO` mode.
- Reason: this is a maintenance sprint with a bounded scaffold sync plus a trivial smoke validation.

## Scope

- merge `oci_scaffold/main` into `oci_scaffold/oci_bv4db_arch`
- keep using the `oci_bv4db_arch` branch after the merge
- run a minimal smoke validation against the merged submodule state
- validate only:
  - ephemeral compute creation
  - `ensure-blockvolume.sh` volume creation and attachment
  - clean teardown

## Smoke Shape

- reuse Sprint 1 shared infra state
- launch a small ephemeral compute instance
- create and attach one small block volume using `ensure-blockvolume.sh`
- record the resulting state
- tear the resources down
