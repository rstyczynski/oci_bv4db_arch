# Sprint 22 - Tests

Status: Done (Integration tests passed)

## Planned Gates

- Test: integration
- Regression: integration

## Test Coverage

### Integration Tests

Test runner: `tests/integration/test_sprint22_fstab.sh`

| Test ID | Description | Status |
|---------|-------------|--------|
| IT-1 | Sprint 22 scripts exist and are executable | PASS |
| IT-2 | Progress directory structure complete | PASS |
| IT-3 | Guest fstab script syntax validation | PASS |
| IT-4 | Guest fstab script help output | PASS |
| IT-5 | Manual contains all required sections | PASS |
| IT-6 | Manual snippets syntax validation | PASS |
| IT-7 | Sprint 20 dependencies present | PASS |
| IT-8 | Sprint 1 infrastructure state exists | PASS |
| IT-9 | PLAN.md contains Sprint 22 with YOLO mode | PASS |
| IT-10 | PROGRESS_BOARD.md contains Sprint 22 | PASS |
| IT-11 | Sprint 21 marked as failed | PASS |
| IT-12 | oci_scaffold ensure_* scripts unchanged | SKIP |
| IT-13 | Scripts parse without errors | PASS |

### Live Execution Tests (Manual Verification)

These tests require OCI infrastructure and SSH access:

| Test ID | Description | Status |
|---------|-------------|--------|
| LIVE-1 | `run_bv4db_multipath_diag_sprint22.sh` completes successfully | Pending |
| LIVE-2 | `run_bv4db_fio_multipath_ab_sprint22.sh` completes successfully | Pending |
| LIVE-3 | fstab entry created with correct format | Pending |
| LIVE-4 | `mount -a` succeeds with fstab entry | Pending |
| LIVE-5 | Mount survives simulated reboot (`umount && mount -a`) | Pending |
| LIVE-6 | fstab disable workflow works | Pending |
| LIVE-7 | fstab enable workflow works | Pending |
| LIVE-8 | fstab remove workflow works | Pending |
| LIVE-9 | All manual snippets execute successfully | Pending |
| LIVE-10 | Teardown removes fstab entry cleanly | Pending |

## Running Tests

### Integration Tests (Local)

```bash
./tests/integration/test_sprint22_fstab.sh
```

### Live Execution Tests (Requires OCI)

```bash
# Step 1: Run diagnostics
KEEP_INFRA=true NAME_PREFIX=bv4db-s22-mpath ./tools/run_bv4db_multipath_diag_sprint22.sh

# Step 2: Run A/B benchmark
KEEP_INFRA=true NAME_PREFIX=bv4db-s22-mpath ./tools/run_bv4db_fio_multipath_ab_sprint22.sh

# Step 3: SSH to instance and verify fstab
# (see manual for SSH instructions)

# Step 4: Test fstab workflows
sudo /tmp/bv4db_sprint22_fstab.sh show
sudo /tmp/bv4db_sprint22_fstab.sh verify --mount /mnt/sprint22
sudo /tmp/bv4db_sprint22_fstab.sh disable --mount /mnt/sprint22
sudo /tmp/bv4db_sprint22_fstab.sh enable --mount /mnt/sprint22

# Step 5: Teardown
cd progress/sprint_22
export PATH="$PWD/../../oci_scaffold/do:$PWD/../../oci_scaffold/resource:$PATH"
export NAME_PREFIX="bv4db-s22-mpath"
export STATE_FILE="$PWD/state-${NAME_PREFIX}.json"
export FORCE_DELETE=true
teardown-blockvolume.sh || true
teardown-compute.sh || true
```

## Live Execution Evidence

### Integration Test Output

```
========================================
=== BV4DB Integration Tests - Sprint 22 ===
========================================

=== IT-1: Sprint 22 scripts exist and are executable ===
    OK: run_bv4db_multipath_diag_sprint22.sh
    OK: run_bv4db_fio_multipath_ab_sprint22.sh
    OK: bv4db_sprint22_fstab.sh
  [PASS] IT-1: all scripts present and executable
=== IT-2: Sprint 22 progress directory structure ===
    OK: sprint_22_setup.md
    OK: sprint_22_design.md
    OK: sprint_22_implementation.md
    OK: sprint22_manual.md
  [PASS] IT-2: progress directory complete
=== IT-3: Guest fstab script syntax validation ===
  [PASS] IT-3: fstab script syntax OK
=== IT-4: Guest fstab script help output ===
  [PASS] IT-4: fstab script help contains expected commands
=== IT-5: Manual contains all required sections ===
    OK: Step 1 - Run Diagnostics
    OK: Step 2 - Run A/B Performance Test
    OK: Step 3 - SSH Access
    OK: Step 4 - fstab Workflow
    OK: View Current fstab Entry
    OK: Verify Mount Status
    OK: Disable Multipath
    OK: Enable Multipath
    OK: Remove fstab Entry
    OK: Test Reboot Persistence
    OK: Switch Between Multipath and Single-Path
    OK: Collect Diagnostics
    OK: Teardown
    OK: Quick Reference
  [PASS] IT-5: manual contains all required sections
=== IT-6: Manual snippets syntax validation ===
  [PASS] IT-6: manual contains expected bash patterns
=== IT-7: Sprint 20 scripts exist (dependency check) ===
    OK: run_bv4db_multipath_diag_sprint20.sh
    OK: run_bv4db_fio_multipath_ab_sprint20.sh
    OK: bv4db_sprint20_load.sh
  [PASS] IT-7: Sprint 20 dependencies present
=== IT-8: Sprint 1 infrastructure state exists ===
  [PASS] IT-8: Sprint 1 infrastructure state valid
=== IT-9: PLAN.md contains Sprint 22 ===
  [PASS] IT-9: Sprint 22 in PLAN.md with YOLO mode
=== IT-10: PROGRESS_BOARD.md contains Sprint 22 ===
  [PASS] IT-10: Sprint 22 in PROGRESS_BOARD.md
=== IT-11: Sprint 21 marked as failed ===
  [PASS] IT-11: Sprint 21 correctly marked as Failed
=== IT-12: oci_scaffold ensure_* scripts not modified ===
  [SKIP] IT-12: oci_scaffold not a git repo
=== IT-13: Scripts validate without actual execution ===
  [PASS] IT-13: Sprint 22 scripts parse without errors

========================================
Results: 12 passed, 0 failed, 1 skipped
========================================
```

### Live Test Output

Live tests require OCI infrastructure deployment. Execute with:

```bash
KEEP_INFRA=true NAME_PREFIX=bv4db-s22-mpath ./tools/run_bv4db_fio_multipath_ab_sprint22.sh
```

(Live execution evidence to be added after operator runs the scripts)
