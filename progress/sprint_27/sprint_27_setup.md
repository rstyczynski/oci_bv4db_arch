# Sprint 27 - Setup

## Contract

Sprint 27 implements BV4DB-61 and BV4DB-62. The scenario is a live OCI probe for a block volume attached below UHP level and later updated to `100` VPUs/GB, including the Linux-level clean release procedure required to preserve data during detach, VPU update, and UHP multipath reattach.

## Analysis

The key unknown for BV4DB-61 is lifecycle behavior. Existing Sprint 26 evidence starts with a UHP volume before attachment and produced a negative vanilla result. Sprint 27 must instead preserve the original non-UHP attachment and observe whether changing VPUs changes attachment metadata, instance metadata, Oracle Cloud Agent behavior, iSCSI sessions, or dm-multipath state.

BV4DB-62 is covered by the same live test matrix through the Linux unsafe negative case and clean positive case. The sprint validates stop-I/O, flush, unmount, iSCSI logout, detach, update, reattach, multipath discovery, consistent path handling, and checksum verification on disposable data.

YOLO mode applies, so the sprint records assumptions and proceeds with a focused Terraform plus integration-test probe.
