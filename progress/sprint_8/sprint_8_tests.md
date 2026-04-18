# Sprint 8 Tests

Status: tested

Test level:
- `integration`

Regression level:
- `integration`

Executed validation:
- reused the Sprint 5 compute shape, fio job, filesystem layout, and LVM model
- changed only the underlying storage topology to one single UHP block volume
- captured raw fio and iostat integration artifacts
- compared the single-UHP result with the Sprint 5 split-domain baseline

Artifacts:
- `progress/sprint_8/fio-results-oracle-integration.json`
- `progress/sprint_8/iostat-oracle-integration.json`
- `progress/sprint_8/fio-analysis-oracle-integration.md`

Outcome:
- the run completed successfully with valid per-job fio JSON
- the single UHP topology preserved the guest-visible Oracle layout, but not the storage-domain isolation of Sprint 5
- data and redo performance dropped materially versus Sprint 5 because all domains contended on one underlying block volume
