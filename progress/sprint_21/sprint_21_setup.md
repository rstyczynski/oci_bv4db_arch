# Sprint 21 - Setup

Status: None

## Goal

Redo Sprint 20 with one new operational capability:

- Persist and control the block-volume mount via `/etc/fstab` using Oracle-recommended options (`_netdev,nofail`).

Sprint 21 keeps Sprint 20 capabilities:

- provisioning/adopting one compute instance + one UHP block volume
- multipath diagnostics sandbox flow
- A/B benchmark (multipath vs single-path)
- automated execution scripts + operator manual execution snippets
- integration test coverage

## Backlog Items

- BV4DB-52. Persist block-volume mount in /etc/fstab with _netdev,nofail

## Entry points

- `tools/run_bv4db_multipath_diag_sprint21.sh`
- `tools/run_bv4db_fio_multipath_ab_sprint21.sh`

