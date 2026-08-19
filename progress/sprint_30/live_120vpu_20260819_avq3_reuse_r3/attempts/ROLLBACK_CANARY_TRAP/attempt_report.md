# Sprint 30 rollback-canary report: ROLLBACK_CANARY_TRAP

## Result

- Result: `expected_failure_restored`
- Safe source candidate: `TCP_BUF_2X`
- Baseline restored byte-equal: `yes`
- Sentinels valid: `yes`
- Rollback lease disarmed: `yes`
- Rollback unit state: `not_applicable`

This is a non-performance recovery test. It intentionally injects a failure and makes no throughput or latency claim.

## Evidence files

- [canary.json](canary.json)
- [guest_preflight.json](guest_preflight.json)
