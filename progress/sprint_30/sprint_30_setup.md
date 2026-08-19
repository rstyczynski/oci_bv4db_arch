# Sprint 30 - Setup

## Contract

Sprint 30 is managed: design approval is required before construction, any live FIO work, or changes to OCI and guest storage configuration. The original scope was BV4DB-72 and was explicitly extended by the Product Owner with BV4DB-75 on 2026-08-19. Both items preserve the established Oracle-style block-volume layout for FIO file placement, use a four-OCPU single-path iSCSI server, and produce evidence rather than an unverified tuning recommendation.

The sprint follows the RUP artifact, status, test-gate, bug, and Git rules. It must not modify the read-only `RUPStrikesBack/` submodule, directly edit the Open-iSCSI node database, or perform destructive storage actions without an explicit data-safety design and validation.

## Analysis

BV4DB-72 and BV4DB-75 are feasible with the existing Oracle-style FIO benchmark and `bv4db` integration-test component. This is a FIO-only sprint: the established Oracle-style block-volume layout supplies benchmark filesystems, but Oracle Database must not be installed or tested. The accepted 50-VPU baseline is the archived run `live_50vpu_20260818_224723`; 50-VPU tuning runs import that evidence. BV4DB-75 measures one separate 120-VPU baseline because cross-tier baseline comparison is invalid. The test infrastructure is one reusable `oci_scaffold` state: every candidate starts from and returns to the same captured compute, volume, attachment, guest, and filesystem configuration. Resources remain available after normal tests; destruction is reserved for an explicitly authorized hard-recovery case when exact baseline restoration is impossible. Every candidate receives one screening run; only promising candidates receive two validation runs. Every executed candidate or rollback canary creates a human-readable Markdown report in its own evidence directory. The 30-VPU revalidation remains deferred to BV4DB-74.

Previous UHP multipath sprints are not a configuration baseline because this sprint explicitly evaluates a single-path attachment on a four-OCPU host. The established Oracle-style block-volume layout is the storage-layout baseline; the benchmark creates only FIO test files and must not reformat or recreate the layout.

Live execution uses OCI CLI profile `avq3` and a reusable approved benchmark environment. OCI and GitHub authentication are validated prerequisites, not reasons to provision a new environment per test.

### Readiness

Ready for design. The design must be reviewed and explicitly accepted before construction because this is a managed sprint.

### Final outcome

The accepted design was implemented and the canonical reusable-infrastructure
matrix completed. A3 and scoped B3 passed; final performance and report links
are recorded in `sprint_30_tests.md`.

## BV4DB-75 extension - 120 VPUs/GB

On 2026-08-19 the Product Owner explicitly extended Sprint 30 with BV4DB-75
and approved live execution. The accepted BV4DB-72 test definitions and FIO
profile are unchanged. Execution reuses the same `avq3` compute, five volumes,
attachments, filesystems, and guest layout; it changes only all five volume
performance settings from 50 to 120 VPUs/GB. Because a baseline is meaningful
only at the tested tier, one regular 120-VPU baseline is collected once, then
the unchanged candidate matrix compares against it. Candidate teardown restores
guest configuration and retains the reusable OCI resources at the 120-VPU
regular baseline state. Evidence and reports are kept separate from 50 VPU.

BV4DB-75 completed in `live_120vpu_20260819_avq3_reuse_r3`; the final summary
is `sprint_30_120vpu_summary.md` and the setting-specific recommendation is
`RPS_ALL_ONLINE`.
