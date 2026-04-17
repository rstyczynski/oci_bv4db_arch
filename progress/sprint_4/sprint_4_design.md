# Sprint 4 - Design

## BV4DB-9. Minimal Oracle-style block volume layout with concurrent workload validation

Status: Accepted

### Requirement Summary

Provision a compute instance with five block volumes arranged as three storage classes representing a minimal Oracle Database host layout. Execute concurrent fio workloads targeting all three storage classes and validate I/O isolation via device-level utilization metrics.

### Feasibility Analysis

**API Availability:**

- OCI Compute API: Instance provisioning with flexible shapes (documented in previous sprints)
- OCI Block Volume API: Volume provisioning with VPU configuration (documented in Sprint 1-3)
- OCI Volume Attachment API: iSCSI multipath attachment with consistent device paths (documented in Sprint 2)
- oci_scaffold: ensure-blockvolume.sh supports multiple volume provisioning

**Technical Constraints:**

- Maximum 32 block volumes per compute instance (Sprint 4 uses 5 — well within limit)
- Consistent device paths require OCI Block Volume Management plugin enabled
- Guest LVM striping requires Linux kernel device-mapper support (standard in Oracle Linux 8)

**Risk Assessment:**

- Risk 1: Multiple volume attachments may take longer to complete — Mitigation: Sequential provisioning with wait loops
- Risk 2: Device utilization capture adds complexity — Mitigation: Use iostat with JSON output for structured parsing

### Design Overview

**Architecture:**

```
┌──────────────────────────────────────────────────────────────────────┐
│  OCI Compute Instance (VM.Standard.E5.Flex, 40 OCPUs)                │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐      │
│  │  /u02/oradata   │  │   /u03/redo     │  │   /u04/fra      │      │
│  │  (LV striped)   │  │  (LV striped)   │  │  (direct mount) │      │
│  └────────┬────────┘  └────────┬────────┘  └────────┬────────┘      │
│           │                    │                    │                │
│  ┌────────┴────────┐  ┌────────┴────────┐  ┌───────┴────────┐       │
│  │    vg_data      │  │    vg_redo      │  │    ext4        │       │
│  │  lv_oradata     │  │    lv_redo      │  │                │       │
│  └──┬──────────┬───┘  └──┬──────────┬───┘  └───────┬────────┘       │
│     │          │         │          │              │                 │
│  ┌──┴──┐    ┌──┴──┐   ┌──┴──┐    ┌──┴──┐       ┌───┴───┐            │
│  │ vdb │    │ vdc │   │ vdd │    │ vde │       │  vdf  │            │
│  │ UHP │    │ UHP │   │ HP  │    │ HP  │       │ BAL   │            │
│  │120VP│    │120VP│   │20VP │    │20VP │       │10VP   │            │
│  └─────┘    └─────┘   └─────┘    └─────┘       └───────┘            │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

**Key Components:**

1. **Volume Configuration Script** (`tools/run_bv_fio_oracle.sh`)
   - Provisions compute and five block volumes with different VPU settings
   - Attaches all volumes using iSCSI multipath
   - Configures guest LVM for data and redo storage classes
   - Runs concurrent fio workload and captures device utilization

2. **fio Profile File** (`progress/sprint_4/oracle-layout.fio`)
   - Three concurrent job sections targeting data, redo, and fra
   - Database-representative I/O patterns for each storage class

3. **Integration Test** (`tests/integration/test_bv4db_oracle.sh`)
   - Validates artifacts and I/O distribution

### Technical Specification

**Block Volume Configuration:**

| Volume | Device Path | VPU/GB | Size GB | Purpose | Volume Group |
|--------|-------------|--------|---------|---------|--------------|
| bv-data-1 | /dev/oracleoci/oraclevdb | 120 | 200 | Data file stripe 1 | vg_data |
| bv-data-2 | /dev/oracleoci/oraclevdc | 120 | 200 | Data file stripe 2 | vg_data |
| bv-redo-1 | /dev/oracleoci/oraclevdd | 20 | 50 | Redo log stripe 1 | vg_redo |
| bv-redo-2 | /dev/oracleoci/oraclevde | 20 | 50 | Redo log stripe 2 | vg_redo |
| bv-fra | /dev/oracleoci/oraclevdf | 10 | 100 | Fast Recovery Area | (none) |

**LVM Configuration:**

```bash
# Data volume group — stripe across two UHP volumes
pvcreate /dev/mapper/mpath-vdb /dev/mapper/mpath-vdc
vgcreate vg_data /dev/mapper/mpath-vdb /dev/mapper/mpath-vdc
lvcreate -l 100%FREE -n lv_oradata -i 2 -I 256K vg_data
mkfs.ext4 /dev/vg_data/lv_oradata
mkdir -p /u02/oradata
mount /dev/vg_data/lv_oradata /u02/oradata

# Redo volume group — stripe across two HP volumes
pvcreate /dev/mapper/mpath-vdd /dev/mapper/mpath-vde
vgcreate vg_redo /dev/mapper/mpath-vdd /dev/mapper/mpath-vde
lvcreate -l 100%FREE -n lv_redo -i 2 -I 256K vg_redo
mkfs.ext4 /dev/vg_redo/lv_redo
mkdir -p /u03/redo
mount /dev/vg_redo/lv_redo /u03/redo

# FRA — direct mount (no striping)
mkfs.ext4 /dev/mapper/mpath-vdf
mkdir -p /u04/fra
mount /dev/mapper/mpath-vdf /u04/fra
```

**fio Profile File (`oracle-layout.fio`):**

```ini
[global]
ioengine=libaio
direct=1
time_based=1
runtime=450
ramp_time=30
group_reporting=1
invalidate=1

# Data workload — 70/30 read/write, 8k random (OLTP-like)
[data-8k]
filename=/u02/oradata/testfile
size=32G
rw=randrw
rwmixread=70
bs=8k
numjobs=4
iodepth=32
fsync_on_close=1

# Redo workload — sequential sync write, low queue depth
[redo]
filename=/u03/redo/testfile
size=4G
rw=write
bs=256k
numjobs=1
iodepth=1
fsync=1

# FRA workload — large-block sequential traffic
[fra-1m]
filename=/u04/fra/testfile
size=16G
rw=rw
bs=1M
numjobs=2
iodepth=16
```

**Device Utilization Capture:**

```bash
# Capture iostat during fio run (10s intervals)
iostat -xdmz 10 -o JSON > iostat-oracle-${RUN_LEVEL}.json &
IOSTAT_PID=$!

# Run fio
fio --output=fio-oracle-${RUN_LEVEL}.json --output-format=json oracle-layout.fio

# Stop iostat
kill $IOSTAT_PID
```

**Artifacts:**

| Artifact | Path | Purpose |
|----------|------|---------|
| fio profile | `progress/sprint_4/oracle-layout.fio` | Workload definition |
| fio results (smoke) | `progress/sprint_4/fio-results-oracle-smoke.json` | Raw fio output (60s) |
| fio results (integration) | `progress/sprint_4/fio-results-oracle-integration.json` | Raw fio output (900s) |
| iostat (smoke) | `progress/sprint_4/iostat-oracle-smoke.json` | Device utilization (60s) |
| iostat (integration) | `progress/sprint_4/iostat-oracle-integration.json` | Device utilization (900s) |
| Analysis | `progress/sprint_4/fio-analysis-oracle-${level}.md` | Summary report |

### Implementation Approach

**Step 1:** Create fio profile file `progress/sprint_4/oracle-layout.fio`

**Step 2:** Create runner script `tools/run_bv_fio_oracle.sh`:
- Reuse Sprint 1 infra state
- Provision compute (reuse Sprint 2 sizing)
- Provision five block volumes with varying VPU settings
- Configure guest iSCSI multipath for all volumes
- Configure guest LVM (vg_data, vg_redo, direct mount for FRA)
- Upload fio profile and run with iostat capture
- Collect results and tear down

**Step 3:** Create integration test `tests/integration/test_bv4db_oracle.sh`:
- Verify fio profile exists with correct job sections
- Verify fio results JSON is valid
- Verify iostat JSON shows I/O on expected devices
- Verify archived state shows teardown complete

### Testing Strategy

#### Recommended Sprint Parameters

- **Test:** integration — No unit tests (infrastructure-only sprint); integration validates artifacts
- **Regression:** integration — Run Sprint 1-3 integration tests to ensure no breakage

#### Unit Test Targets

None — Sprint 4 is infrastructure provisioning and benchmarking only.

#### Integration Test Scenarios

| Scenario | Infrastructure Dependencies | Expected Outcome | Est. Runtime |
|----------|----------------------------|------------------|--------------|
| IT-14: Oracle fio profile exists | Local filesystem | Profile file with 3 job sections | < 1 sec |
| IT-15: Smoke run completed | OCI tenancy, Sprint 1 infra | Valid fio JSON with runtime=60 | < 1 sec (artifact check) |
| IT-16: Device utilization captured | OCI tenancy, Sprint 1 infra | iostat JSON with device I/O | < 1 sec (artifact check) |
| IT-17: I/O isolation validated | Artifact analysis | Each storage class shows I/O on correct devices | < 2 sec |
| IT-18: Resources torn down | Archived state file | State file indicates deletion | < 1 sec |

#### Smoke Test Candidates

None — smoke tests are execution-time tests; this sprint's "smoke" is the 60s fio run which produces integration artifacts.

#### Success Criteria

1. All three fio jobs complete concurrently
2. fio JSON output is valid and shows metrics for all three jobs
3. iostat JSON shows I/O activity on all five block volume devices
4. Device utilization confirms I/O isolation (data volumes handle data I/O, etc.)
5. Compute and block volumes are torn down after benchmark

### Integration Notes

**Dependencies:**

- Sprint 1 shared infra (compartment, network, vault, SSH key)
- oci_scaffold ensure-compute.sh and ensure-blockvolume.sh

**Compatibility:**

- Extends Sprint 2/3 single-volume approach to multi-volume layout
- Reuses established guest setup patterns (iSCSI, multipath, fio execution)
- Follows Sprint 3 profile file approach

**Reusability:**

- LVM configuration script can be reused for future multi-volume sprints
- iostat capture approach can be reused for device-level analysis

### Documentation Requirements

**User Documentation:**

- How to run the Oracle-layout benchmark
- How to interpret iostat device utilization
- How to compare results across storage classes

**Technical Documentation:**

- Block volume VPU configuration rationale
- LVM striping parameters

### Design Decisions

**Decision 1:** Use LVM striping for data and redo, direct mount for FRA
**Rationale:** Data and redo benefit from striping across two volumes for throughput; FRA is single-volume workload
**Alternatives Considered:** Software RAID (mdadm) — LVM is simpler and integrates with OCI documentation

**Decision 2:** Use iostat JSON output for device utilization
**Rationale:** Structured output allows programmatic validation of I/O distribution
**Alternatives Considered:** sar, blktrace — iostat is simpler and sufficient for this use case

**Decision 3:** Volume sizes scaled down from production (200GB data, 50GB redo, 100GB FRA)
**Rationale:** Sufficient for benchmark while minimizing cost; VPU setting determines performance tier
**Alternatives Considered:** Larger volumes — not needed for benchmark validation

### Open Design Questions

None

---

## Test Specification

Sprint Test Configuration:
- Test: integration
- Mode: managed

### Integration Tests

#### IT-14: Oracle fio profile file present

- **What it verifies:** fio profile file exists with three job sections (data-8k, redo, fra-1m)
- **Pass criteria:** File exists and contains all three job section headers
- **Target file:** tests/integration/test_bv4db_oracle.sh

#### IT-15: Smoke run completed on Oracle layout

- **What it verifies:** fio completed 60s smoke run and produced valid JSON
- **Pass criteria:** fio-results-oracle-smoke.json exists and is valid JSON with runtime=60
- **Target file:** tests/integration/test_bv4db_oracle.sh

#### IT-16: Device utilization captured

- **What it verifies:** iostat JSON captured during fio run
- **Pass criteria:** iostat-oracle-smoke.json exists and is valid JSON
- **Target file:** tests/integration/test_bv4db_oracle.sh

#### IT-17: I/O isolation validated

- **What it verifies:** Each storage class shows I/O on correct underlying devices
- **Pass criteria:** iostat JSON shows non-zero I/O on dm-* or mpath devices corresponding to each volume
- **Target file:** tests/integration/test_bv4db_oracle.sh

#### IT-18: Resources torn down automatically

- **What it verifies:** Compute and block volumes deleted after benchmark
- **Pass criteria:** Archived state file with blockvolume.deleted=true
- **Target file:** tests/integration/test_bv4db_oracle.sh

### Traceability

| Backlog Item | Smoke | Unit Tests | Integration Tests |
|--------------|-------|------------|-------------------|
| BV4DB-9 | N/A | N/A | IT-14, IT-15, IT-16, IT-17, IT-18 |

---

## Design Summary

### Overall Architecture

Sprint 4 provisions a multi-volume Oracle-style layout with LVM striping and concurrent fio workloads to validate I/O isolation across storage classes.

### Shared Components

- Sprint 1 infra state (compartment, network, vault)
- oci_scaffold ensure-compute.sh, ensure-blockvolume.sh
- Sprint 2/3 guest setup patterns (iSCSI, multipath)

### Design Risks

- Multiple volume provisioning may increase setup time — mitigated by sequential provisioning with waits
- iostat capture adds complexity — mitigated by using JSON output for structured parsing

### Resource Requirements

- OCI tenancy with block volume quota for 5 volumes
- Sprint 1 shared infra state
- fio, iostat, lvm2 on guest instance

### Design Approval Status

Accepted
