# Sprint 4 - Setup

## Contract

### Project Overview

OCI Block Volume for Database Architecture project. Sprint 4 implements a minimal Oracle-style block volume layout with five block volumes arranged as three storage classes, validated by concurrent fio workloads.

### Rules Understood

- `GENERAL_RULES.md`: Cooperation rules, phase workflow, document ownership
- `GIT_RULES.md`: Semantic commits with format `type: (sprint-N) description`, push after commit
- `backlog_item_definition.md`: What/why format without implementation details
- `sprint_definition.md`: Test/Regression fields required
- `test_procedures.md`: Phase A (new-code) and Phase B (regression) gates

### Responsibilities

**Allowed:**
- Create/edit sprint design, implementation, and test documents
- Update PROGRESS_BOARD.md status during phases
- Append to proposedchanges.md and openquestions.md
- Update PLAN.md status from Progress to Done/Failed

**Prohibited:**
- Modify Implementation Plan in PLAN.md
- Modify status tokens owned by Product Owner
- Edit documents from other sprints
- Modify RUPStrikesBack submodule (read-only)
- Commit to oci_scaffold main (use oci_bv4db_arch branch only)

### Constraints

- Sprint 4 reuses shared infra from Sprint 1 (compartment, network, vault)
- Compute and block volumes are ephemeral (torn down after benchmark)
- Must use OCI consistent device paths for guest LVM striping

---

## Analysis

### Sprint Overview

Sprint 4 provisions a compute instance with five block volumes arranged as three independent storage classes representing a realistic Oracle Database host layout.

### BV4DB-9. Minimal Oracle-style block volume layout with concurrent workload validation

**Requirement Summary:**

Provision five block volumes as three storage classes:
- Data: Two UHP volumes (120 VPU/GB) striped into LV at `/u02/oradata`
- Redo: Two HP volumes (20 VPU/GB) striped into LV at `/u03/redo`
- FRA: One balanced volume (10 VPU/GB) at `/u04/fra`

Execute concurrent fio workloads targeting all three storage classes and validate I/O isolation via device-level utilization.

**Technical Approach:**

1. Reuse Sprint 2 compute sizing (VM.Standard.E5.Flex, 40 OCPUs)
2. Provision five block volumes with varying VPU configurations via oci_scaffold
3. Attach all volumes using iSCSI multipath with consistent device paths
4. Configure guest LVM on the instance:
   - VG `vg_data` with LV `lv_oradata` striped across two UHP volumes
   - VG `vg_redo` with LV `lv_redo` striped across two HP volumes
   - Direct mount for FRA volume (no striping needed)
5. Create fio profile file with three concurrent job sections (data, redo, fra)
6. Run 60s smoke and 900s integration levels
7. Capture iostat or device metrics to validate I/O distribution

**Dependencies:**

- Sprint 1 shared infra (compartment, network, vault, SSH key)
- oci_scaffold ensure-blockvolume.sh (supports multiple volumes)
- Sprint 2/3 guest setup patterns (iSCSI multipath, mkfs, mount)

**Testing Strategy:**

- **Smoke (60s):** All three fio jobs complete, produce JSON output
- **Integration (900s):** Full-duration run with device utilization validation

**Risks/Concerns:**

- Multiple block volume attachments may require sequential provisioning
- LVM striping configuration adds guest complexity
- Device utilization capture requires iostat or sar on guest

**Compatibility Notes:**

- Extends Sprint 2/3 single-volume pattern to multi-volume layout
- Uses existing oci_scaffold ensure-blockvolume.sh capabilities
- Follows established fio profile file approach from Sprint 3

### Overall Sprint Assessment

**Feasibility:** High
- All OCI APIs and oci_scaffold capabilities are available
- LVM striping is standard Linux configuration

**Complexity:** Moderate
- Five volumes instead of one
- Guest LVM configuration
- Concurrent fio job coordination
- Device utilization validation

**Prerequisites Met:** Yes
- Sprint 1 infra state exists
- oci_scaffold block volume scripts available
- fio profile approach proven in Sprint 3

**Open Questions:** None

### Recommended Design Focus Areas

1. Block volume naming and consistent device path mapping
2. Guest LVM configuration script
3. Concurrent fio profile file structure
4. Device utilization capture method (iostat JSON output)

### Readiness for Design Phase

Confirmed Ready
