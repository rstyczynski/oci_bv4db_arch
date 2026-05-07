# Sprint 25 - Test Execution Results

## Summary

| Gate | Result | Retries | Pass Rate |
| ---- | ------ | ------- | --------- |
| A3 Integration | PASS | 1 | 100% |
| B3 Integration | PASS | 0 | 100% |

## Artifacts

| Gate | Log File |
| ---- | -------- |
| A3 Integration | `test_run_A3_integration_20260507_114625.log` |
| A3 Integration Retry | `test_run_A3_integration_20260507_114636.log` |
| B3 Integration | `test_run_B3_integration_20260507_114645.log` |

## Failures

### Retry 1 - A3 Integration

- **Test:** `test_sprint25_terraform_agent_multipath.sh`
- **Error:** static regex failed to match `resource "terraform_data" "multipath_attachment"` in `main.tf`.
- **Fix:** corrected the regex to include Terraform's `resource` keyword.
- **Result:** pass on retry 1.

## Overall Results

| Scope | Scripts Passed | Scripts Failed | Status |
| ----- | -------------- | -------------- | ------ |
| New-code integration | 1 | 0 | PASS |
| Regression integration | 21 | 0 | PASS |

## Terraform Validation

The Sprint 25 integration gate ran:

- `terraform fmt -check -recursive`
- `terraform init -backend=false -input=false`
- `terraform validate`
- `terraform plan -refresh=false -input=false` with dummy OCI identifiers and a temporary SSH public key

The structural plan reported `Plan: 3 to add, 0 to change, 0 to destroy`.
