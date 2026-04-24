# Sprint 20 Manual

## Prerequisites

- OCI CLI configured locally.
- SSH access via the shared vault key.

## Operator - SSH access to the instance

- Run the Sprint 20 script with `KEEP_INFRA=true` so the instance is not torn down immediately.
- Extract the public IP from the newest Sprint 20 state file and connect.

```bash
STATE="$(ls -1t progress/sprint_20/state-bv4db-s20-mpath-*.json 2>/dev/null | head -n 1)"
if [ -z "$STATE" ]; then
  echo "No Sprint 20 state file found. Run with KEEP_INFRA=true first, e.g."
  echo "  KEEP_INFRA=true ./tools/run_bv4db_multipath_diag_sprint20.sh"
  echo "  KEEP_INFRA=true ./tools/run_bv4db_fio_multipath_ab_sprint20.sh"
  exit 1
fi
IP="$(jq -r '.compute.public_ip' "$STATE")"

SECRET_OCID="$(jq -r '.secret.ocid' progress/sprint_1/state-bv4db.json)"
TMPKEY="$(mktemp)"
chmod 600 "$TMPKEY"
oci secrets secret-bundle get \
  --secret-id "$SECRET_OCID" \
  --query 'data."secret-bundle-content".content' --raw-output \
  | base64 --decode > "$TMPKEY"

ssh -i "$TMPKEY" -o StrictHostKeyChecking=no opc@"$IP"
```

## Step 1 - Diagnose multipath (sandbox)

```bash
KEEP_INFRA=true ./tools/run_bv4db_multipath_diag_sprint20.sh
```

## Step 2 - Run A/B performance test (fio)

```bash
KEEP_INFRA=true ./tools/run_bv4db_fio_multipath_ab_sprint20.sh
```

## Step 3 - Teardown

- Teardown is executed automatically at the end of both Sprint 20 scripts.
- If a run fails mid-way, re-run the same script to complete teardown, or use the scaffold teardown helpers from `progress/sprint_20/` working directory (they are called by the scripts):

```bash
cd progress/sprint_20
teardown_compute.sh || true
teardown_blockvolume_attachment.sh || true
teardown_blockvolume.sh || true
```

## Outputs

Artifacts are written under `progress/sprint_20/`.
