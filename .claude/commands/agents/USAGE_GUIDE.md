# RUP Subagent Architecture - Usage Guide

## Quick Start

### Running the Complete RUP Cycle (Fully Automated)

To execute a full RUP cycle with all phases automatically:

```text
@rup-manager.md
```

**This is fully automated.** The manager will:
- Read each agent's instruction file
- Execute all instructions from that agent
- Commit changes after each phase
- Automatically transition to the next phase
- Provide final summary when complete

All 5 phases run in sequence:
1. Contracting (reads and executes agent-contractor.md)
2. Inception (reads and executes agent-analyst.md)
3. Elaboration (reads and executes agent-designer.md)
4. Construction (reads and executes agent-constructor.md)
5. Documentation (reads and executes agent-documentor.md)

**No user intervention needed between phases.**

### Running Individual Phases

If you need to run or re-run a specific phase:

```text
@agent-contractor.md   # Phase 1: Contracting
@agent-analyst.md      # Phase 2: Inception
@agent-designer.md     # Phase 3: Elaboration
@agent-constructor.md  # Phase 4: Construction
@agent-documentor.md   # Phase 5: Documentation
```

## When to Use Each Approach

### Use Full Cycle (rup-manager.md) When:

- Starting a new Sprint from scratch
- All phases need to be executed
- You want fully automated execution (no manual intervention)
- You want automatic phase transitions with git commits
- You need a comprehensive final report

### Use Individual Agents When:

- Resuming after an interruption
- Iterating on a specific phase
- Design needs revision after feedback
- Tests failed and need re-implementation
- Documentation needs validation update

## Common Scenarios

### Scenario 1: Starting a New Sprint

```text
1. Ensure Sprint is marked as "Progress" in PLAN.md
2. @rup-manager.md
3. Manager automatically executes all 5 phases
4. Review comprehensive final summary
5. All phases committed automatically
```

**Note**: The manager runs fully automatically. If it needs clarification at any phase, it will stop and request it.

### Scenario 2: Design Revision Needed

```text
1. Product Owner updates design document with feedback
2. @agent-designer.md
3. Designer revises based on feedback
4. Once approved, continue with:
   @agent-constructor.md
```

### Scenario 3: Construction Failed, Retry Needed

```text
1. Review failed tests in progress/sprint_${no}/sprint_${no}_tests.md
2. Identify and fix the issue
3. @agent-constructor.md
4. Constructor re-runs tests
5. Continue to documentation if successful
```

### Scenario 4: Session Interrupted

```text
1. Check PROGRESS_BOARD.md to see last completed phase
2. Invoke the next phase agent:
   - If contracting done: @agent-analyst.md
   - If inception done: @agent-designer.md
   - If elaboration done: @agent-constructor.md
   - If construction done: @agent-documentor.md
```

### Scenario 5: Documentation Compliance Check

```text
1. After construction completes
2. @agent-documentor.md
3. Reviews all documentation
4. Reports compliance issues
5. If issues found, fix and re-run
```

## Agent Inputs and Outputs

### Agent: Contractor

**Input:**
- BACKLOG.md
- PLAN.md
- rules/*.md files

**Output:**
- progress/contracting_review_${cnt}.md

**Next Step:** Analyst Agent

---

### Agent: Analyst

**Input:**
- BACKLOG.md (Sprint in Progress)
- PLAN.md
- Previous Sprint artifacts in progress/

**Output:**
- progress/sprint_${no}/sprint_${no}_analysis.md
- progress/inception/inception_sprint_${no}_chat_${cnt}.md
- Updated PROGRESS_BOARD.md

**Next Step:** Designer Agent

---

### Agent: Designer

**Input:**
- progress/sprint_${no}/sprint_${no}_analysis.md
- BACKLOG.md requirements

**Output:**
- progress/sprint_${no}/sprint_${no}_design.md
- progress/elaboration/elaboration_sprint_${no}_chat_${cnt}.md
- Updated PROGRESS_BOARD.md

**Next Step:** Wait for approval, then Constructor Agent

---

### Agent: Constructor

**Input:**
- progress/sprint_${no}/sprint_${no}_design.md (approved)
- progress/sprint_${no}/sprint_${no}_analysis.md

**Output:**
- Code artifacts (scripts, tools)
- progress/sprint_${no}/sprint_${no}_implementation.md
- progress/sprint_${no}/sprint_${no}_tests.md
- Updated PROGRESS_BOARD.md

**Next Step:** Documentor Agent

---

### Agent: Documentor

**Input:**
- progress/sprint_${no}/sprint_${no}_analysis.md
- progress/sprint_${no}/sprint_${no}_design.md
- progress/sprint_${no}/sprint_${no}_implementation.md
- progress/sprint_${no}/sprint_${no}_tests.md

**Output:**
- progress/sprint_${no}/sprint_${no}_documentation.md
- Updated README.md
- Updated PROGRESS_BOARD.md

**Next Step:** Sprint Complete

---

## State Transitions

Each agent updates PROGRESS_BOARD.md with appropriate states:

### Sprint States

```
Planned → under_analysis → under_design → under_construction → 
implemented/implemented_partially/failed
```

### Backlog Item States

```
Planned → under_analysis → analysed → under_design → designed → 
under_construction → implemented/tested/failed
```

## Error Handling

### If an Agent Reports Issues

1. **Read the agent's output** carefully
2. **Check for open questions** in the output
3. **Provide clarifications** if needed
4. **Update documents** if required
5. **Re-invoke the agent** to continue

### If Tests Fail After 10 Attempts

1. **Review test output** in sprint_${no}_tests.md
2. **Identify root cause**
3. **Decide:**
   - Fix and retry (re-invoke constructor)
   - Mark Backlog Item as failed
   - Request design revision

### If Design is Not Feasible

1. **Designer will report** API unavailability
2. **Product Owner decides:**
   - Reject the requirement
   - Modify the requirement
   - Find alternative approach
3. **Update BACKLOG.md** accordingly
4. **Re-invoke designer** with updated requirements

## Best Practices

### 1. Review After Each Phase

Don't wait until the end. Review outputs after each phase:
- Check documentation created
- Verify PROGRESS_BOARD.md updates
- Confirm no open questions

### 2. Git Commits

Each phase should end with a git commit:
- Contracting: commits contracting review
- Inception: commits analysis
- Elaboration: commits design
- Construction: commits code and docs
- Documentation: commits README update

### 3. Progress Board Monitoring

Always check PROGRESS_BOARD.md to understand:
- Current Sprint state
- Each Backlog Item state
- Which phase is active

### 4. Documentation Validation

Before marking Sprint as done:
- Run agent-documentor.md
- Verify all code snippets are tested
- Confirm no `exit` in copy-paste examples
- Check README is current

### 5. Parallel Work

For multiple independent Backlog Items:
- Can run agents in parallel
- Each maintains its own state
- Synchronize via PROGRESS_BOARD.md

## Troubleshooting

### Agent Doesn't Proceed

**Possible causes:**
- Open questions not answered
- Required input files missing
- Status not set correctly in documents
- Prerequisite phase not complete

**Solution:**
- Check agent output for blockers
- Verify prerequisite phase completed
- Check PROGRESS_BOARD.md states

### Agent Modifies Wrong Documents

**Possible cause:**
- Agent misunderstands boundaries

**Solution:**
- Remind agent of allowed edits (per GENERAL_RULES)
- Revert unauthorized changes
- Re-invoke agent with clarification

### Documentation Doesn't Pass Validation

**Possible causes:**
- Code snippets contain `exit` commands
- Examples not tested
- Missing prerequisites

**Solution:**
- Review documentation checklist
- Fix compliance issues
- Re-run documentor agent

### State Machine Violations

**Possible cause:**
- Agent skipped a state

**Solution:**
- Check state machine in GENERAL_RULES
- Correct PROGRESS_BOARD.md manually
- Re-invoke agent at correct state

## Migration from Original rup-cycle.md

If you were using the original single-agent approach:

**Before:**
```text
@rup-cycle.md
```

**After:**
```text
@rup-manager.md
```

Benefits:
- Same functionality
- Better modularity
- Easier to resume/iterate
- Individual phase control

## Getting Help

- **Architecture**: See agents/README.md
- **Conversion Details**: See CONVERSION_NOTES.md
- **Project Rules**: See rules/*.md
- **Product Owner Guide**: See rules/PRODUCT_OWNER_GUIDE.md

## Example Session

```text
# Start new Sprint 18
$ @rup-manager.md

[Contractor Agent runs]
✓ Contracting complete - ready for Inception

[Analyst Agent runs]
✓ Inception complete - ready for Elaboration

[Designer Agent runs]
✓ Design proposed - awaiting approval

[Product Owner reviews design, approves]

[Constructor Agent runs]
✓ Construction complete - all tests passed

[Documentor Agent runs]
✓ Documentation validated and README updated

[Manager provides final summary]
Sprint 18: implemented
- GH-25: tested
All phases complete
```

## Summary

The RUP Subagent Architecture provides:

- **Modularity**: Each phase is independent
- **Flexibility**: Run full cycle or individual phases
- **Resumability**: Continue from any phase
- **Clarity**: Clear inputs/outputs per agent
- **Maintainability**: Easy to update individual phases

Use `@rup-manager.md` for full automation, or invoke individual agents for precise control.

