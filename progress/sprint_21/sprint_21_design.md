# Sprint 21 - Design

Status: None

## Scope

- Redo Sprint 20 tooling and operator workflow for:
  - UHP iSCSI multipath diagnostics sandbox
  - A/B benchmark: multipath vs single-path (fio preferred, dd fallback)
- Add `/etc/fstab` workflow to make the mount reboot-safe and operator-controlled:
  - write/replace an fstab entry for the benchmark mountpoint
  - use Oracle-recommended options: `_netdev,nofail`
  - document how to enable/disable multipath using fstab + iSCSI session control

## Key decisions (YOLO)

- `/etc/fstab` is managed by scripts using a tagged entry line (marker comment) so it can be updated/disabled safely.
- `fstab` is used for persistence and for operator learning. The scripts still mount explicitly for immediate execution.
- Single-path mode uses a **raw** iSCSI by-path device (auto-discovered LUN), not `/dev/mapper/mpath*`.

## Outputs

- Diagnostics artifacts for each mode.
- fio JSON results for each mode (preferred).
- dd results for each mode (fallback).
- Comparison summary (`fio_compare_*.md`).
- Operator manual for:
  - creating/updating fstab entry
  - disabling/removing fstab entry
  - switching between multipath and single-path cleanly

## Testing Strategy

- Test: integration
- Regression: integration

## Test Specification

Sprint Test Configuration:
- Test: integration
- Mode: YOLO

### Integration Tests

#### IT-1: Sprint 21 scripts exist and are executable
- **What it verifies:** new Sprint 21 entry scripts are present
- **Pass criteria:** scripts exist and are executable

#### IT-2: Sprint 21 artifacts exist after a live run
- **What it verifies:** a live run produces diagnostic + result artifacts
- **Pass criteria:** `progress/sprint_21/` contains `diag_*` and `fio_*` artifacts

#### IT-3: fstab entry is created and uses _netdev,nofail
- **What it verifies:** fstab persistence workflow is applied
- **Pass criteria:** guest `/etc/fstab` contains a tagged entry with `_netdev,nofail` for the Sprint 21 mountpoint

### Traceability

| Backlog Item | Integration Tests |
|--------------|-------------------|
| BV4DB-52 | IT-1, IT-2, IT-3 |

