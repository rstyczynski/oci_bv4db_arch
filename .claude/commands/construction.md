# Construction phase (4/4)

Proceed with implementation of sprints in `Designed` state.

## Analysis and design

Follow design document available in `progress` directory for given sprint. Build your understanding looking into `inception` document available in `progress` directory for given sprint.

## Progress board

When the implementation phase is started mark it by setting Sprint's status to `under_construction` in the `PROGRESS_BOARD.md` file. Note it's allowed extension of general project rules.

Progress board is a table showing sprint, and backlog items state. It's the only purpose of this file. All potential comments, progress notes, etc. always keep in dedicated files for each phase.

When the implementation if the Backlog Item belonging to the Sprint is started mark it by setting Backlog Item's status to `under_construction` in the Sprint's chapter of the `PROGRESS_BOARD.md` file. Note it's allowed extension of general project rules.

Run test for each software product to confirm proper execution before passing to the Product Owner. Run the test loops for me. Report to me success or failure once you test loops are finished.

Break functional test loop of given Backlog Item after 10 attempts to remove obstacles, and mark failed Backlog Item status as `failed`.

When functional tests pass - mark Backlog Item as `implemented` in the Sprint's chapter `PROGRESS_BOARD.md` file. Note it's allowed extension of general project rules. You have right to mark Backlog Item status as `tested` or `failed`.

## Documentation

Create user documentation for implemented Backlog Items. Documentation includes test snippets that create full copy/paste sequence to perform some educational sequences. Each sequence is tested i.e. executed with success.

Save the implementation documentation product in `progress/sprint_${no}/sprint_${no}_implementation.md`

### Documentation Checklist

When implementing a Backlog Item in a Sprint, the following documentation rules MUST be followed:

1. Implementation details for each Backlog Item MUST be recorded in `progress/sprint_${no}/sprint_${no}_implementation.md`.
2. Documentation MUST include a summary of implementation status, main features, and compliance with project design.
3. Documentation MUST include a table listing all exemplary code snippets with status: edited, tested, confirmed running by copy/paste.
4. User-facing documentation for each implemented Backlog Item MUST be included in the implementation doc.
5. Prerequisites, usage, and special notes MUST be clearly described.
6. If scripts are delivered (e.g., shell scripts), the interface, options, and expected behaviors MUST be documented.
7. All examples in the user documentation MUST be fully executable by copy/paste without modification (except when external tokens, secrets, or API permissions are required). 
8. NEVER use `exit 1, exit X in general` or equivalent in copy/paste examples as user terminal will terminate. Allowed only in scripts.
9. Sequences must form a complete, realistic workflow illustrating setup, execution, and result verification.
10. Each sequence MUST show both normal operation and typical edge/error cases when applicable.
11. Sample outputs and validation steps MUST be provided, matching exactly what the user or Product Owner will see when running commands.
12. All documentation steps and code snippets MUST be verified by actual execution at least once prior to submission.
13. Any assumptions or environmental requirements (e.g., required files, secrets) MUST be clearly stated at the top of the example sequence.
14. Implementation and usage documentation is expected to remain current with any future changes.
15. In case of deviations or failed results, results MUST be noted and explained.
16. DO NOT modify any file or document outside the specified progress or implementation doc(s) relevant to the Sprint or Backlog Item.
17. Commit and push only the intended documentation and code changes per standard project workflow.
18. All steps in the checklist MUST be confirmed by the agent before marking a Backlog Item or Sprint as implemented.

Adherence to this checklist is mandatory for shipping completed implementation and user documentation in this project.

## Functional Test

All the functional tests are documented in a form of copy/paste able sequences that Product Owner of user may execute to see exactly the same results.

### Functional Test Implementation Checklist

When implementing functional tests for a Sprint, the following rules MUST be followed:

1. All tests for Backlog Items MUST be documented in `progress/sprint_${no}/sprint_${no}_tests.md`.
2. Each test MUST be provided as a copy/paste-able shell sequence, executable by the Product Owner or user.
3. Tests MUST comprehensively cover all acceptance criteria and functional requirements described in the Backlog Item.
4. Test sequences MUST match the API usage and options as defined in implementation and user documentation.
5. Each test sequence MUST be executed successfully at least once before submission.
6. The expected output or verification criteria for each test sequence MUST be clearly documented.
7. Functional test scripts MUST use only allowed interfaces and tokens per project security rules.
8. Key error conditions MUST be tested (including missing arguments, invalid input, insufficient permissions, and API failures).
9. All functionally equivalent edge cases and safety features MUST be validated (confirmation prompts, dry-run, idempotence, etc.).
10. Test attempts and obstacles MUST be tracked for up to 10 attempts; failed tests are marked as `failed` after exhausting allowed tries.
11. Results of each test MUST be explicitly reported as PASS/FAIL in the test documentation.
12. Final status of each Backlog Item MUST be accurately updated in `PROGRESS_BOARD.md` based on the test results.
13. No undocumented modifications or side effects may be introduced during test implementation.

The agent must confirm all the above before marking the functional tests as implemented.

## Pre-finish Checklist

Before marking a Sprint as complete, verify:

1. All Backlog Items for the Sprint have been implemented.
2. All functional tests have been executed and documented.
3. All test results are recorded as PASS/FAIL in the test documentation.
4. Implementation documentation is complete and accurate in `progress/sprint_${no}/sprint_${no}_implementation.md`.
5. Test documentation is complete and accurate in `progress/sprint_${no}/sprint_${no}_tests.md`.
6. The `PROGRESS_BOARD.md` reflects the current status of all Backlog Items.
7. All documentation follows the markdown formatting rules specified in the project.
8. All code changes follow the project's coding standards and conventions.
9. No temporary files or test artifacts remain in the repository.
10. All changes are ready to be committed with a semantic commit message.

## Finalization

Once all Backlog Items for the Sprint are implemented and tested with success report end of the implementation phase, by setting Sprint's status to `implemented`. When some of Backlog Items failed report overall `implemented_partially`. When all failed mark status as `failed`.

Commit the Sprint related changes to the repository following semantic commit message convention. Do not change any other documents / file in the local file system! Push to remote after commit.

## Feedback

Enumerate required changes as instructed in general rules.

Ask questions in case of clarifications needed as instructed in general rules.

If anything is not clear raise it now, and stop here.

## Ready to go?

If all is clear, proceed with implementation.

## Commit

Commit the change to the repository following semantic commit message conventions as defined in generic GitHub rules.
