# Sprint 9 Tests

Status: tested

Test level:

- `integration`

Regression level:

- `integration`

Executed validation:

- confirm the Sprint 9 fio profile uses `4k` redo
- execute the single-UHP run and collect fio plus iostat artifacts
- execute the separated-volume run and collect fio plus iostat artifacts
- confirm both runs preserve per-job fio output
- confirm teardown archives state cleanly
- run [`tests/integration/test_bv4db_oracle_sprint9.sh`](../../tests/integration/test_bv4db_oracle_sprint9.sh)
