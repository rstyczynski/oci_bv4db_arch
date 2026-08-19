# Sprint 30 - Setup

## Contract

Sprint 30 is managed: design approval is required before construction, any live FIO work, or changes to OCI and guest storage configuration. The scope is limited to BV4DB-72 and must preserve the established Oracle-style block-volume layout for FIO file placement, use a four-OCPU single-path iSCSI server, and produce evidence rather than an unverified tuning recommendation.

The sprint follows the RUP artifact, status, test-gate, bug, and Git rules. It must not modify the read-only `RUPStrikesBack/` submodule, directly edit the Open-iSCSI node database, or perform destructive storage actions without an explicit data-safety design and validation.

## Analysis

BV4DB-72 is feasible with the existing Oracle-style FIO benchmark and `bv4db` integration-test component. This is a FIO-only sprint: the established Oracle-style block-volume layout supplies benchmark filesystems, but Oracle Database must not be installed or tested. The design must inventory the tuning controls actually available on the selected Oracle Linux image, establish one 50 VPU/GB smoke baseline, change one supported control or coupled setting group at a time, and retain FIO, CPU, and iSCSI network-path evidence for each comparable run. Every candidate receives one screening run; only candidates that improve a primary metric by more than 5% without a primary regression, CPU guard failure, integrity failure, or monitored error increase receive two additional validation runs. Every executed performance test, including a baseline, checkpoint, candidate screening or validation run, and rollback canary, must also create a human-readable Markdown report in its own evidence directory; raw JSON or HTML alone is insufficient. The 30- and 120-VPU revalidations are explicitly deferred to BV4DB-74 and BV4DB-75 and are not Sprint 30 execution scope.

Previous UHP multipath sprints are not a configuration baseline because this sprint explicitly evaluates a single-path attachment on a four-OCPU host. The established Oracle-style block-volume layout is the storage-layout baseline; the benchmark creates only FIO test files and must not reformat or recreate the layout.

Live execution requires working OCI credentials and a disposable or otherwise approved benchmark environment. The current repository records invalid OCI authentication as blocking pre-existing live integration tests, so credential validation is a precondition for the later live gate rather than an assumption of this setup phase.

### Readiness

Ready for design. The design must be reviewed and explicitly accepted before construction because this is a managed sprint.
