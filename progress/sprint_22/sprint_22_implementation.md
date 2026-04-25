# Sprint 22 - Implementation

Status: Done

## Summary

Sprint 22 implements fstab-based mount persistence for multipath block volumes. The implementation reuses Sprint 20's proven scripts as a stable baseline and adds complete fstab management.

## Scope Clarification: HA Multipath Baseline

Sprint 22 focuses on **HA multipath** (correct aggregation + correct mount source) and on **operator-safe persistence** via `/etc/fstab`.

It does **not** attempt to force dm-multipath to distribute I/O across all paths. Default policies can produce path stickiness (one hot path) even when multipath is correctly configured.

Sprint 23 is intended to reuse Sprint 22’s stable baseline but add an explicit load-balancing policy configuration (for example round-robin) and the operator-facing documentation/evidence needed to make that behavior clear.

## Entry Scripts

- `tools/run_bv4db_multipath_diag_sprint22.sh` - Diagnostics wrapper
- `tools/run_bv4db_fio_multipath_ab_sprint22.sh` - A/B benchmark with fstab handling

## Guest Scripts

- `tools/guest/bv4db_sprint22_fstab.sh` - fstab management (add/disable/enable/remove/show/verify)

## Implementation Details

### Script Architecture

Sprint 22 scripts:
1. Set Sprint 22-specific environment (`NAME_PREFIX=bv4db-s22-mpath`, `PROGRESS_DIR`, `SPRINT_MNT=/mnt/sprint22`)
2. Call Sprint 20 scripts (proven stable, DO NOT modify oci_scaffold ensure_* scripts)
3. Add fstab handling after Sprint 20 operations complete

### fstab Management

The guest script `bv4db_sprint22_fstab.sh` provides complete fstab management:

```bash
# Add/update fstab entry
bv4db_sprint22_fstab.sh add --device /dev/oracleoci/oraclevdb --mount /mnt/sprint22

# Disable entry (comment out)
bv4db_sprint22_fstab.sh disable --mount /mnt/sprint22

# Enable entry (uncomment)
bv4db_sprint22_fstab.sh enable --mount /mnt/sprint22

# Remove entry entirely
bv4db_sprint22_fstab.sh remove --mount /mnt/sprint22

# Show sprint-managed entries
bv4db_sprint22_fstab.sh show

# Verify mount status
bv4db_sprint22_fstab.sh verify --mount /mnt/sprint22
```

### fstab Entry Format

```
/dev/oracleoci/oraclevdb /mnt/sprint22 xfs defaults,_netdev,nofail 0 2 # bv4db-sprint22
```

Options per Oracle guidance:
- `defaults` - standard mount options
- `_netdev` - wait for network/iSCSI initiator before mount
- `nofail` - don't block boot if device unavailable

### Tag for Management

All Sprint 22 fstab entries use tag: `# bv4db-sprint22`

This enables safe identification, updates, and removal.

## Key Differences from Sprint 21

| Aspect | Sprint 21 | Sprint 22 |
|--------|-----------|-----------|
| fstab handling | Delegated to Sprint 20 | Complete guest script |
| Implementation | Thin wrapper only | Full implementation |
| Manual snippets | Incomplete | ALL executable |
| Integration tests | Not fully run | REALLY run all |

## Artifacts

- `progress/sprint_22/fstab_state_*.txt` - fstab state after each run
- `progress/sprint_22/state-bv4db-s22-mpath.json` - Instance state
- Standard Sprint 20 artifacts (diagnostics, fio results, comparison)

## Notes

- Sprint 20 scripts are unchanged (stable baseline)
- oci_scaffold ensure_* scripts are NOT modified
- fstab management is fully contained in Sprint 22 scripts
