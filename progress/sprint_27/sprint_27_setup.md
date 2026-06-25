# Sprint 27 - Setup

## Contract

Sprint 27 implements BV4DB-61 only. The scenario is a live OCI probe for a block volume attached below UHP level and later updated to `100` VPUs/GB.

## Analysis

The key unknown is lifecycle behavior. Existing Sprint 26 evidence starts with a UHP volume before attachment and produced a negative vanilla result. Sprint 27 must instead preserve the original non-UHP attachment and observe whether changing VPUs changes attachment metadata, instance metadata, Oracle Cloud Agent behavior, iSCSI sessions, or dm-multipath state.

YOLO mode applies, so the sprint records assumptions and proceeds with a focused Terraform plus integration-test probe.
