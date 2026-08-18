# RUP Subagent Architecture

This directory contains specialized agents for the Rational Unified Process (RUP) cycle implementation.

## Overview

The RUP cycle has been decomposed into specialized subagents, each responsible for a specific phase of the development process. This architecture provides:

- **Separation of Concerns**: Each agent focuses on one phase
- **Reusability**: Agents can be invoked independently or as part of the full cycle
- **Clarity**: Each agent has clear inputs, outputs, and responsibilities
- **Maintainability**: Changes to one phase don't affect others

## Architecture

```
rup-manager.md (Orchestrator)
    ↓
    ├─→ agent-contractor.md (Phase 1: Contracting)
    ├─→ agent-analyst.md (Phase 2: Inception)
    ├─→ agent-designer.md (Phase 3: Elaboration)
    ├─→ agent-constructor.md (Phase 4: Construction)
    └─→ agent-documentor.md (Phase 5: Documentation)
```

## Agents

### agent-contractor.md
**Phase**: 1/5 - Contracting

**Responsibilities:**
- Review project scope (BACKLOG.md)
- Review implementation plan (PLAN.md)
- Review all cooperation rules
- Confirm understanding and readiness
- Create contracting summary

**Input:** Project documentation
**Output:** `progress/contracting_review_${cnt}.md`

---

### agent-analyst.md
**Phase**: 2/5 - Inception

**Responsibilities:**
- Analyze Sprint requirements
- Review previous Sprint work
- Assess feasibility and compatibility
- Update PROGRESS_BOARD.md
- Create analysis document

**Input:** Design from previous phase
**Output:** 
- `progress/sprint_${no}/sprint_${no}_analysis.md`
- `progress/inception/inception_sprint_${no}_chat_${cnt}.md`

---

### agent-designer.md
**Phase**: 3/5 - Elaboration

**Responsibilities:**
- Create detailed technical design
- Verify API feasibility
- Document architecture and approach
- Create diagrams and models
- Wait for design approval

**Input:** Analysis from Inception phase
**Output:**
- `progress/sprint_${no}/sprint_${no}_design.md`
- `progress/elaboration/elaboration_sprint_${no}_chat_${cnt}.md`

---

### agent-constructor.md
**Phase**: 4/5 - Construction

**Responsibilities:**
- Implement code based on design
- Create functional tests
- Execute test loops (up to 10 attempts)
- Document implementation
- Create user documentation

**Input:** Approved design
**Output:**
- Code artifacts (scripts, tools)
- `progress/sprint_${no}/sprint_${no}_implementation.md`
- `progress/sprint_${no}/sprint_${no}_tests.md`

---

### agent-documentor.md
**Phase**: 5/5 - Documentation

**Responsibilities:**
- Validate Sprint documentation
- Verify code snippet compliance
- Update README.md
- Check documentation consistency
- Create documentation summary

**Input:** All Sprint documentation
**Output:**
- Updated README.md
- `progress/sprint_${no}/sprint_${no}_documentation.md`

---

## Usage

### Full RUP Cycle (Fully Automated)
To execute the complete RUP cycle with all phases automatically:

```
@rup-manager.md
```

The manager will:
1. Read each agent's instruction file (`.claude/commands/agents/agent-*.md`)
2. Execute all instructions from that agent
3. Handle git commits after each phase
4. Automatically transition to the next phase
5. Provide comprehensive final summary at the end

**This is fully automated** - no user intervention needed between phases.

### Individual Agent Invocation
You can also invoke agents individually for specific phases:

```
@agent-contractor.md   # Just contracting
@agent-analyst.md      # Just inception
@agent-designer.md     # Just elaboration
@agent-constructor.md  # Just construction
@agent-documentor.md   # Just documentation
```

This is useful when:
- Resuming after interruption
- Iterating on a specific phase
- Debugging a particular phase issue

## State Management

The agents coordinate through:

1. **PROGRESS_BOARD.md**: Single source of truth for Sprint and Backlog Item states
2. **Git commits**: Synchronization points between phases
3. **Document Status tokens**: Phase-specific status tracking

## Communication Protocol

Each agent:
1. Reads inputs from previous phase
2. Performs its specialized work
3. Updates PROGRESS_BOARD.md
4. Creates phase-specific documentation
5. Reports completion status
6. Returns control to manager (or user if invoked directly)

## Benefits vs Single-Agent Approach

### Original (rup-cycle.md)
- Single agent executes all phases sequentially
- Reads each phase command file and executes it
- All instructions inline in phase files
- All responsibility in one execution context

### New Subagent Architecture
- **Manager executes all phases automatically** (like original)
- **Specialized agent definitions** for each phase
- **Modular instruction files** - easier to maintain
- **Clear phase boundaries** with focused responsibilities
- **Each agent can be invoked independently** for iteration
- **Better separation of concerns** - one file per phase
- **More maintainable** - update one agent without affecting others
- **Same automation** as original with better organization

## Migration Notes

The original `rup-cycle.md` remains available for backward compatibility. The new architecture provides the same functionality with improved modularity.

To migrate:
- Replace `@rup-cycle.md` with `@rup-manager.md`
- Functionality is equivalent
- Same inputs and outputs
- Same git commit patterns

## Future Enhancements

Potential improvements to the architecture:

1. **Parallel execution**: Some agents could run in parallel for independent Backlog Items
2. **Retry logic**: Automatic retry of failed phases with adjusted parameters
3. **Agent specialization**: Further decomposition (e.g., separate test agent, code review agent)
4. **Metrics collection**: Track cycle times, failure rates per phase
5. **Agent communication**: Direct agent-to-agent handoff without manager intervention

