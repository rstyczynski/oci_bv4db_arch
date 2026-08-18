# Archive Sprint - Move Completed PBIs

## Command Purpose
Archive completed Product Backlog Items (PBIs) from the active BACKLOG.md to COMPLETED_BACKLOG.md after sprint completion.

## Instructions for Agent

### Step 1: Read Current State
1. Read `BACKLOG.md` to identify all completed PBIs (marked as Done/Completed)
2. Read `COMPLETED_BACKLOG.md` (create if doesn't exist)
3. Read the latest sprint documentation in `progress/sprint_XX/sprint_XX_*.md`
4. Determine current sprint number from PLAN.md or latest progress files

### Step 2: Extract Completion Information
For each completed PBI, gather:
- PBI identifier and title
- Original description and acceptance criteria
- Sprint number when completed
- Completion date
- Key outcomes and deliverables
- Links to relevant sprint progress files
- Any technical decisions or lessons learned

### Step 3: Archive to COMPLETED_BACKLOG.md
Move completed PBIs to `COMPLETED_BACKLOG.md` with this format:

```markdown
## [DONE] PBI-XXX: [Title]
**Status:** ✅ Completed  
**Sprint:** Sprint XX  
**Completed:** YYYY-MM-DD  
**Implementation Details:** See [sprint_XX_implementation.md](progress/sprint_XX/sprint_XX_implementation.md)  
**Test Details:** See [sprint_XX_tests.md](progress/sprint_XX/sprint_XX_tests.md)

### Original Requirements
[Copy original PBI description]

### Acceptance Criteria
- [x] Criterion 1
- [x] Criterion 2

### Key Outcomes
- What was delivered
- Important technical decisions
- Lessons learned
- References to artifacts or code

---
```

### Step 4: Update BACKLOG.md
1. Remove archived PBIs from BACKLOG.md
2. Keep the structure clean with only:
   - Active PBIs (In Progress)
   - Ready PBIs (To Do)
   - Blocked PBIs (if any)
3. Optionally add a "Recently Completed (Current Sprint)" section for latest sprint only

### Step 5: Update Organization
1. Organize `COMPLETED_BACKLOG.md` in reverse chronological order (newest first)
2. Add sprint sections if helpful:
   ```markdown
   # Completed Product Backlog Items
   
   ## Sprint 18 (November 2025)
   [Completed PBIs]
   
   ## Sprint 17 (October 2025)
   [Completed PBIs]
   ```

### Phase 6: Summary Report
Provide a summary showing:
- Number of PBIs archived
- Sprint number
- List of archived PBI titles
- Current state of BACKLOG.md (remaining active PBIs)

## Expected Behavior
- **Preserve all information** - Don't lose any details during archival
- **Maintain traceability** - Keep links to sprint progress files
- **Keep BACKLOG.md focused** - Only active/upcoming work
- **Document history** - COMPLETED_BACKLOG.md serves as project memory

## Validation
After execution, verify:
- [ ] All completed PBIs moved to COMPLETED_BACKLOG.md
- [ ] BACKLOG.md contains only active/pending items
- [ ] All links to progress files are valid
- [ ] No information was lost during transfer
- [ ] Markdown formatting is correct

## Usage
Simply say: "Archive the completed PBIs from Sprint XX" or use this command file.
