# Sprint 22 - Design

Status: Done

## Overview

Sprint 22 delivers fstab-based mount persistence for the multipath block volume benchmark environment. The design reuses Sprint 20's proven scripts and adds a proper fstab management layer.

## Scope Clarification: HA vs Load Balancing

Sprint 22 validates **HA multipath correctness**:

- multiple iSCSI sessions are present
- the block volume is mapped as `/dev/mapper/mpath*`
- the filesystem is mounted on the mapper device (not on a raw single-path device)

Sprint 22 does **not** attempt to enforce a particular dm-multipath I/O distribution policy. Depending on the active policy (for example `service-time` selector and path-group priorities), I/O can be effectively **single-path** (sticky) while still being HA-correct.

Sprint 23 is intended to extend this baseline with an explicit load-balancing configuration (for example round-robin), plus evidence capture that confirms distribution across paths during the test window.

## Architecture

### Script Structure

```
tools/
  run_bv4db_multipath_diag_sprint22.sh   # Calls Sprint 20 diag script
  run_bv4db_fio_multipath_ab_sprint22.sh # Calls Sprint 20 A/B script + fstab handling
  guest/
    bv4db_sprint22_fstab.sh              # Guest-side fstab management
```

### fstab Entry Format

Per Oracle guidance for consistent device paths:

```
<device_path> <mountpoint> xfs defaults,_netdev,nofail 0 2 # bv4db-sprint22
```

Mount options:
- `defaults` - standard mount options
- `_netdev` - wait for network/iSCSI before mount
- `nofail` - don't block boot if device unavailable

### Device Path Selection

| Mode | Device Path |
|------|-------------|
| multipath | `/dev/oracleoci/oraclevdb` (consistent device path) or `/dev/mapper/mpath*` |
| single-path | `/dev/disk/by-path/ip-<target>:<port>-iscsi-<iqn>-lun-*` |

### fstab Management Operations

1. **Add fstab entry**: Add/update tagged line for sprint mountpoint
2. **Disable fstab entry**: Comment out tagged line (temporary disable)
3. **Enable fstab entry**: Uncomment tagged line
4. **Remove fstab entry**: Delete tagged line entirely

### Tag Format

All fstab entries managed by Sprint 22 use the tag: `# bv4db-sprint22`

This enables:
- Safe identification of sprint-managed entries
- Non-destructive updates
- Clean removal during teardown

## Implementation Notes

### Sprint 20 Reuse

Sprint 22 scripts:
1. Set environment variables for Sprint 22 context
2. Call Sprint 20 scripts (which are proven stable)
3. Add fstab handling after Sprint 20 operations complete

### fstab Safety

- Never blindly overwrite `/etc/fstab`
- Always use atomic update pattern: write temp file, then replace
- Preserve all non-tagged entries
- Use `mount -a` to validate changes

### Integration Test Strategy

Tests must verify:
1. Scripts exist and are executable
2. fstab entry is created with correct format
3. `mount -a` succeeds with the entry
4. Mount survives simulated reboot (`umount && mount -a`)
5. fstab disable/enable workflow works
6. Teardown removes fstab entry cleanly

## Manual Documentation

The manual must include runnable snippets for:
1. Running diagnostics script
2. Running A/B benchmark script
3. SSH access to instance
4. Viewing current fstab entry
5. Manually disabling multipath via fstab
6. Manually enabling multipath via fstab
7. Verifying mount after changes
8. Teardown procedure
