# Sprint 23 - Design

Status: Accepted

## Overview

Sprint 23 extends the Sprint 22 baseline (HA multipath + fstab persistence + A/B benchmark + metrics/timestamps) by explicitly configuring dm-multipath for **load balancing** (round-robin) and collecting evidence that I/O is distributed across paths during the benchmark window.

## Goals

- Keep Sprint 22’s correctness guarantees (mountpoint assertions, fstab safety, metrics window correlation).
- Add a deterministic and documented multipath policy configuration for the multipath phase.
- Archive “before/after” configuration and path distribution evidence around the benchmark.

## Proposed dm-multipath Policy

The target configuration is round-robin over active paths:

- `path_grouping_policy multibus`
- `path_selector "round-robin 0"`
- `rr_weight uniform`
- `rr_min_io_rq` tuned low (start with `1`) so distribution is observable even on shorter runs

Implementation is applied on the guest just before the multipath-phase filesystem preparation and benchmark run, and it is observable via:

- `multipath -ll`
- `multipathd show config`
- `multipathd show paths`

## Artifact Contract

In addition to Sprint 22 artifacts, Sprint 23 must archive:

- multipath policy evidence (config snapshot)
- explicit “pre/post” snapshots around the multipath-phase test window

## Testing Strategy (Integration)

- Run Sprint 23 diagnostics wrapper and confirm multipath mapper device exists.
- Run Sprint 23 A/B benchmark with `MULTIPATH_LB_ENABLE=true` and confirm:
  - mount source is `/dev/mapper/mpath*` for multipath phase
  - applied multipath policy is visible in diagnostics
  - evidence shows multiple paths carrying I/O during the test window (not only a single hot path)

Note: throughput may still be limited by upstream bottlenecks; acceptance is based on **distribution evidence**, not necessarily throughput scaling.
