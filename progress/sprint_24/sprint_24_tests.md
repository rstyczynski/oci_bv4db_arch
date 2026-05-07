# Sprint 24 - Test Execution Results

## Summary

| Gate | Result | Retries | Pass Rate |
| ---- | ------ | ------- | --------- |
| A3 Integration | PASS | 0 | 100% |
| B3 Integration | PASS | 0 | 100% |

## Artifacts

| Gate | Log File |
| ---- | -------- |
| A3 Integration | `test_run_A3_integration_20260507_112419.log` |
| B3 Integration | `test_run_B3_integration_20260507_112409.log` |

## Functional Test Documentation

### Test 1: Sprint 24 New-Code Integration Gate

**Purpose:** Validate Sprint 24 runner, manifest, and operator documentation.

**Expected Outcome:** `test_sprint24_oci_agent_multipath.sh` reports 5 passed and 0 failed.

**Test Sequence:**

```bash
TS="$(date -u '+%Y%m%d_%H%M%S')"
LOG="progress/sprint_24/test_run_A3_integration_${TS}.log"
tests/run.sh --integration --new-only progress/sprint_24/new_tests.manifest 2>&1 | tee "$LOG"
```

**Status:** PASS

### Test 2: Integration Regression Gate

**Purpose:** Run the repository integration suite after Sprint 24 changes.

**Expected Outcome:** Existing integration tests pass, including Sprint 24.

**Test Sequence:**

```bash
TS="$(date -u '+%Y%m%d_%H%M%S')"
LOG="progress/sprint_24/test_run_B3_integration_${TS}.log"
tests/run.sh --integration 2>&1 | tee "$LOG"
```

**Status:** PASS

## Failures

None.

## Overall Results

| Scope | Scripts Passed | Scripts Failed | Status |
| ----- | -------------- | -------------- | ------ |
| New-code integration | 1 | 0 | PASS |
| Regression integration | 20 | 0 | PASS |

## Live OCI Evidence

| Artifact | Result |
| -------- | ------ |
| `oci_agent_multipath_evidence_20260507_111415.txt` | `RESULT=PASS` |
| `volume_attachment_20260507_111415.json` | sanitized attachment JSON: `is-multipath=true`, `multipath-devices=4` |
| `state-bv4db-s24-agent_20260507_111415.json` | archived live run state |

Observed guest evidence:

```text
sessions=5
maps=1
active_ready_running_paths=5
RESULT=PASS
```
