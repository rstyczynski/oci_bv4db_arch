# Sprint 3 - Design

## BV4DB-8. Mixed 8k database-oriented benchmark profile on Sprint 2 topology

Status: Accepted

### Requirement Summary

Run fio from a profile file on the Sprint 2 UHP topology using the mixed `8k` workload. The sprint must support both `60`-second smoke and `15`-minute integration execution levels while preserving raw JSON artifacts and analysis.

### Proposed Design

1. Reuse the Sprint 2 compute and block volume sizing: `VM.Standard.E5.Flex`, `40` OCPUs, `1500 GB`, `120 VPU/GB`, iSCSI multipath.
2. Store the fio workload as a profile file in `progress/sprint_3/` using the exact requested content.
3. Add a dedicated Sprint 3 runner that reuses the proven Sprint 2 guest-setup path and executes fio from the profile file on the guest.
4. Start with the `60`-second smoke run by overriding runtime at execution time while preserving the profile file content.
5. Save smoke artifacts under `progress/sprint_3/` and leave the `15`-minute integration run for the second execution level.

### Testing Strategy

- Smoke execution level: `60` seconds total runtime on the mixed `8k` profile
- Integration execution level: `900` seconds total runtime on the same profile
- Initial execution target for this sprint start: smoke run only
