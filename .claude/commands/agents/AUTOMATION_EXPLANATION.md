# Fully Automated RUP Manager - How It Works

## Overview

The **rup-manager.md** is fully automated and orchestrates all 5 RUP phases without requiring user intervention between phases.

## How It Works

### Single Invocation

User invokes once:

```text
@rup-manager.md
```

### Automated Execution Flow

The manager then:

1. **Reads** `.claude/commands/agents/agent-contractor.md`
2. **Executes** all instructions from that file
3. **Commits** changes to git
4. **Proceeds** automatically to next phase

5. **Reads** `.claude/commands/agents/agent-analyst.md`
6. **Executes** all instructions from that file
7. **Commits** changes to git
8. **Proceeds** automatically to next phase

9. **Reads** `.claude/commands/agents/agent-designer.md`
10. **Executes** all instructions from that file
11. **Commits** changes to git
12. **Waits 60 seconds** for design approval (or assumes approval)
13. **Proceeds** automatically to next phase

14. **Reads** `.claude/commands/agents/agent-constructor.md`
15. **Executes** all instructions from that file (implement + test)
16. **Commits** changes to git
17. **Proceeds** automatically to next phase

18. **Reads** `.claude/commands/agents/agent-documentor.md`
19. **Executes** all instructions from that file
20. **Commits** changes to git

21. **Provides** comprehensive final summary

## Key Points

### ✅ Fully Automated

- **No user intervention** needed between phases
- Manager reads each agent file and executes it
- All transitions happen automatically
- Git commits happen automatically after each phase

### ✅ Single Agent Context

- One agent execution from start to finish
- Maintains context and continuity throughout
- All work done in one session
- Complete audit trail in one conversation

### ✅ Modular Definitions

- Each phase defined in its own agent file
- Easy to update individual phase instructions
- Clear separation of concerns
- Maintainable and extensible

### ✅ Flexible Invocation

While the manager runs automatically, you can still:
- Invoke individual agents: `@agent-contractor.md`
- Useful for iteration on specific phases
- Resume work after manual fixes
- Test individual phases independently

## Architecture Diagram

```
User invokes: @rup-manager.md
         ↓
    ┌────────────────────────────────┐
    │   RUP Manager (Single Agent)   │
    │                                │
    │  Phase 1: Read & Execute       │
    │  ├─→ agent-contractor.md       │
    │  └─→ Git commit                │
    │                                │
    │  Phase 2: Read & Execute       │
    │  ├─→ agent-analyst.md          │
    │  └─→ Git commit                │
    │                                │
    │  Phase 3: Read & Execute       │
    │  ├─→ agent-designer.md         │
    │  └─→ Git commit                │
    │                                │
    │  Phase 4: Read & Execute       │
    │  ├─→ agent-constructor.md      │
    │  └─→ Git commit                │
    │                                │
    │  Phase 5: Read & Execute       │
    │  ├─→ agent-documentor.md       │
    │  └─→ Git commit                │
    │                                │
    │  Final: Summary Report         │
    └────────────────────────────────┘
         ↓
    Complete - All phases done
```

## Comparison with Original

### Original rup-cycle.md

```markdown
## Step 1: Execute Contracting Phase
Read `.claude/commands/contract.md` and execute all its instructions.
[Commit after phase]

## Step 2: Execute Inception Phase
Read `.claude/commands/inception.md` and execute all its instructions.
[Commit after phase]
...
```

### New rup-manager.md

```markdown
## Phase 1: Execute Contracting
Read `.claude/commands/agents/agent-contractor.md` and execute all its instructions.
[Commit after phase]

## Phase 2: Execute Inception
Read `.claude/commands/agents/agent-analyst.md` and execute all its instructions.
[Commit after phase]
...
```

**Difference**: 
- Original: Reads phase commands (`contract.md`, `inception.md`, etc.)
- New: Reads specialized agent definitions (`agent-contractor.md`, `agent-analyst.md`, etc.)
- **Automation level is the same**: Both fully automated
- **Benefit**: Agent definitions are more detailed, modular, and can be invoked independently

## Benefits

### 1. Automation

- ✅ **One invocation** runs entire cycle
- ✅ **No manual coordination** needed
- ✅ **Automatic git commits** after each phase
- ✅ **Automatic transitions** between phases

### 2. Modularity

- ✅ **Separate files** for each phase
- ✅ **Clear responsibilities** per agent
- ✅ **Easy to update** one phase without affecting others
- ✅ **Better organization** of instructions

### 3. Flexibility

- ✅ **Independent invocation** of any agent
- ✅ **Iteration** on specific phases
- ✅ **Resume** work at any phase
- ✅ **Test** individual phases independently

### 4. Maintainability

- ✅ **Focused files** - each agent file is self-contained
- ✅ **Clear structure** - responsibilities are explicit
- ✅ **Easy updates** - change one file for one phase
- ✅ **Version control** - track changes per phase

## Error Handling

### If Agent Encounters Issues

The manager will:
1. **Stop** execution at that phase
2. **Report** the issue clearly
3. **Preserve** progress via git commits
4. **Wait** for Product Owner clarification

### Resuming After Issues

To resume:
1. Fix the issue (update design, clarify requirements, etc.)
2. **Option A**: Re-invoke manager `@rup-manager.md` (will continue from checkpoint)
3. **Option B**: Invoke specific agent `@agent-designer.md` (if you know which phase)

### State Preservation

Git commits after each phase ensure:
- No work is lost
- Clear checkpoints exist
- Easy to resume from last successful phase
- Complete audit trail of progress

## Usage Examples

### Example 1: Complete Sprint Execution

```text
User: @rup-manager.md

[Manager executes automatically]

Phase 1: Contracting
✓ Read rules and scope
✓ Created progress/contracting_review_1.md
✓ Committed: docs(contract): add contracting review 1

Phase 2: Inception  
✓ Analyzed Sprint 18
✓ Created progress/sprint_18_analysis.md
✓ Updated PROGRESS_BOARD.md
✓ Committed: docs(inception): add sprint 18 analysis

Phase 3: Elaboration
✓ Created design for GH-25
✓ Created progress/sprint_18_design.md
✓ [Wait 60 seconds for approval]
✓ Assumed approval
✓ Committed: docs(design): add sprint 18 design

Phase 4: Construction
✓ Implemented GH-25
✓ Created and ran tests
✓ All tests passed
✓ Created progress/sprint_18_implementation.md
✓ Created progress/sprint_18_tests.md
✓ Committed: feat(sprint-18): implement artifact deletion

Phase 5: Documentation
✓ Validated all documentation
✓ Updated README.md
✓ Created progress/sprint_18_documentation.md
✓ Committed: docs(sprint-18): update documentation and README

=== RUP Cycle Complete ===

Sprint 18: implemented
- GH-25: tested
All phases complete
5 commits made
```

### Example 2: Design Iteration Needed

```text
User: @rup-manager.md

[Executes Phase 1-2 successfully]

Phase 3: Elaboration
✓ Created design
✗ Design has feasibility issue with API X

[Manager stops and reports]

User: [Updates requirements to use alternative API Y]

User: @agent-designer.md
[Re-runs design phase with updated requirements]
✓ Design complete with API Y

User: @agent-constructor.md
[Continues from construction phase]
...
```

## Summary

The **rup-manager.md** provides:

- ✅ **Full automation** - one invocation, no user intervention
- ✅ **Modular design** - each phase in separate file
- ✅ **Single context** - maintains continuity throughout
- ✅ **Flexible invocation** - can run individual agents too
- ✅ **Better maintainability** - update one agent without affecting others
- ✅ **Same functionality** as original with better organization

**Best of both worlds**: Automation of original rup-cycle.md + Modularity of subagent architecture.

