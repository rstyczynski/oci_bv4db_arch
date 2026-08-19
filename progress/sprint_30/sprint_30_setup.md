# Sprint 30 - Setup

## Contract

Sprint 30 is managed: design approval is required before construction, any live FIO work, or changes to OCI and guest storage configuration. The scope is limited to BV4DB-72 and must preserve the established Oracle-style block-volume layout for FIO file placement, use a four-OCPU single-path iSCSI server, and produce evidence rather than an unverified tuning recommendation.

The sprint follows the RUP artifact, status, test-gate, bug, and Git rules. It must not modify the read-only `RUPStrikesBack/` submodule, directly edit the Open-iSCSI node database, or perform destructive storage actions without an explicit data-safety design and validation.

## Analysis

BV4DB-72 is feasible with the existing Oracle-style FIO benchmark and `bv4db` integration-test component. This is a FIO-only sprint: the established Oracle-style block-volume layout supplies benchmark filesystems, but Oracle Database must not be installed or tested. The accepted 50-VPU baseline is the archived run `live_50vpu_20260818_224723`; later tuning runs import that evidence and do not spend OCI time measuring another baseline. The test infrastructure is one reusable `oci_scaffold` state: every candidate starts from and returns to the same captured compute, volume, attachment, guest, and filesystem configuration. Resources remain available after normal tests; destruction is reserved for an explicitly authorized hard-recovery case when exact baseline restoration is impossible. Every candidate receives one screening run; only promising candidates receive two validation runs. Every executed candidate or rollback canary creates a human-readable Markdown report in its own evidence directory. The 30- and 120-VPU revalidations remain deferred to BV4DB-74 and BV4DB-75.

Previous UHP multipath sprints are not a configuration baseline because this sprint explicitly evaluates a single-path attachment on a four-OCPU host. The established Oracle-style block-volume layout is the storage-layout baseline; the benchmark creates only FIO test files and must not reformat or recreate the layout.

Live execution uses OCI CLI profile `avq3` and a reusable approved benchmark environment. OCI and GitHub authentication are validated prerequisites, not reasons to provision a new environment per test.

### Readiness

Ready for design. The design must be reviewed and explicitly accepted before construction because this is a managed sprint.

### Final outcome

The accepted design was implemented and the canonical reusable-infrastructure
matrix completed. A3 and scoped B3 passed; final performance and report links
are recorded in `sprint_30_tests.md`.
