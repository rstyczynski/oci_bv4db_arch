# Sprint 10 Tests

Status: tested

Test level:

- `integration`

Regression level:

- `integration`

Planned validation:

- execute Lower Cost single-volume Oracle-style run
- execute Balanced single-volume Oracle-style run
- execute Balanced separated-volume Oracle-style run
- execute Higher Performance single-volume Oracle-style run
- execute Higher Performance separated-volume Oracle-style run
- preserve fio per-job JSON and produce analysis artifacts for each run
- archive teardown state for each run
- produce OCI performance-tier comparison analysis

Executed validation:

- Lower Cost single-volume Oracle-style integration run completed and archived
- Balanced single-volume Oracle-style integration run completed and archived
- Balanced multi-volume Oracle-style integration run completed and archived
- Higher Performance single-volume Oracle-style integration run completed and archived
- Higher Performance multi-volume Oracle-style integration run completed and archived
- all five fio JSON result files parse successfully
- all five analysis files exist
- OCI performance-tier comparison document exists
- teardown state archives exist for every executed run
