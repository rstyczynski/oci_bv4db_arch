# Sprint 2 - Design

## BV4DB-7. Maximum-performance block volume configuration benchmark

Status: Accepted

### Requirement Summary

Run a higher-performance block volume benchmark than Sprint 1 using the shared Sprint 1 infrastructure. The run must use maximum supported block volume VPU, the required network paths for best performance, a 60-second fio measurement window for this sprint, produce an analyzed report, and tear down compute and block volume automatically after benchmark completion.

### Feasibility Analysis

**API and Platform Availability**

- OCI Block Volume UHP supports up to `120 VPU/GB`, `300,000` IOPS, and `2,680 MB/s` per volume.
- UHP requires multipath-enabled attachments for best performance.
- Current VM shapes with `16+` OCPUs support UHP, and `VM.Standard.E5.Flex` supports up to `40 Gbps` network bandwidth and up to `4,800 MB/s` block-volume throughput per instance.

**Primary references**

- Oracle Block Volume Performance: `https://docs.oracle.com/en-us/iaas/Content/Block/Concepts/blockvolumeperformance.htm`
- Oracle Ultra High Performance: `https://docs.oracle.com/en-us/iaas/Content/Block/Concepts/blockvolumeultrahighperformance.htm`
- Oracle Multipath Attachments: `https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/configuringmultipathattachments.htm`

### Proposed Design

1. Reuse `progress/sprint_1/state-bv4db.json` for the shared compartment, subnet, and SSH secret.
2. Add a dedicated Sprint 2 benchmark flow with its own ephemeral state and result artifacts under `progress/sprint_2/`.
3. Provision a `VM.Standard.E5.Flex` instance sized to the shape's maximum VM network bandwidth (`40` OCPUs) so the instance does not cap the block volume below the intended target.
4. Provision one block volume at the UHP maximum of `120 VPU/GB` and size it large enough to reach the service maximum for a single volume (`1,500 GB` minimum to reach `300,000` IOPS and `2,680 MB/s`).
5. Configure the attachment for the required multipath-capable UHP path, with a consistent device path and Oracle-supported guest prerequisites.
6. Run fio long enough to provide the required 60-second measurement window for this sprint.
7. Save raw fio JSON plus a derived analysis file under `progress/sprint_2/`.
8. Tear down compute and block volume automatically after the benchmark run, relying on OCI metrics retention for terminated resources.

### Technical Specification

**Shared inputs reused from Sprint 1**

| Key | Source |
| --- | --- |
| compartment OCID | `progress/sprint_1/state-bv4db.json` |
| subnet OCID | `progress/sprint_1/state-bv4db.json` |
| SSH secret OCID | `progress/sprint_1/state-bv4db.json` |

**Planned Sprint 2 compute inputs**

| Key | Value |
| --- | --- |
| shape | `VM.Standard.E5.Flex` |
| OCPUs | `40` |
| memory | `64 GB` |
| public IP | enabled |

**Planned Sprint 2 block volume inputs**

| Key | Value |
| --- | --- |
| attach type | `iscsi` |
| performance level | Ultra High Performance |
| VPU | `120` |
| size | `1500 GB` |

**Planned Sprint 2 artifacts**

| Artifact | Purpose |
| --- | --- |
| `progress/sprint_2/state-bv4db-perf-run.json` | ephemeral compute and volume state |
| `progress/sprint_2/fio-results-perf.json` | raw fio result |
| `progress/sprint_2/fio_analysis.md` | analyzed report |
| `progress/sprint_2/sprint_2_tests.md` | execution and verification procedure |

### Testing Strategy

#### Recommended Sprint Parameters

- **Test:** integration — this sprint is entirely end-to-end infrastructure and benchmark execution
- **Regression:** integration — re-run the integration path after implementing the higher-performance variant

#### Integration Test Targets

| Scenario | What it verifies | Expected outcome |
| --- | --- | --- |
| Max-performance compute launch | Sprint 2 compute launches in reused Sprint 1 subnet | compute state contains VM.Standard.E5.Flex instance |
| UHP block volume attach | UHP volume attaches with the required high-performance path | attachment state and device are present |
| 60-second benchmark execution | fio completes with the defined Sprint 2 window | raw fio JSON exists and is valid |
| Automatic teardown | compute and volume are deleted after the run | benchmark resources do not remain allocated |
| Analysis artifact | analyzed report is written | Sprint 2 analysis file exists and summarizes results |

### Managed-Mode Approval Gate

Implementation should begin after the Product Owner confirms the 60-second benchmark interpretation for Sprint 2 and accepts this proposed configuration.
