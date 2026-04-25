# Sprint 22 - Setup

Status: Done

## Sprint Context

Sprint 22 is a redo of Sprint 20 multipath diagnostics and A/B benchmarking, with the addition of fstab-based mount persistence. The sprint learns from Sprint 21 failures (incomplete implementation, thin wrappers) and delivers a complete, operator-usable solution.

## Backlog Item

* BV4DB-52. Persist block-volume mount in /etc/fstab with _netdev,nofail

## Sprint Parameters

- Mode: YOLO
- Test: integration
- Regression: integration

## Key Constraints

1. **DO NOT modify oci_scaffold ensure_* scripts** - Sprint 20 guarantees all works fine
2. Sprint 20 scripts are the stable baseline - reuse them via explicit sourcing/calling
3. Sprint 22 scripts must handle fstab completely (not delegated to Sprint 20)
4. Manual must include ALL executable snippets for operator fstab workflows
5. Integration tests must REALLY run all test scripts and ALL manual snippets

## Scope

- Create Sprint 22 wrapper scripts that call Sprint 20 scripts
- Add complete fstab handling for mount persistence
- Document operator workflows for enabling/disabling multipath via fstab
- Create integration tests that verify all manual snippets work

## Dependencies

- Sprint 1 shared infrastructure (compartment, network, vault)
- Sprint 20 scripts (proven stable baseline)
